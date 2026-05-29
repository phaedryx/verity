# frozen_string_literal: true

# Dogfood mirror of test/tag_filter_test.rb — structural checks only.

test "parse_tag_filter_token strips colons and whitespace" do
  assert_equal actual: Verity.parse_tag_filter_token(" :x "), expected: :x
end

test "parse_tag_filter_token returns nil for blank" do
  assert_nil Verity.parse_tag_filter_token("  ")
end
