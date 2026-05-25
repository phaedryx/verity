# frozen_string_literal: true

# Triple suite (compare / redundant proof): verity/group_test.rb · spec/verity/group_spec.rb

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

  def test_inner_group_without_block_does_not_corrupt_outer_group_stack
    reset_verity_process_state!
    Verity.clear_group_stack!

    dsl = Object.new.extend(Verity::DSL)
    dsl.group("Outer") do
      assert_raises(ArgumentError) { dsl.group("Bad") }
      dsl.test("after_bad_inner") { true }
    end

    t = Verity::Registry.all.find { _1.description == "after_bad_inner" }
    assert_equal ["Outer"], t.group_path
    assert_equal ["Outer"], t.group_scopes.map(&:title)
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
    assert_equal 2, t.group_scopes.size
    assert_equal %w[Outer Inner], t.group_scopes.map(&:title)
    assert(t.group_scopes.all? { |g| g.file.end_with?("group_test.rb") })
    assert_operator t.group_scopes.map(&:line).max, :>=, 1
    assert_equal %i[integration], t.inherited_group_tags
    assert_equal %i[integration], Verity.effective_tags(t)
  end

  def test_group_skip_applies_to_nested_tests
    reset_verity_process_state!
    Verity.clear_group_stack!
    ran = []
    Object.new.extend(Verity::DSL).instance_eval do
      group "WIP", skip: true do
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
      group "Focused block", focus: true do
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
      group "A", skip: true do
        group "B", focus: true do
          test "t", tags: [:integration] do
          end
        end
      end
    end

    t = Verity::Registry.all.first
    assert_equal [:integration], Verity.effective_tags(t)
    assert Verity.skipped?(t)
    assert Verity.focused?(t)
  end

  def test_documentation_reporter_prints_group_headers
    reset_verity_process_state!
    io = StringIO.new
    rep = Verity::Reporters::DocumentationReporter.new(io, color: false)
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
      inherited_group_tags: [], group_scopes: []
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
      inherited_group_tags: [], group_scopes: []
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
      inherited_group_tags: [], group_scopes: []
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

  def test_location_filter_matches_group_opening_line
    reset_verity_process_state!
    Dir.mktmpdir do |dir|
      f = File.join(dir, "scoped_test.rb")
      File.write(f, <<~RUBY)
        group "Box" do
          test "inside_one" do
          end
          test "inside_two" do
          end
        end

        test "outside" do
        end
      RUBY

      group_line = File.readlines(f).index { _1.include?('group "Box"') } + 1

      Dir.chdir(dir) do
        Verity.configure do |c|
          c.test_globs = [f]
          c.location_filters = [[File.expand_path(f), group_line]]
        end
        Verity.load_discovery!
        names = Verity.runnable_tests.map(&:description).sort
        assert_equal %w[inside_one inside_two], names
      end
    end
  end

  def test_location_filter_matches_test_line_only
    reset_verity_process_state!
    Dir.mktmpdir do |dir|
      f = File.join(dir, "one_test.rb")
      File.write(f, <<~RUBY)
        group "Box" do
          test "only_me" do
          end
          test "other" do
          end
        end
      RUBY

      lines = File.readlines(f)
      only_line = lines.index { _1.include?('test "only_me"') } + 1

      Dir.chdir(dir) do
        Verity.configure do |c|
          c.test_globs = [f]
          c.location_filters = [[File.expand_path(f), only_line]]
        end
        Verity.load_discovery!
        names = Verity.runnable_tests.map(&:description)
        assert_equal ["only_me"], names
      end
    end
  end

  def test_location_filter_warns_when_nothing_matches
    reset_verity_process_state!
    Dir.mktmpdir do |dir|
      f = File.join(dir, "emptyish_test.rb")
      File.write(f, <<~RUBY)
        test "solo" do
        end
      RUBY

      Dir.chdir(dir) do
        Verity.configure do |c|
          c.test_globs = [f]
          c.location_filters = [[File.expand_path(f), 999]]
        end
        Verity.load_discovery!
        _err = capture_io { assert_empty Verity.runnable_tests }.last
        assert_match(/no tests matched location filter/, _err)
      end
    end
  end
end
