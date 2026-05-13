# frozen_string_literal: true

require "json"
require "sqlite3"

module Verity
  # Public: SQLite-backed manifest that coordinates test distribution across
  # workers. Each row tracks a single test's fingerprint, metadata, and
  # execution status. Workers atomically claim pending rows to run.
  class Manifest
    SCHEMA_VERSION = 2

    # Public: Immutable value object returned by claim_next representing a
    # single test row from the manifest with all its stored metadata.
    #
    # fingerprint - String content-based test identifier.
    # file        - String source file path.
    # line        - Integer source line number.
    # description - String human-readable test name.
    # method      - String derived test method name.
    # tags        - Array of tag Strings.
    # requires    - Array of precondition Strings.
    # resources   - Hash of resource metadata.
    # timeout     - Float seconds or nil.
    # status      - Symbol (:pending, :running, :passed, :failed, :errored).
    # worker_id   - Integer or nil.
    # failure     - Hash with "class", "message", "backtrace" keys, or nil.
    ClaimedRow = Data.define(
      :fingerprint, :file, :line, :description, :method,
      :tags, :requires, :resources, :timeout,
      :status, :worker_id, :failure
    )

    # Public: Open (or create) a manifest database at the given path.
    #
    # path - String file path, or ":memory:" for an in-process database.
    #
    # Returns a new Manifest instance.
    def self.open(path, **)
      new(path, **)
    end

    def initialize(path, busy_timeout_ms: 5000)
      @memory = (path == ":memory:")
      @busy_timeout_ms = busy_timeout_ms
      @db = SQLite3::Database.new(path)
      configure_connection!
    end

    # Public: Close the underlying SQLite connection.
    #
    # Returns nothing.
    def close = @db.close

    # Internal: Raw SQLite3::Database handle for tests and introspection.
    attr_reader :db

    # Public: Create or upgrade the tests table to the current schema version.
    # Safe to call multiple times; no-ops when already at SCHEMA_VERSION.
    #
    # Returns nothing.
    def migrate!
      version = @db.get_first_value("PRAGMA user_version").to_i
      return if version >= SCHEMA_VERSION

      if version.zero?
        @db.transaction do
          @db.execute_batch(<<~SQL)
            CREATE TABLE IF NOT EXISTS tests (
              fingerprint     TEXT PRIMARY KEY,
              file            TEXT NOT NULL,
              line            INTEGER NOT NULL,
              description     TEXT,
              method          TEXT NOT NULL,
              tags            TEXT,
              requires        TEXT,
              resources       TEXT,
              timeout         REAL,
              status          TEXT NOT NULL DEFAULT 'pending',
              worker_id       INTEGER,
              failure         TEXT,
              CHECK (status IN ('pending', 'running', 'passed', 'failed', 'errored'))
            );
            CREATE INDEX IF NOT EXISTS idx_tests_pending
              ON tests (status, fingerprint);
          SQL
          @db.execute("PRAGMA user_version = #{SCHEMA_VERSION}")
        end
        return
      end

      return unless version == 1

      @db.transaction do
        @db.execute("DROP INDEX IF EXISTS idx_tests_pending_duration")
        @db.execute("ALTER TABLE tests DROP COLUMN duration_p50")
        @db.execute(<<~SQL)
          CREATE INDEX IF NOT EXISTS idx_tests_pending
            ON tests (status, fingerprint);
        SQL
        @db.execute("PRAGMA user_version = #{SCHEMA_VERSION}")
      end
    end

    # Public: Atomically clear the tests table and insert the given tests as
    # pending rows. Called once per run before workers begin claiming.
    #
    # tests - Array of Verity::Test instances.
    #
    # Returns nothing.
    def replace_tests(tests)
      @db.transaction do
        @db.execute("DELETE FROM tests")
        stmt = @db.prepare(<<~SQL)
          INSERT INTO tests (
            fingerprint, file, line, description, method,
            tags, requires, resources, timeout,
            status, worker_id, failure
          ) VALUES (
            ?, ?, ?, ?, ?, ?, ?, ?, ?,
            'pending', NULL, NULL
          )
        SQL
        tests.each do |t|
          stmt.execute!(
            t.fingerprint,
            t.file,
            t.line,
            t.description,
            derive_method(t.fingerprint),
            dump_json(t.tags),
            dump_json(t.requires),
            dump_json(t.resources),
            t.timeout
          )
        end
        stmt.close
      end
    end

    # Public: Atomically claim the next pending test for a worker. Marks the
    # row as "running" and returns its data.
    #
    # worker_id - Integer identifying the claiming worker.
    #
    # Returns a ClaimedRow, or nil when no pending tests remain.
    def claim_next(worker_id)
      rows = @db.execute2(<<~SQL, worker_id)
        UPDATE tests
        SET status = 'running', worker_id = ?
        WHERE fingerprint = (
          SELECT fingerprint FROM tests
          WHERE status = 'pending'
          ORDER BY fingerprint ASC
          LIMIT 1
        )
        RETURNING
          fingerprint, file, line, description, method,
          tags, requires, resources, timeout,
          status, worker_id, failure
      SQL
      return nil if rows.size < 2

      headers = rows[0]
      values = rows[1]
      hash = headers.zip(values).to_h
      hydrate_row(hash)
    end

    # Public: Mark a test as passed.
    #
    # fingerprint - String test fingerprint.
    #
    # Returns nothing.
    def record_pass(fingerprint)
      @db.execute(<<~SQL, [fingerprint])
        UPDATE tests
        SET status = 'passed', failure = NULL, worker_id = NULL
        WHERE fingerprint = ?
      SQL
    end

    # Public: Mark a test as failed and store the failure details.
    #
    # fingerprint - String test fingerprint.
    # error       - Exception that caused the failure.
    #
    # Returns nothing.
    def record_failure(fingerprint, error)
      @db.execute(<<~SQL, [encode_failure(error), fingerprint])
        UPDATE tests
        SET status = 'failed', failure = ?, worker_id = NULL
        WHERE fingerprint = ?
      SQL
    end

    # Public: Mark a test as errored (unexpected exception) and store details.
    #
    # fingerprint - String test fingerprint.
    # error       - Exception that caused the error.
    #
    # Returns nothing.
    def record_error(fingerprint, error)
      @db.execute(<<~SQL, [encode_failure(error), fingerprint])
        UPDATE tests
        SET status = 'errored', failure = ?, worker_id = NULL
        WHERE fingerprint = ?
      SQL
    end

    # Public: Total number of test rows in the manifest.
    #
    # Returns an Integer.
    def example_count
      @db.get_first_value("SELECT COUNT(*) FROM tests").to_i
    end

    # Public: Aggregate test counts grouped by status. Used by
    # ParallelSummaryReporter after all workers finish.
    #
    # Returns a Hash with String status keys and Integer counts.
    def count_by_status
      @db.execute("SELECT status, COUNT(*) FROM tests GROUP BY status").to_h.transform_values(&:to_i)
    end

    # Public: Fetch details for all failed and errored tests, ordered by
    # fingerprint, for the final summary report.
    #
    # Returns an Array of Hashes with :fingerprint, :description, :status,
    # and :failure keys.
    def failures_for_report
      @db.execute(<<~SQL).map do |fingerprint, description, status, failure|
          SELECT fingerprint, description, status, failure
          FROM tests
          WHERE status IN ('failed', 'errored')
          ORDER BY fingerprint ASC
        SQL
        {
          fingerprint: fingerprint,
          description: description,
          status: status.to_sym,
          failure: parse_failure(failure)
        }
      end
    end

    private

    def configure_connection!
      @db.busy_timeout = @busy_timeout_ms
      return if @memory

      @db.execute("PRAGMA journal_mode=WAL")
    rescue SQLite3::SQLException
      # Unavailable for some URI modes; ignore.
    end

    def derive_method(fingerprint)
      "test_#{Verity::Fingerprint.derive_method_suffix(fingerprint)}"
    end

    def dump_json(obj)
      JSON.generate(normalize_json_tree(obj))
    end

    def normalize_json_tree(obj)
      case obj
      when Hash then obj.transform_values { |v| normalize_json_tree(v) }
      when Array then obj.map { |v| normalize_json_tree(v) }
      when Symbol then obj.to_s
      else obj
      end
    end

    def encode_failure(error)
      JSON.generate(
        "class" => error.class.name,
        "message" => error.message.to_s,
        "backtrace" => Array(error.backtrace).take(50)
      )
    end

    def hydrate_row(hash)
      ClaimedRow.new(
        fingerprint: hash["fingerprint"],
        file: hash["file"],
        line: Integer(hash["line"]),
        description: hash["description"],
        method: hash["method"],
        tags: parse_json_array(hash["tags"]),
        requires: parse_json_array(hash["requires"]),
        resources: parse_json_object(hash["resources"]),
        timeout: hash["timeout"]&.to_f,
        status: hash["status"].to_sym,
        worker_id: hash["worker_id"]&.to_i,
        failure: parse_failure(hash["failure"])
      )
    end

    def parse_json_array(str)
      return [] if str.nil? || str.empty?
      JSON.parse(str)
    end

    def parse_json_object(str)
      return {} if str.nil? || str.empty?
      JSON.parse(str)
    end

    def parse_failure(str)
      return nil if str.nil? || str.empty?
      JSON.parse(str)
    end
  end
end
