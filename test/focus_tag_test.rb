# frozen_string_literal: true

# Triple suite (compare / redundant proof): verity/focus_tag_test.rb · spec/verity/focus_tag_spec.rb

require "minitest/autorun"
require "fileutils"
require_relative "../lib/verity"
require_relative "verity_test_helper"

class FocusTagTest < Minitest::Test
  include VerityTestHelper

  def test_runnable_without_focus_is_all_non_skipped
    reset_verity_process_state!
    reg(
      t("a", [], :a),
      t("b", [], :b)
    )

    assert_equal 2, Verity.runnable_tests.size
    refute Verity.focus_filter_active?(Verity::Registry.all.reject { Verity.skipped?(_1) })
  end

  def test_runnable_with_focus_is_only_focused
    reset_verity_process_state!
    reg(
      t("run", [:focus], :f),
      t("ignore", [], :n)
    )

    assert_equal 1, Verity.runnable_tests.size
    assert_equal :f, Verity.runnable_tests.first.fn.call
    assert Verity.focus_filter_active?(Verity::Registry.all.reject { Verity.skipped?(_1) })
  end

  def test_focus_ignored_when_every_runnable_is_focused
    reset_verity_process_state!
    reg(
      t("a", [:focus], :a),
      t("b", [:focus], :b)
    )

    assert_equal 2, Verity.runnable_tests.size
    refute Verity.focus_filter_active?(Verity::Registry.all.reject { Verity.skipped?(_1) })
  end

  def test_skip_wins_over_focus
    reset_verity_process_state!
    reg(
      t("skip_focus", %i[skip focus], :bad)
    )

    assert_empty Verity.runnable_tests
  end

  def test_runner_run_only_focused
    reset_verity_process_state!
    ran = []
    reg(
      t("f", [:focus], -> { ran << :f }),
      t("n", [], -> { ran << :n })
    )

    assert Verity::Runner.new.run
    assert_equal [:f], ran
  end

  def test_verity_run_respects_focus
    reset_verity_process_state!
    Dir.mktmpdir do |dir|
      verity_dir = File.join(dir, "verity")
      FileUtils.mkdir_p(verity_dir)
      File.write(File.join(verity_dir, "t_test.rb"), <<~RUBY)
        test "ignored" do
          assert false
        end

        test "only", focus: true do
          assert true
        end
      RUBY

      Dir.chdir(dir) do
        Verity.configure do |c|
          c.test_globs = ["verity/**/*_test.rb"]
          c.manifest_path = ":memory:"
          c.worker_count = 1
        end

        assert Verity.run
        assert_equal 2, Verity::Registry.all.size
        assert_equal 1, Verity.runnable_tests.size
      end
    end
  end

  private

  def t(desc, tags, fn_sym_or_proc)
    sym = fn_sym_or_proc.is_a?(Proc) ? fn_sym_or_proc : -> { fn_sym_or_proc }
    Verity::Test.new(
      fingerprint: "#{desc.gsub(/\s+/, '_')}.rb:#{'a' * 16}",
      description: desc,
      tags: tags - %i[skip focus],
      skip: tags.include?(:skip),
      focus: tags.include?(:focus),
      timeout: nil,
      requires: [],
      resources: {},
      file: "#{desc}.rb",
      line: 1,
      fn: sym,
      group_path: [],
      inherited_group_tags: [], group_scopes: []
    )
  end

  def reg(*tests)
    tests.each { Verity::Registry.register(_1) }
  end
end
