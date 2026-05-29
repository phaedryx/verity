# frozen_string_literal: true

# Triple suite (compare / redundant proof): verity/tag_filter_test.rb · spec/verity/tag_filter_spec.rb

require "minitest/autorun"
require "open3"
require "fileutils"
require_relative "../lib/verity"
require_relative "verity_test_helper"

class TagFilterTest < Minitest::Test
  include VerityTestHelper

  BIN = File.expand_path("../bin/verity", __dir__)

  def teardown
    reset_verity_process_state!
    super
  end

  def test_runnable_unfiltered_when_no_tag_preferences
    reset_verity_process_state!
    reg(tt("a", {}, :a), tt("b", {}, :b))
    assert_equal 2, Verity.runnable_tests.size
    refute Verity.tag_filter_configured?
  end

  def test_included_tags_use_or_semantics
    reset_verity_process_state!
    reg(
      tt("slow", { tags: [:slow] }, :s),
      tt("wip", { tags: [:wip] }, :w),
      tt("plain", {}, :p)
    )
    Verity.configure { |c| c.included_tags = %i[slow wip] }
    descriptions = Verity.runnable_tests.map(&:description).sort
    assert_equal %w[slow wip], descriptions
    assert Verity.tag_filter_configured?
  end

  def test_exclude_tag_drops_matching_tests
    reset_verity_process_state!
    reg(tt("keep", {}, :k), tt("drop", { tags: [:junk] }, :j))
    Verity.configure { |c| c.excluded_tags = [:junk] }
    assert_equal ["keep"], Verity.runnable_tests.map(&:description)
  end

  def test_exclude_wins_when_tag_overlaps_include
    reset_verity_process_state!
    reg(tt("mixed", { tags: %i[integration wip] }, :x))
    Verity.configure { |c| c.included_tags = [:integration]; c.excluded_tags = [:wip] }
    assert_empty Verity.runnable_tests
  end

  def test_group_inherited_tags_participate
    reset_verity_process_state!
    Verity.clear_group_stack!
    dsl = Object.new.extend(Verity::DSL)
    dsl.group "Outer", tags: [:integration] do
      dsl.test "leaf" do
        assert true
      end
    end
    Verity.configure { |c| c.included_tags = [:integration] }
    assert_equal ["leaf"], Verity.runnable_tests.map(&:description)
  end

  def test_warning_when_include_matches_nothing_and_suite_non_empty
    reset_verity_process_state!
    reg(tt("only_plain", {}, :p))
    Verity.configure { |c| c.included_tags = [:nope] }
    err = capture_io { Verity.runnable_tests(warn: true) }.last
    assert_match(/no tests matched --tag filter/, err)
    assert_empty Verity.runnable_tests
  end

  def test_runnable_tests_is_silent_by_default
    reset_verity_process_state!
    reg(tt("only_plain", {}, :p))
    Verity.configure { |c| c.included_tags = [:nope] }
    err = capture_io { Verity.runnable_tests }.last
    assert_empty err
  end

  def test_parse_tag_filter_token
    assert_equal :foo, Verity.parse_tag_filter_token("foo")
    assert_equal :foo, Verity.parse_tag_filter_token(":foo")
    assert_equal :bar_baz, Verity.parse_tag_filter_token("  bar_baz  ")
    assert_nil Verity.parse_tag_filter_token("   ")
    assert_nil Verity.parse_tag_filter_token("")
  end

  def test_cli_tag_and_exclude_filter_temp_project
    Dir.mktmpdir do |dir|
      vd = File.join(dir, "verity")
      FileUtils.mkdir_p(vd)
      File.write(File.join(vd, "t_test.rb"), <<~RUBY)
        test "a", tags: [:slow] do
          assert true
        end
        test "b", tags: [:fast] do
          assert false
        end
        test "c" do
          assert false
        end
      RUBY

      out, err, st = Open3.capture3(
        RbConfig.ruby, BIN, "--tag", "slow", "--exclude-tag", "fast",
        chdir: dir
      )
      assert_equal 0, st.exitstatus, "stderr: #{err}"
      assert_match(/1 passed/, out)
      assert_match(/0 failed/, out)
    end
  end

  def test_cli_empty_tag_exits_2
    _out, err, st = Open3.capture3(RbConfig.ruby, BIN, "--tag", "  ", chdir: Dir.mktmpdir)
    assert_equal 2, st.exitstatus
    assert_match(/non-empty name/, err)
  end

  private

  def tt(desc, opts, fn_val)
    tags = Array(opts[:tags])
    Verity::Test.new(
      fingerprint: "#{desc.gsub(/\s+/, '_')}.rb:#{'a' * 16}",
      description: desc,
      tags: tags,
      skip: opts[:skip] || false,
      focus: opts[:focus] || false,
      timeout: nil,
      requires: [],
      resources: {},
      file: "#{desc}.rb",
      line: 1,
      fn: fn_val.is_a?(Proc) ? fn_val : -> { fn_val },
      group_path: Array(opts[:group_path]),
      inherited_group_tags: Array(opts[:inherited_group_tags]),
      group_scopes: []
    )
  end

  def reg(*tests)
    tests.each { Verity::Registry.register(_1) }
  end
end
