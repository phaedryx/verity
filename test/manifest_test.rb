# frozen_string_literal: true

# Triple suite (compare / redundant proof): verity/manifest_test.rb · spec/verity/manifest_spec.rb

require "minitest/autorun"
require "json"
require "sqlite3"
require "tmpdir"
require_relative "../lib/verity"

class ManifestTest < Minitest::Test
  ClaimedRow = Verity::Manifest::ClaimedRow

  def test_open_creates_parent_directories_for_non_memory_path
    Dir.mktmpdir do |base|
      nested = File.join(base, "deep", "nested", "dir")
      path = File.join(nested, "test.db")
      refute Dir.exist?(nested)
      m = Verity::Manifest.open(path)
      m.migrate!
      assert File.exist?(path)
    ensure
      m&.close
    end
  end

  def test_migrate_is_idempotent
    # Arrange
    manifest = open_memory_manifest

    begin
      # Act
      manifest.migrate!
      version = sqlite_connection(manifest).get_first_value("PRAGMA user_version").to_i

      # Assert
      assert_equal Verity::Manifest::SCHEMA_VERSION, version
    ensure
      manifest.close
    end
  end

  def test_replace_tests_inserts_rows
    # Arrange
    manifest = open_memory_manifest
    first = make_test(fingerprint: "a.rb:aaaaaaaaaaaaaaaa", file: "a.rb", line: 1)
    second = make_test(fingerprint: "b.rb:bbbbbbbbbbbbbbbb", file: "b.rb", line: 2, description: "two")

    begin
      # Act
      manifest.replace_tests([first, second])

      # Assert
      sqlite = sqlite_connection(manifest)
      count = sqlite.get_first_value("SELECT COUNT(*) FROM tests").to_i
      assert_equal 2, count

      row = sqlite.get_first_row(
        "SELECT description, method, tags, status FROM tests WHERE fingerprint = ?", first.fingerprint
      )
      assert_equal ["example", "test_aaaaaaaaaaaaaaaa", '["unit"]', "pending"], row
    ensure
      manifest.close
    end
  end

  def test_claim_next_orders_by_dispatch_sequence
    # Arrange — claim order follows replace_tests arg order (queue_index), not fingerprint.
    manifest = open_memory_manifest
    triple = [
      make_test(fingerprint: "z.rb:1111111111111111", file: "z.rb", line: 1),
      make_test(fingerprint: "a.rb:2222222222222222", file: "a.rb", line: 1),
      make_test(fingerprint: "m.rb:3333333333333333", file: "m.rb", line: 1)
    ]
    manifest.replace_tests(triple)

    begin
      # Act
      first_claim = manifest.claim_next(1)
      second_claim = manifest.claim_next(2)
      third_claim = manifest.claim_next(3)

      # Assert
      assert_equal "z.rb:1111111111111111", first_claim.fingerprint
      assert_equal "a.rb:2222222222222222", second_claim.fingerprint
      assert_equal "m.rb:3333333333333333", third_claim.fingerprint
      assert_kind_of ClaimedRow, first_claim
    ensure
      manifest.close
    end
  end

  def test_claim_next_nil_when_empty
    # Arrange
    manifest = open_memory_manifest

    begin
      # Act
      claimed = manifest.claim_next(1)

      # Assert
      assert_nil claimed
    ensure
      manifest.close
    end
  end

  def test_second_worker_gets_nothing_when_only_one_pending
    # Arrange
    manifest = open_memory_manifest
    lone = make_test
    manifest.replace_tests([lone])

    begin
      # Act
      first_claim = manifest.claim_next(100)
      second_claim = manifest.claim_next(200)

      # Assert
      refute_nil first_claim
      assert_nil second_claim
    ensure
      manifest.close
    end
  end

  def test_record_pass
    # Arrange
    manifest = open_memory_manifest
    manifest.replace_tests([make_test(fingerprint: "z.rb:acacacacacacacac")])
    manifest.claim_next(1)

    begin
      # Act
      manifest.record_pass("z.rb:acacacacacacacac")

      # Assert
      sqlite = sqlite_connection(manifest)
      status = sqlite.get_first_value("SELECT status FROM tests WHERE fingerprint = ?", "z.rb:acacacacacacacac")
      worker = sqlite.get_first_value("SELECT worker_id FROM tests WHERE fingerprint = ?", "z.rb:acacacacacacacac")
      failure = sqlite.get_first_value("SELECT failure FROM tests WHERE fingerprint = ?", "z.rb:acacacacacacacac")

      assert_equal "passed", status
      assert_nil worker
      assert_nil failure
    ensure
      manifest.close
    end
  end

  def test_record_failure_and_error
    # Arrange
    manifest = open_memory_manifest
    manifest.replace_tests([
      make_test(fingerprint: "fail.rb:aaaaaaaaaaaaaaaa"),
      make_test(fingerprint: "err.rb:bbbbbbbbbbbbbbbb")
    ])
    manifest.claim_next(1)
    manifest.claim_next(1)
    assertion_e = Verity::AssertionError.new("boom")
    assertion_e.set_backtrace %w[line1 line2]

    begin
      # Act
      manifest.record_failure("fail.rb:aaaaaaaaaaaaaaaa", assertion_e)
      manifest.record_error("err.rb:bbbbbbbbbbbbbbbb", RuntimeError.new("x"))

      # Assert
      sqlite = sqlite_connection(manifest)
      fail_status = sqlite.get_first_value("SELECT status FROM tests WHERE fingerprint = ?", "fail.rb:aaaaaaaaaaaaaaaa")
      err_status = sqlite.get_first_value("SELECT status FROM tests WHERE fingerprint = ?", "err.rb:bbbbbbbbbbbbbbbb")
      fail_json = JSON.parse(sqlite.get_first_value("SELECT failure FROM tests WHERE fingerprint = ?", "fail.rb:aaaaaaaaaaaaaaaa"))
      err_json = JSON.parse(sqlite.get_first_value("SELECT failure FROM tests WHERE fingerprint = ?", "err.rb:bbbbbbbbbbbbbbbb"))

      assert_equal "failed", fail_status
      assert_equal "errored", err_status
      assert_equal "Verity::AssertionError", fail_json["class"]
      assert_equal "boom", fail_json["message"]
      assert_equal %w[line1 line2], fail_json["backtrace"]
      assert_equal "RuntimeError", err_json["class"]
      assert_equal "x", err_json["message"]
    ensure
      manifest.close
    end
  end

  def test_replace_tests_clears_previous_run
    # Arrange
    manifest = open_memory_manifest
    manifest.replace_tests([make_test(fingerprint: "one.rb:1111111111111111")])

    begin
      # Act
      manifest.replace_tests([make_test(fingerprint: "two.rb:2222222222222222")])

      # Assert
      sqlite = sqlite_connection(manifest)
      count = sqlite.get_first_value("SELECT COUNT(*) FROM tests").to_i
      assert_equal 1, count
      assert_equal "two.rb:2222222222222222", sqlite.get_first_value("SELECT fingerprint FROM tests")
    ensure
      manifest.close
    end
  end

  def test_resources_and_requires_serialize_symbols
    # Arrange
    manifest = open_memory_manifest
    t = make_test(
      tags: [:a, :b],
      requires: [:db],
      resources: { tables: [:users] }
    )
    manifest.replace_tests([t])

    begin
      # Act
      claimed = manifest.claim_next(0)

      # Assert
      assert_equal %w[a b], claimed.tags
      assert_equal ["db"], claimed.requires
      assert_equal({ "tables" => ["users"] }, claimed.resources)
    ensure
      manifest.close
    end
  end

  def test_migrate_v1_to_v2_drops_duration_column
    Dir.mktmpdir do |dir|
      path = File.join(dir, "legacy.db")
      SQLite3::Database.new(path) do |db|
        db.execute_batch(<<~SQL)
          CREATE TABLE tests (
            fingerprint     TEXT PRIMARY KEY,
            file            TEXT NOT NULL,
            line            INTEGER NOT NULL,
            description     TEXT,
            method          TEXT NOT NULL,
            tags            TEXT,
            requires        TEXT,
            resources       TEXT,
            timeout         REAL,
            duration_p50    REAL,
            status          TEXT NOT NULL DEFAULT 'pending',
            worker_id       INTEGER,
            failure         TEXT,
            CHECK (status IN ('pending', 'running', 'passed', 'failed', 'errored'))
          );
          CREATE INDEX idx_tests_pending_duration
            ON tests (status, duration_p50 DESC, fingerprint);
        SQL
        db.execute("PRAGMA user_version = 1")
      end

      manifest = Verity::Manifest.open(path)
      begin
        manifest.migrate!
        sqlite = sqlite_connection(manifest)
        names = sqlite.execute("PRAGMA table_info(tests)").map { |r| r[1] }
        refute_includes names, "duration_p50"
        assert_includes names, "queue_index"
        assert_equal Verity::Manifest::SCHEMA_VERSION, sqlite.get_first_value("PRAGMA user_version").to_i
      ensure
        manifest.close
      end
    end
  end

  def test_migrate_v2_to_v3_adds_queue_index
    Dir.mktmpdir do |dir|
      path = File.join(dir, "v2.db")
      SQLite3::Database.new(path) do |db|
        db.execute_batch(<<~SQL)
          CREATE TABLE tests (
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
          CREATE INDEX idx_tests_pending
            ON tests (status, fingerprint);
        SQL
        db.execute("PRAGMA user_version = 2")
      end

      manifest = Verity::Manifest.open(path)
      begin
        manifest.migrate!
        sqlite = sqlite_connection(manifest)
        names = sqlite.execute("PRAGMA table_info(tests)").map { |r| r[1] }
        assert_includes names, "queue_index"
        assert_equal Verity::Manifest::SCHEMA_VERSION, sqlite.get_first_value("PRAGMA user_version").to_i
      ensure
        manifest.close
      end
    end
  end

  private

  def open_memory_manifest
    Verity::Manifest.open(":memory:").tap(&:migrate!)
  end

  def sqlite_connection(manifest)
    manifest.db
  end

  def make_test(**overrides)
    defaults = {
      fingerprint: "t.rb:deadbeefdeadbeef",
      description: "example",
      tags: [:unit],
      timeout: nil,
      requires: [],
      resources: {},
      file: "t.rb",
      line: 10,
      fn: -> {},
      group_path: [],
      inherited_group_tags: [], group_scopes: []
    }
    Verity::Test.new(**defaults.merge(overrides))
  end
end
