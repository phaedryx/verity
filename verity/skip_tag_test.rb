# frozen_string_literal: true

require "fileutils"
require "tmpdir"

# Dogfood mirror of test/skip_tag_test.rb

test "skipped? and runnable_tests include only non-skipped" do
  t_run = Verity::Test.new(
    fingerprint: "sk_a.rb:aaaaaaaaaaaaaaaa",
    description: "runs",
    tags: [],
    timeout: nil,
    requires: [],
    resources: {},
    file: "a.rb",
    line: 1,
    fn: -> {},
    group_path: [],
    inherited_group_tags: []
  )
  t_skip = Verity::Test.new(
    fingerprint: "sk_b.rb:bbbbbbbbbbbbbbbb",
    description: "skipped",
    tags: [:skip],
    timeout: nil,
    requires: [],
    resources: {},
    file: "b.rb",
    line: 1,
    fn: -> {},
    group_path: [],
    inherited_group_tags: []
  )
  Verity::Registry.register(t_run)
  Verity::Registry.register(t_skip)

  assert Verity.skipped?(t_skip)
  refute Verity.skipped?(t_run)
  assert_includes item: t_run, collection: Verity.runnable_tests
  refute_includes item: t_skip, collection: Verity.runnable_tests
end

test "runner run only executes non-skipped in explicit list" do
  ran = []
  t_ok = Verity::Test.new(
    fingerprint: "sk_ok.rb:aaaaaaaaaaaaaaaa",
    description: "ok",
    tags: [],
    timeout: nil,
    requires: [],
    resources: {},
    file: "a.rb",
    line: 1,
    fn: -> { ran << :ok },
    group_path: [],
    inherited_group_tags: []
  )
  t_skip = Verity::Test.new(
    fingerprint: "sk_no.rb:bbbbbbbbbbbbbbbb",
    description: "nope",
    tags: [:skip],
    timeout: nil,
    requires: [],
    resources: {},
    file: "b.rb",
    line: 2,
    fn: -> { ran << :skip },
    group_path: [],
    inherited_group_tags: []
  )
  Verity::Registry.register(t_ok)
  Verity::Registry.register(t_skip)

  rep = Verity::Reporters::TestReporter.new
  assert Verity::Runner.new(reporter: rep).run([t_ok, t_skip])
  assert_equal actual: rep.run_starts, expected: [{ total: 1, worker_id: 0 }]
  assert_equal actual: rep.test_completes,
    expected: [{ status: :pass, worker_id: 0 }, { status: :skip, worker_id: 0 }]
  assert_equal actual: rep.run_finishes.size, expected: 1
  fin = rep.run_finishes.first
  assert_equal actual: fin[:worker_id], expected: 0
  s = fin[:summary]
  assert_equal actual: s[:total], expected: 1
  assert_equal actual: s[:passed], expected: 1
  assert_equal actual: s[:failed], expected: 0
  assert_equal actual: s[:errored], expected: 0
  assert_equal actual: s[:skipped], expected: 1
  refute s[:focus]
  assert_equal actual: ran, expected: [:ok]
end

test "verity run skips tagged examples in isolated project" do
  lib = File.join(File.expand_path("..", __dir__), "lib")
  Dir.mktmpdir do |dir|
    verity_dir = File.join(dir, "verity")
    FileUtils.mkdir_p(verity_dir)
    File.write(File.join(verity_dir, "t_test.rb"), <<~RUBY)
      test "one" do
        assert true
      end

      test "two", tags: [:skip] do
        assert false
      end
    RUBY

    script = <<~RUBY
      require "verity"
      Dir.chdir(#{dir.inspect}) do
        Verity.reset_configuration!
        Verity.configure do |c|
          c.test_globs = ["verity/**/*_test.rb"]
          c.manifest_path = ":memory:"
        end
        ok = Verity.run
        reg = Verity::Registry.all.size
        runn = Verity.runnable_tests.size
        exit(ok && reg == 2 && runn == 1 ? 0 : 1)
      end
    RUBY

    assert system(RbConfig.ruby, "-I#{lib}", "-e", script, out: File::NULL, err: File::NULL)
  end
end
