# frozen_string_literal: true

# No triple-suite mirror: unit-level DSL/registration wiring. Scenario-level
# skip/focus behavior is proven in verity/ + spec/ (group_test, focus_tag, etc.).

require "minitest/autorun"
require_relative "../lib/verity"

class BehavioralKeywordRegistrationTest < Minitest::Test
  def setup
    Verity::Registry.clear
    Verity.clear_group_stack!
  end

  def last(desc)
    Verity::Registry.all.reverse.find { _1.description == desc }
  end

  def test_test_level_skip_and_focus_populate_fields
    Object.new.extend(Verity::DSL).instance_eval do
      test("k_skip", skip: true) {}
      test("k_focus", focus: true) {}
      test("k_plain") {}
    end
    assert last("k_skip").skip
    refute last("k_skip").focus
    assert last("k_focus").focus
    refute last("k_plain").skip
    refute last("k_plain").focus
  end

  def test_group_skip_and_focus_cascade_to_nested_tests
    Object.new.extend(Verity::DSL).instance_eval do
      group "WIP", skip: true do
        test("g_skip_inner") {}
      end
      group "Focus", focus: true do
        test("g_focus_inner") {}
      end
    end
    assert last("g_skip_inner").skip
    assert last("g_focus_inner").focus
  end

  def test_skip_and_focus_cascade_from_outer_group_through_inner_group
    Object.new.extend(Verity::DSL).instance_eval do
      group "Outer", skip: true do
        group "Inner" do
          test("deep_skip") {}
        end
      end
      group "OuterFocus", focus: true do
        group "InnerFocus" do
          test("deep_focus", skip: true) {}
        end
      end
    end
    assert last("deep_skip").skip       # inherited from grandparent group
    refute last("deep_skip").focus
    assert last("deep_focus").focus     # inherited from grandparent group
    assert last("deep_focus").skip      # own skip: true combined with focused ancestor
  end

  def test_descriptive_tags_still_cascade_independently
    Object.new.extend(Verity::DSL).instance_eval do
      group "Outer", tags: [:integration] do
        test("g_tagged", tags: [:unit]) {}
      end
    end
    assert_equal %i[integration unit], Verity.effective_tags(last("g_tagged"))
  end
end
