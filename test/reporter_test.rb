# frozen_string_literal: true

# Triple suite (compare / redundant proof): verity/reporter_test.rb · spec/verity/reporter_spec.rb

require "minitest/autorun"
require "stringio"
require "fileutils"
require_relative "../lib/verity"
require_relative "verity_test_helper"

class ReporterTest < Minitest::Test
  include VerityTestHelper

  def test_runner_invokes_hooks_in_order
    # Arrange
    reset_verity_process_state!
    reporter = Verity::Reporters::TestReporter.new

    # Act
    t1 = Verity::Test.new(
      fingerprint: "a.rb:#{'a' * 16}",
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

    # Assert
    assert_equal [{ total: 1, worker_id: 0 }], reporter.run_starts
    assert_equal [{ status: :pass, error: nil, worker_id: 0 }], reporter.test_completes
    assert_equal 1, reporter.run_finishes.size
    summary = reporter.run_finishes.first[:summary]
    assert_equal 0, reporter.run_finishes.first[:worker_id]
    assert_equal 1, summary[:total]
    assert_equal 1, summary[:passed]
    assert_equal 0, summary[:failed]
    assert_equal 0, summary[:errored]
    assert_equal 0, summary[:skipped]
    refute summary[:focus]
  end

  def test_skip_and_focus_appear_in_documentation_summary_line
    # Arrange
    reset_verity_process_state!
    io = StringIO.new
    rep = Verity::Reporters::DocumentationReporter.new(io)

    skip_test = Verity::Test.new(
      fingerprint: "s.rb:#{'b' * 16}",
      description: "skip me",
      tags: [:skip],
      timeout: nil,
      requires: [],
      resources: {},
      file: "s.rb",
      line: 1,
      fn: -> { raise "unreachable" },
      group_path: [],
      inherited_group_tags: [], group_scopes: []
    )
    focus_test = Verity::Test.new(
      fingerprint: "f.rb:#{'c' * 16}",
      description: "focused",
      tags: [:focus],
      timeout: nil,
      requires: [],
      resources: {},
      file: "f.rb",
      line: 1,
      fn: -> {},
      group_path: [],
      inherited_group_tags: [], group_scopes: []
    )
    other = Verity::Test.new(
      fingerprint: "o.rb:#{'d' * 16}",
      description: "other",
      tags: [],
      timeout: nil,
      requires: [],
      resources: {},
      file: "o.rb",
      line: 1,
      fn: -> {},
      group_path: [],
      inherited_group_tags: [], group_scopes: []
    )
    Verity::Registry.register(skip_test)
    Verity::Registry.register(focus_test)
    Verity::Registry.register(other)

    # Act
    Verity::Runner.new(reporter: rep).run

    # Assert
    out = io.string
    assert_match(/1 skipped/, out)
    assert_match(/\(focus\)/, out)
  end

  def test_configure_reporter_is_used_by_verity_run
    Dir.mktmpdir do |dir|
      verity_dir = File.join(dir, "verity")
      FileUtils.mkdir_p(verity_dir)
      File.write(File.join(verity_dir, "one_test.rb"), <<~RUBY)
        test "hello" do
          assert true
        end
      RUBY

      Dir.chdir(dir) do
        # Arrange
        reset_verity_process_state!
        events = []
        rep = Object.new.extend(Verity::Reporter)
        rep.define_singleton_method(:on_run_start) { |total:, worker_id:| events << [:start, total, worker_id] }
        rep.define_singleton_method(:on_test_complete) { |result:, worker_id:| events << [:ex, result.status, worker_id] }
        rep.define_singleton_method(:on_run_finish) { |summary:, worker_id:| events << [:finish, summary[:passed], worker_id] }

        Verity.configure do |c|
          c.test_globs = ["verity/**/*_test.rb"]
          c.manifest_path = ":memory:"
          c.reporter = rep
          c.worker_count = 1
        end

        # Act
        assert Verity.run

        # Assert
        assert_equal [:start, 1, 0], events[0]
        assert_equal [:ex, :pass, 0], events[1]
        assert_equal [:finish, 1, 0], events[2]
      end
    end
  end

  def test_manifest_count_by_status_and_failures_for_report
    # Arrange
    reset_verity_process_state!
    manifest = Verity::Manifest.open(":memory:").tap(&:migrate!)
    good = Verity::Test.new(
      fingerprint: "g.rb:#{'e' * 16}",
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
      fingerprint: "x.rb:#{'f' * 16}",
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

    # Act
    Verity::Runner.new(reporter: Verity::Reporters::NullReporter.new).run_manifest(manifest, worker_id: 1)

    # Assert
    assert_equal 2, manifest.example_count
    counts = manifest.count_by_status
    assert_equal 1, counts["passed"]
    assert_equal 1, counts["failed"]
    problems = manifest.failures_for_report
    assert_equal 1, problems.size
    assert_equal :failed, problems[0][:status]
    assert_equal "bad", problems[0][:description]
  ensure
    manifest&.close
  end
end
