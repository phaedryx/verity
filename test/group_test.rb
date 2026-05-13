# frozen_string_literal: true

require "minitest/autorun"
require "stringio"
require "fileutils"
require_relative "../lib/verity"
require_relative "verity_test_helper"

class GroupTest < Minitest::Test
  include VerityTestHelper

  def test_group_requires_block
    reset_verity_process_state!
    assert_raises(ArgumentError) { Object.new.extend(Verity::DSL).group("nope") }
  end

  def test_nested_group_path_on_tests
    reset_verity_process_state!
    Verity.clear_group_stack!

    Object.new.extend(Verity::DSL).instance_eval do
      group "Outer", tags: [:integration] do
        group "Inner" do
          test "leaf" do
            assert true
          end
        end
      end
    end

    t = Verity::Registry.all.first
    assert_equal %w[Outer Inner], t.group_path
    assert_equal %i[integration], t.inherited_group_tags
    assert_equal %i[integration], Verity.effective_tags(t)
  end

  def test_group_skip_applies_to_nested_tests
    reset_verity_process_state!
    Verity.clear_group_stack!
    ran = []
    Object.new.extend(Verity::DSL).instance_eval do
      group "WIP", tags: [:skip] do
        test "inside" do
          ran << :inside
        end
      end
    end

    t = Verity::Registry.all.first
    assert Verity.skipped?(t)
    assert_empty Verity.runnable_tests
    Verity::Runner.new(reporter: Verity::Reporters::NullReporter.new).run(Verity::Registry.all)
    assert_empty ran
  end

  def test_group_focus_narrows_runnable_suite
    reset_verity_process_state!
    Verity.clear_group_stack!
    Object.new.extend(Verity::DSL).instance_eval do
      group "Focused block", tags: [:focus] do
        test "in group" do
        end
      end
      test "outside" do
      end
    end

    names = Verity.runnable_tests.map(&:description).sort
    assert_equal ["in group"], names
    assert Verity.focus_filter_active?(Verity::Registry.all.reject { Verity.skipped?(_1) })
  end

  def test_group_tags_accumulate_for_effective_tags
    reset_verity_process_state!
    Verity.clear_group_stack!
    Object.new.extend(Verity::DSL).instance_eval do
      group "A", tags: [:skip] do
        group "B", tags: [:focus] do
          test "t", tags: [:integration] do
          end
        end
      end
    end

    t = Verity::Registry.all.first
    assert_equal %i[skip focus integration], Verity.effective_tags(t)
    assert Verity.skipped?(t)
  end

  def test_documentation_reporter_prints_group_headers
    reset_verity_process_state!
    io = StringIO.new
    rep = Verity::Reporters::DocumentationReporter.new(io)
    a = Verity::Test.new(
      fingerprint: "a.rb:#{'a' * 16}",
      description: "one",
      tags: [],
      timeout: nil,
      requires: [],
      resources: {},
      file: "a.rb",
      line: 1,
      fn: -> {},
      group_path: %w[Alpha],
      inherited_group_tags: []
    )
    b = Verity::Test.new(
      fingerprint: "b.rb:#{'b' * 16}",
      description: "two",
      tags: [],
      timeout: nil,
      requires: [],
      resources: {},
      file: "b.rb",
      line: 1,
      fn: -> {},
      group_path: %w[Alpha Beta],
      inherited_group_tags: []
    )
    c = Verity::Test.new(
      fingerprint: "c.rb:#{'c' * 16}",
      description: "three",
      tags: [],
      timeout: nil,
      requires: [],
      resources: {},
      file: "c.rb",
      line: 1,
      fn: -> {},
      group_path: ["Gamma"],
      inherited_group_tags: []
    )

    rep.on_run_start(total: 3, worker_id: 0)
    rep.on_test_complete(result: Verity::Runner::Result.new(test: a, status: :pass, error: nil), worker_id: 0)
    rep.on_test_complete(result: Verity::Runner::Result.new(test: b, status: :pass, error: nil), worker_id: 0)
    rep.on_test_complete(result: Verity::Runner::Result.new(test: c, status: :pass, error: nil), worker_id: 0)

    out = io.string
    assert_match(/Alpha\n/, out)
    assert_match(/  Beta\n/, out)
    assert_match(/Gamma\n/, out)
    assert_match(/      pass  two\n/, out)
  end

  def test_load_discovery_clears_group_stack_per_file
    reset_verity_process_state!
    Dir.mktmpdir do |dir|
      verity_dir = File.join(dir, "verity")
      FileUtils.mkdir_p(verity_dir)
      File.write(File.join(verity_dir, "a_test.rb"), <<~RUBY)
        group "FromA" do
          test "in a" do
          end
        end
      RUBY
      File.write(File.join(verity_dir, "b_test.rb"), <<~RUBY)
        test "no group" do
        end
      RUBY

      Dir.chdir(dir) do
        Verity.configure { |c| c.test_globs = ["verity/**/*_test.rb"] }
        Verity.load_discovery!
      end

      paths = Verity::Registry.all.map(&:group_path)
      assert_includes paths, %w[FromA]
      assert_includes paths, []
    end
  end
end
