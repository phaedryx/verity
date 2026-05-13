# frozen_string_literal: true

# Dogfood mirror of test/assertions_test.rb — exercises Verity::Assertions via the DSL.
DOGFOOD_AE = Verity::AssertionError

test "assert passes with truthy values" do
  assert true
  assert "value"
  assert 1
end

test "assert fails with false" do
  err = assert_raises(DOGFOOD_AE) { assert false }
  assert_match pattern: /Expected truthy/, actual: err.message
end

test "assert_equal passes" do
  assert_equal actual: 1, expected: 1
end

test "assert_equal fails with message" do
  err = assert_raises(DOGFOOD_AE) { assert_equal actual: 1, expected: 2 }
  assert_match pattern: /actual/, actual: err.message
end

test "refute_equal passes when different" do
  refute_equal actual: 1, expected: 2
end

test "assert_same uses object identity" do
  obj = Object.new
  assert_same actual: obj, expected: obj
end

test "assert_raises catches runtime error" do
  err = assert_raises(RuntimeError) { raise "boom" }
  assert_equal actual: err.message, expected: "boom"
end

test "assert_in_delta within tolerance" do
  assert_in_delta expected: 1.0, actual: 1.05, delta: 0.1
end

test "assert_match regexp" do
  assert_match pattern: /hel+o/, actual: "hello"
end

test "assert_includes array" do
  assert_includes item: 2, collection: [1, 2, 3]
end

test "refute_match when no match" do
  refute_match pattern: /\d+/, actual: "no digits"
end
