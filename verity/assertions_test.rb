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

test "refute passes with false" do
  refute false
end

test "refute fails with truthy" do
  err = assert_raises(DOGFOOD_AE) { refute "truthy" }
  assert_match pattern: /Expected falsy/, actual: err.message
end

test "refute_equal fails when equal" do
  err = assert_raises(DOGFOOD_AE) { refute_equal actual: 1, expected: 1 }
  assert_match pattern: /differ/, actual: err.message
end

test "assert_same fails with equal but different objects" do
  err = assert_raises(DOGFOOD_AE) { assert_same actual: "abc", expected: String.new("abc") }
  assert_match pattern: /same object/, actual: err.message
end

test "refute_same passes with different objects" do
  refute_same actual: "abc", expected: String.new("abc")
end

test "refute_same fails with identical object" do
  obj = :symbol
  assert_raises(DOGFOOD_AE) { refute_same actual: obj, expected: obj }
end

test "assert_raises with match string" do
  err = assert_raises(RuntimeError, match: "boom") { raise RuntimeError, "big boom" }
  assert_equal actual: err.class, expected: RuntimeError
end

test "assert_raises with match regexp" do
  assert_raises(RuntimeError, match: /\d+/) { raise RuntimeError, "error 42" }
end

test "assert_raises with match fails when no match" do
  err = assert_raises(DOGFOOD_AE) { assert_raises(RuntimeError, match: "boom") { raise RuntimeError, "silence" } }
  assert_match pattern: /did not match/, actual: err.message
end

test "refute_raises passes when nothing raised" do
  refute_raises { 1 + 1 }
end

test "refute_raises fails when exception raised" do
  assert_raises(DOGFOOD_AE) { refute_raises { raise "oops" } }
end

test "refute_raises with class passes when different class raised" do
  assert_raises(ArgumentError) { refute_raises(RuntimeError) { raise ArgumentError, "wrong" } }
end

test "refute_raises with class fails when listed class raised" do
  assert_raises(DOGFOOD_AE) { refute_raises(RuntimeError) { raise RuntimeError, "boom" } }
end

test "refute_raises with match passes when message does not match" do
  refute_raises(RuntimeError, match: "specific") { raise RuntimeError, "something else" }
end

test "refute_in_delta passes outside delta" do
  refute_in_delta expected: 1.0, actual: 1.2, delta: 0.1
end

test "refute_in_delta fails within delta" do
  assert_raises(DOGFOOD_AE) { refute_in_delta expected: 1.0, actual: 1.05, delta: 0.1 }
end

test "refute_match when no match" do
  refute_match pattern: /\d+/, actual: "no digits"
end

test "refute_match fails when matching" do
  assert_raises(DOGFOOD_AE) { refute_match pattern: /hel+o/, actual: "hello" }
end

test "refute_includes passes when not in collection" do
  refute_includes item: 5, collection: [1, 2, 3]
end

test "refute_includes fails when in collection" do
  assert_raises(DOGFOOD_AE) { refute_includes item: 2, collection: [1, 2, 3] }
end
