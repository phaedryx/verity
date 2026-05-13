# frozen_string_literal: true

require "json"
require "sqlite3"

module Verity
  class Manifest
    SCHEMA_VERSION = 2

    ClaimedRow = Data.define(
      :fingerprint, :file, :line, :description, :method,
      :tags, :requires, :resources, :timeout,
      :status, :worker_id, :failure
    )

    def self.open(path, **)
      new(path, **)
    end

    def initialize(path, busy_timeout_ms: 5000)
      @memory = (path == ":memory:")
      @busy_timeout_ms = busy_timeout_ms
      @db = SQLite3::Database.new(path)
      configure_connection!
    end

    def close = @db.close

    # Raw +SQLite3::Database+ (for tests and advanced introspection).
    attr_reader :db

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

    def record_pass(fingerprint)
      @db.execute(<<~SQL, [fingerprint])
        UPDATE tests
        SET status = 'passed', failure = NULL, worker_id = NULL
        WHERE fingerprint = ?
      SQL
    end

    def record_failure(fingerprint, error)
      @db.execute(<<~SQL, [encode_failure(error), fingerprint])
        UPDATE tests
        SET status = 'failed', failure = ?, worker_id = NULL
        WHERE fingerprint = ?
      SQL
    end

    def record_error(fingerprint, error)
      @db.execute(<<~SQL, [encode_failure(error), fingerprint])
        UPDATE tests
        SET status = 'errored', failure = ?, worker_id = NULL
        WHERE fingerprint = ?
      SQL
    end

    def example_count
      @db.get_first_value("SELECT COUNT(*) FROM tests").to_i
    end

    # String status keys ("passed", "failed", …) for {Reporters::ParallelSummaryReporter}.
    def count_by_status
      @db.execute("SELECT status, COUNT(*) FROM tests GROUP BY status").to_h.transform_values(&:to_i)
    end

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
