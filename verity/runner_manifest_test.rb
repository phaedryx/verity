# frozen_string_literal: true

# Dogfood mirror of test/runner_manifest_test.rb

MPASS = lambda do |fingerprint: "ok.rb:aaaaaaaaaaaaaaaa", description: "passes"|
  Verity::Test.new(
    fingerprint:,
    description:,
    tags: [],
    timeout: nil,
    requires: [],
    resources: {},
    file: "ok.rb",
    line: 1,
    fn: -> {},
    group_path: [],
    inherited_group_tags: []
  )
end

MFAIL = lambda do |fingerprint: "bad.rb:bbbbbbbbbbbbbbbb"|
  Verity::Test.new(
    fingerprint:,
    description: "fails",
    tags: [],
    timeout: nil,
    requires: [],
    resources: {},
    file: "bad.rb",
    line: 1,
    fn: -> { raise Verity::AssertionError, "fails" },
    group_path: [],
    inherited_group_tags: []
  )
end

test "run_manifest empty queue succeeds" do
  manifest = Verity::Manifest.open(":memory:").tap(&:migrate!)
  runner = Verity::Runner.new(reporter: Verity::Reporters::NullReporter.new)
  begin
    assert_equal actual: runner.run_manifest(manifest, worker_id: 42), expected: true
  ensure
    manifest.close
    Verity.hooks.each_value(&:clear)
  end
end

test "run_manifest runs claimed examples and updates sqlite" do
  manifest = Verity::Manifest.open(":memory:").tap(&:migrate!)
  runner = Verity::Runner.new(reporter: Verity::Reporters::NullReporter.new)
  first_test = MPASS.call(fingerprint: "am.rb:1111111111111111", description: "one")
  second_test = MPASS.call(fingerprint: "bm.rb:2222222222222222", description: "two")
  Verity::Registry.register(first_test)
  Verity::Registry.register(second_test)
  manifest.replace_tests([first_test, second_test])
  begin
    assert runner.run_manifest(manifest, worker_id: 7)
    sqlite = manifest.db
    statuses = sqlite.execute("SELECT fingerprint, status FROM tests ORDER BY fingerprint").to_h
    assert_equal actual: statuses, expected: { "am.rb:1111111111111111" => "passed", "bm.rb:2222222222222222" => "passed" }
  ensure
    manifest.close
    Verity.hooks.each_value(&:clear)
  end
end

test "run_manifest records failure and error statuses" do
  manifest = Verity::Manifest.open(":memory:").tap(&:migrate!)
  runner = Verity::Runner.new(reporter: Verity::Reporters::NullReporter.new)
  good = MPASS.call(fingerprint: "gm.rb:aaaaaaaaaaaaaaaa")
  bad = MFAIL.call
  boom = Verity::Test.new(
    fingerprint: "em.rb:cccccccccccccccc",
    description: "raises",
    tags: [],
    timeout: nil,
    requires: [],
    resources: {},
    file: "e.rb",
    line: 1,
    fn: -> { raise "boom" },
    group_path: [],
    inherited_group_tags: []
  )
  Verity::Registry.register(good)
  Verity::Registry.register(bad)
  Verity::Registry.register(boom)
  manifest.replace_tests([good, bad, boom])
  begin
    refute runner.run_manifest(manifest, worker_id: 1)
    sqlite = manifest.db
    assert_equal actual: sqlite.get_first_value("SELECT status FROM tests WHERE fingerprint = ?", good.fingerprint), expected: "passed"
    assert_equal actual: sqlite.get_first_value("SELECT status FROM tests WHERE fingerprint = ?", bad.fingerprint), expected: "failed"
    assert_equal actual: sqlite.get_first_value("SELECT status FROM tests WHERE fingerprint = ?", boom.fingerprint), expected: "errored"
  ensure
    manifest.close
    Verity.hooks.each_value(&:clear)
  end
end

test "run_manifest hooks fire around each example" do
  manifest = Verity::Manifest.open(":memory:").tap(&:migrate!)
  runner = Verity::Runner.new(reporter: Verity::Reporters::NullReporter.new)
  log = []
  Verity.before_worker_start { log << :worker }
  Verity.before_test { log << :before }
  Verity.after_test { log << :after }
  lone_test = MPASS.call(fingerprint: "hookm.rb:aaaaaaaaaaaaaaaa")
  Verity::Registry.register(lone_test)
  manifest.replace_tests([lone_test])
  begin
    runner.run_manifest(manifest, worker_id: 0)
    assert_equal actual: log, expected: %i[worker before after]
  ensure
    Verity.hooks.each_value(&:clear)
    manifest.close
  end
end

test "missing registry row subprocess records errored" do
  lib = File.join(File.expand_path("..", __dir__), "lib")
  script = <<~RUBY
    require "verity"
    manifest = Verity::Manifest.open(":memory:").tap(&:migrate!)
    orphan_row = Verity::Test.new(
      fingerprint: "orphan.rb:dddddddddddddddd",
      description: "orphan",
      tags: [],
      timeout: nil,
      requires: [],
      resources: {},
      file: "orphan.rb",
      line: 1,
      fn: -> {},
      group_path: [],
      inherited_group_tags: []
    )
    manifest.replace_tests([orphan_row])
    Verity::Registry.clear
    runner = Verity::Runner.new(reporter: Verity::Reporters::NullReporter.new)
    outcome = runner.run_manifest(manifest, worker_id: 3)
    sqlite = manifest.db
    st = sqlite.get_first_value("SELECT status FROM tests WHERE fingerprint = ?", orphan_row.fingerprint)
    manifest.close
    exit(outcome == false && st == "errored" ? 0 : 1)
  RUBY

  assert system(RbConfig.ruby, "-I#{lib}", "-e", script, out: File::NULL, err: File::NULL)
end
