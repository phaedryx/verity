# frozen_string_literal: true

# Triple suite: verity/inert_behavioral_tags_test.rb
# Locks the clean break: :skip / :focus as descriptive tags do nothing.

require "minitest/autorun"
require_relative "../lib/verity"
require_relative "verity_test_helper"

class InertBehavioralTagsTest < Minitest::Test
  include VerityTestHelper

  def setup
    reset_verity_process_state!
    Verity.clear_group_stack!
  end

  def last(desc)
    Verity::Registry.all.reverse.find { _1.description == desc }
  end

  def test_skip_symbol_in_tags_does_not_skip
    Object.new.extend(Verity::DSL).test("inert_skip", tags: [:skip]) {}
    refute Verity.skipped?(last("inert_skip"))
    assert_includes Verity.effective_tags(last("inert_skip")), :skip # still a plain label
  end

  def test_focus_symbol_in_tags_does_not_focus
    Object.new.extend(Verity::DSL).test("inert_focus", tags: [:focus]) {}
    refute Verity.focused?(last("inert_focus"))
  end
end
