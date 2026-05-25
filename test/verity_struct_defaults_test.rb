# frozen_string_literal: true

# Triple suite note: struct-level defaults are Minitest-only (no behavior, just construction).

require "minitest/autorun"
require_relative "../lib/verity"

class VerityStructDefaultsTest < Minitest::Test
  def base_attrs
    {
      fingerprint: "x.rb:#{"a" * 16}", description: "d", tags: [], timeout: nil,
      requires: [], resources: {}, file: "x.rb", line: 1, fn: -> {},
      group_path: [], inherited_group_tags: [], group_scopes: []
    }
  end

  def test_skip_and_focus_default_to_false_when_omitted
    t = Verity::Test.new(**base_attrs)
    refute t.skip
    refute t.focus
  end

  def test_skip_and_focus_can_be_set
    t = Verity::Test.new(**base_attrs, skip: true, focus: true)
    assert t.skip
    assert t.focus
  end
end
