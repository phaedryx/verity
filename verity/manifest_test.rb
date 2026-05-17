# frozen_string_literal: true

require "json"
require "sqlite3"
require "fileutils"
require "tmpdir"

# Dogfood mirror of test/manifest_test.rb

MClaimedRow = Verity::Manifest::ClaimedRow

MMAKE = lambda do |**overrides|
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

test "manifest open creates parent directories for non-memory path" do
  dir = Dir.mktmpdir
  nested = File.join(dir, "deep", "nested", "dir")
  path = File.join(nested, "test.db")
  refute(Dir.exist?(nested))
  m = Verity::Manifest.open(path)
  begin
    m.migrate!
    assert(File.exist?(path))
  ensure
    m.close
    FileUtils.rm_rf(dir)
  end
end

test "manifest migrate yields schema version" do
  manifest = Verity::Manifest.open(":memory:").tap(&:migrate!)
  begin
    manifest.migrate!
    version = manifest.db.get_first_value("PRAGMA user_version").to_i
    assert_equal actual: version, expected: Verity::Manifest::SCHEMA_VERSION
  ensure
    manifest.close
  end
end

test "manifest replace_tests inserts rows" do
  manifest = Verity::Manifest.open(":memory:").tap(&:migrate!)
  first = MMAKE.call(fingerprint: "a.rb:aaaaaaaaaaaaaaaa", file: "a.rb", line: 1)
  second = MMAKE.call(fingerprint: "b.rb:bbbbbbbbbbbbbbbb", file: "b.rb", line: 2, description: "two")
  begin
    manifest.replace_tests([first, second])
    sqlite = manifest.db
    assert_equal actual: sqlite.get_first_value("SELECT COUNT(*) FROM tests").to_i, expected: 2
    row = sqlite.get_first_row(
      "SELECT description, method, tags, status FROM tests WHERE fingerprint = ?", first.fingerprint
    )
    assert_equal actual: row, expected: ["example", "test_aaaaaaaaaaaaaaaa", '["unit"]', "pending"]
  ensure
    manifest.close
  end
end

test "manifest claim_next orders by dispatch sequence" do
  manifest = Verity::Manifest.open(":memory:").tap(&:migrate!)
  triple = [
    MMAKE.call(fingerprint: "z.rb:1111111111111111", file: "z.rb", line: 1),
    MMAKE.call(fingerprint: "a.rb:2222222222222222", file: "a.rb", line: 1),
    MMAKE.call(fingerprint: "m.rb:3333333333333333", file: "m.rb", line: 1)
  ]
  manifest.replace_tests(triple)
  begin
    first_claim = manifest.claim_next(1)
    second_claim = manifest.claim_next(2)
    third_claim = manifest.claim_next(3)
    assert_equal actual: first_claim.fingerprint, expected: "z.rb:1111111111111111"
    assert_equal actual: second_claim.fingerprint, expected: "a.rb:2222222222222222"
    assert_equal actual: third_claim.fingerprint, expected: "m.rb:3333333333333333"
    assert first_claim.is_a?(MClaimedRow)
  ensure
    manifest.close
  end
end

test "manifest claim_next nil when empty" do
  manifest = Verity::Manifest.open(":memory:").tap(&:migrate!)
  begin
    assert_equal actual: manifest.claim_next(1), expected: nil
  ensure
    manifest.close
  end
end

test "manifest second worker gets nothing when only one pending" do
  manifest = Verity::Manifest.open(":memory:").tap(&:migrate!)
  lone = MMAKE.call
  manifest.replace_tests([lone])
  begin
    first_claim = manifest.claim_next(100)
    second_claim = manifest.claim_next(200)
    assert first_claim
    assert_equal actual: second_claim, expected: nil
  ensure
    manifest.close
  end
end

test "manifest record_pass updates row" do
  manifest = Verity::Manifest.open(":memory:").tap(&:migrate!)
  manifest.replace_tests([MMAKE.call(fingerprint: "z.rb:acacacacacacacac")])
  manifest.claim_next(1)
  begin
    manifest.record_pass("z.rb:acacacacacacacac")
    sqlite = manifest.db
    status = sqlite.get_first_value("SELECT status FROM tests WHERE fingerprint = ?", "z.rb:acacacacacacacac")
    worker = sqlite.get_first_value("SELECT worker_id FROM tests WHERE fingerprint = ?", "z.rb:acacacacacacacac")
    failure = sqlite.get_first_value("SELECT failure FROM tests WHERE fingerprint = ?", "z.rb:acacacacacacacac")
    assert_equal actual: status, expected: "passed"
    assert_equal actual: worker, expected: nil
    assert_equal actual: failure, expected: nil
  ensure
    manifest.close
  end
end

test "manifest record_failure and record_error serialize failure json" do
  manifest = Verity::Manifest.open(":memory:").tap(&:migrate!)
  manifest.replace_tests([
    MMAKE.call(fingerprint: "fail.rb:aaaaaaaaaaaaaaaa"),
    MMAKE.call(fingerprint: "err.rb:bbbbbbbbbbbbbbbb")
  ])
  manifest.claim_next(1)
  manifest.claim_next(1)
  assertion_e = Verity::AssertionError.new("boom")
  assertion_e.set_backtrace %w[line1 line2]
  begin
    manifest.record_failure("fail.rb:aaaaaaaaaaaaaaaa", assertion_e)
    manifest.record_error("err.rb:bbbbbbbbbbbbbbbb", RuntimeError.new("x"))
    sqlite = manifest.db
    fail_status = sqlite.get_first_value("SELECT status FROM tests WHERE fingerprint = ?", "fail.rb:aaaaaaaaaaaaaaaa")
    err_status = sqlite.get_first_value("SELECT status FROM tests WHERE fingerprint = ?", "err.rb:bbbbbbbbbbbbbbbb")
    fail_json = JSON.parse(sqlite.get_first_value("SELECT failure FROM tests WHERE fingerprint = ?", "fail.rb:aaaaaaaaaaaaaaaa"))
    err_json = JSON.parse(sqlite.get_first_value("SELECT failure FROM tests WHERE fingerprint = ?", "err.rb:bbbbbbbbbbbbbbbb"))
    assert_equal actual: fail_status, expected: "failed"
    assert_equal actual: err_status, expected: "errored"
    assert_equal actual: fail_json["class"], expected: "Verity::AssertionError"
    assert_equal actual: fail_json["message"], expected: "boom"
    assert_equal actual: fail_json["backtrace"], expected: %w[line1 line2]
    assert_equal actual: err_json["class"], expected: "RuntimeError"
    assert_equal actual: err_json["message"], expected: "x"
  ensure
    manifest.close
  end
end

test "manifest replace_tests clears previous rows" do
  manifest = Verity::Manifest.open(":memory:").tap(&:migrate!)
  manifest.replace_tests([MMAKE.call(fingerprint: "one.rb:1111111111111111")])
  begin
    manifest.replace_tests([MMAKE.call(fingerprint: "two.rb:2222222222222222")])
    sqlite = manifest.db
    assert_equal actual: sqlite.get_first_value("SELECT COUNT(*) FROM tests").to_i, expected: 1
    assert_equal actual: sqlite.get_first_value("SELECT fingerprint FROM tests"), expected: "two.rb:2222222222222222"
  ensure
    manifest.close
  end
end

test "manifest resources and requires on claimed row" do
  manifest = Verity::Manifest.open(":memory:").tap(&:migrate!)
  t = MMAKE.call(
    tags: [:a, :b],
    requires: [:db],
    resources: { tables: [:users] }
  )
  manifest.replace_tests([t])
  begin
    claimed = manifest.claim_next(0)
    assert_equal actual: claimed.tags, expected: %w[a b]
    assert_equal actual: claimed.requires, expected: ["db"]
    assert_equal actual: claimed.resources, expected: { "tables" => ["users"] }
  ensure
    manifest.close
  end
end

test "manifest migrate v1 drops duration_p50 column" do
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
      sqlite = manifest.db
      names = sqlite.execute("PRAGMA table_info(tests)").map { |r| r[1] }
      refute_includes item: "duration_p50", collection: names
      assert_includes item: "queue_index", collection: names
      assert_equal actual: sqlite.get_first_value("PRAGMA user_version").to_i, expected: Verity::Manifest::SCHEMA_VERSION
    ensure
      manifest.close
    end
  end
end
