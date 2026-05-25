# frozen_string_literal: true

# Triple suite: test/inert_behavioral_tags_test.rb
# Locks the clean break: :skip / :focus as descriptive tags do nothing.

test "skip symbol in tags is an inert label" do
  t = Verity::Test.new(
    fingerprint: "inert.rb:#{"a" * 16}", description: "inert", tags: [:skip],
    timeout: nil, requires: [], resources: {}, file: "inert.rb", line: 1, fn: -> {},
    group_path: [], inherited_group_tags: [], group_scopes: []
  )
  refute Verity.skipped?(t)
  assert_includes item: :skip, collection: Verity.effective_tags(t)
end

test "focus symbol in tags is an inert label" do
  t = Verity::Test.new(
    fingerprint: "inertf.rb:#{"b" * 16}", description: "inertf", tags: [:focus],
    timeout: nil, requires: [], resources: {}, file: "inertf.rb", line: 1, fn: -> {},
    group_path: [], inherited_group_tags: [], group_scopes: []
  )
  refute Verity.focused?(t)
end
