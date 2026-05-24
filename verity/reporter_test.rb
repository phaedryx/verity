# frozen_string_literal: true

require "stringio"
require "fileutils"
require "tmpdir"

# Dogfood mirror of test/reporter_test.rb — nested Verity.run uses subprocess (load_discovery! clears Registry).

test "runner invokes reporter hooks in order for explicit list" do
  reporter = Verity::Reporters::TestReporter.new

  t1 = Verity::Test.new(
    fingerprint: "dogfood_hooks:#{"a" * 16}",
    description: "one",
    tags: [],
    timeout: nil,
    requires: [],
    resources: {},
    file: "a.rb",
    line: 1,
    fn: -> {},
    group_path: [],
    inherited_group_tags: [], group_scopes: []
  )
  Verity::Registry.register(t1)

  Verity::Runner.new(reporter: reporter).run([t1])

  assert_equal actual: reporter.run_starts, expected: [{ total: 1, worker_id: 0 }]
  assert_equal actual: reporter.test_completes, expected: [{ status: :pass, error: nil, worker_id: 0 }]
  assert_equal actual: reporter.run_finishes.size, expected: 1
  summary = reporter.run_finishes.first[:summary]
  assert_equal actual: reporter.run_finishes.first[:worker_id], expected: 0
  assert_equal actual: summary[:total], expected: 1
  assert_equal actual: summary[:passed], expected: 1
  assert_equal actual: summary[:failed], expected: 0
  assert_equal actual: summary[:errored], expected: 0
  assert_equal actual: summary[:skipped], expected: 0
  refute summary[:focus]
end

test "documentation summary shows skipped line in subprocess" do
  lib = File.join(File.expand_path("..", __dir__), "lib")
  Dir.mktmpdir do |tmp|
    verity_dir = File.join(tmp, "verity")
    FileUtils.mkdir_p(verity_dir)
    File.write(File.join(verity_dir, "only_test.rb"), <<~RUBY)
      test "skipped_example", tags: [:skip] do
        raise "nope"
      end

      test "focused", tags: [:focus] do
        assert true
      end

      test "other" do
        assert true
      end
    RUBY

    script = <<~RUBY
      require "verity"
      require "stringio"
      io = StringIO.new
      rep = Verity::Reporters::DocumentationReporter.new(io, color: false)
      Dir.chdir(#{tmp.inspect}) do
        Verity.reset_configuration!
        Verity.configure do |c|
          c.test_globs = ["verity/**/*_test.rb"]
          c.manifest_path = ":memory:"
          c.reporter = rep
          c.worker_count = 1
        end
        Verity.run or exit(1)
      end
      out = io.string
      unless out.include?("1 skipped") && out.include?("(focus)")
        warn out
        exit(1)
      end
    RUBY

    assert system(RbConfig.ruby, "-I#{lib}", "-e", script, out: File::NULL, err: File::NULL)
  end
end

test "configure reporter used by isolated Verity.run" do
  lib = File.join(File.expand_path("..", __dir__), "lib")
  Dir.mktmpdir do |dir|
    verity_dir = File.join(dir, "verity")
    FileUtils.mkdir_p(verity_dir)
    File.write(File.join(verity_dir, "one_test.rb"), <<~RUBY)
      test "hello" do
        assert true
      end
    RUBY

    script = <<~RUBY
      require "verity"
      require "stringio"
      events = []
      rep = Object.new.extend(Verity::Reporter)
      rep.define_singleton_method(:on_run_start) { |total:, worker_id:| events << [:start, total, worker_id] }
      rep.define_singleton_method(:on_test_complete) { |result:, worker_id:| events << [:ex, result.status, worker_id] }
      rep.define_singleton_method(:on_run_finish) { |summary:, worker_id:| events << [:finish, summary[:passed], worker_id] }
      Dir.chdir(#{dir.inspect}) do
        Verity.reset_configuration!
        Verity.configure do |c|
          c.test_globs = ["verity/**/*_test.rb"]
          c.manifest_path = ":memory:"
          c.reporter = rep
          c.worker_count = 1
        end
        result = Verity.run
        unless events == [[:start, 1, 0], [:ex, :pass, 0], [:finish, 1, 0]]
          warn events.inspect
          exit(1)
        end
        exit(result ? 0 : 1)
      end
    RUBY

    assert system(RbConfig.ruby, "-I#{lib}", "-e", script, out: File::NULL, err: File::NULL)
  end
end

test "run_manifest updates manifest counts and failures_for_report" do
  manifest = Verity::Manifest.open(":memory:").tap(&:migrate!)
  good = Verity::Test.new(
    fingerprint: "repog:#{"e" * 16}",
    description: "ok",
    tags: [],
    timeout: nil,
    requires: [],
    resources: {},
    file: "g.rb",
    line: 1,
    fn: -> {},
    group_path: [],
    inherited_group_tags: [], group_scopes: []
  )
  bad = Verity::Test.new(
    fingerprint: "repox:#{"f" * 16}",
    description: "bad",
    tags: [],
    timeout: nil,
    requires: [],
    resources: {},
    file: "x.rb",
    line: 1,
    fn: -> { raise Verity::AssertionError, "no" },
    group_path: [],
    inherited_group_tags: [], group_scopes: []
  )
  manifest.replace_tests([good, bad])
  Verity::Registry.register(good)
  Verity::Registry.register(bad)

  begin
    Verity::Runner.new(reporter: Verity::Reporters::NullReporter.new).run_manifest(manifest, worker_id: 1)
    assert_equal actual: manifest.example_count, expected: 2
    counts = manifest.count_by_status
    assert_equal actual: counts["passed"], expected: 1
    assert_equal actual: counts["failed"], expected: 1
    problems = manifest.failures_for_report
    assert_equal actual: problems.size, expected: 1
    assert_equal actual: problems[0][:status], expected: :failed
    assert_equal actual: problems[0][:description], expected: "bad"
  ensure
    manifest.close
  end
end
