# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/verity/assertions"

class AssertionsTest < Minitest::Test
  AE = Verity::AssertionError

  # ── assert / refute ────────────────────────────────────────────────────────

  def test_assert_passes_with_truthy
    # Arrange
    subj = assertion_subject
    # Act & Assert
    subj.assert(true)
    subj.assert("value")
    subj.assert(1)
  end

  def test_assert_fails_with_false
    # Arrange
    subj = assertion_subject
    # Act
    err = assert_raises(AE) { subj.assert(false) }
    # Assert
    assert_match(/Expected truthy/, err.message)
  end

  def test_assert_fails_with_nil
    # Arrange
    subj = assertion_subject
    # Act & Assert
    assert_raises(AE) { subj.assert(nil) }
  end

  def test_assert_string_message_on_failure
    # Arrange
    subj = assertion_subject
    # Act
    err = assert_raises(AE) { subj.assert(false, message: "custom msg") }
    # Assert
    assert_match(/custom msg/, err.message)
  end

  def test_assert_proc_message_called_on_failure
    # Arrange
    subj = assertion_subject
    called = false
    # Act
    assert_raises(AE) { subj.assert(false, message: -> { called = true; "msg" }) }
    # Assert
    assert(called)
  end

  def test_assert_proc_message_not_called_on_pass
    # Arrange
    subj = assertion_subject
    called = false
    # Act
    subj.assert(true, message: -> { called = true; "msg" })
    # Assert
    refute(called)
  end

  def test_refute_passes_with_falsy
    # Arrange
    subj = assertion_subject
    # Act & Assert
    subj.refute(false)
    subj.refute(nil)
  end

  def test_refute_fails_with_truthy
    # Arrange
    subj = assertion_subject
    # Act & Assert
    assert_raises(AE) { subj.refute("truthy") }
  end

  # ── assert_equal / refute_equal ────────────────────────────────────────────

  def test_assert_equal_passes
    # Arrange
    subj = assertion_subject
    # Act & Assert
    subj.assert_equal(actual: 1, expected: 1)
    subj.assert_equal(actual: "a", expected: "a")
  end

  def test_assert_equal_fails
    # Arrange
    subj = assertion_subject
    # Act
    err = assert_raises(AE) { subj.assert_equal(actual: 1, expected: 2) }
    # Assert
    assert_match(/actual/, err.message)
    assert_match(/expected/, err.message)
  end

  def test_assert_equal_diff_shows_both_values
    # Arrange
    subj = assertion_subject
    # Act
    err = assert_raises(AE) { subj.assert_equal(actual: "guest", expected: "admin") }
    # Assert
    assert_match(/"guest"/, err.message)
    assert_match(/"admin"/, err.message)
  end

  def test_refute_equal_passes
    # Arrange
    subj = assertion_subject
    # Act & Assert
    subj.refute_equal(actual: 1, expected: 2)
  end

  def test_refute_equal_fails_when_equal
    # Arrange
    subj = assertion_subject
    # Act & Assert
    assert_raises(AE) { subj.refute_equal(actual: 1, expected: 1) }
  end

  # ── assert_same / refute_same ──────────────────────────────────────────────

  def test_assert_same_passes_with_identical_object
    # Arrange
    subj = assertion_subject
    obj = Object.new
    # Act & Assert
    subj.assert_same(actual: obj, expected: obj)
  end

  def test_assert_same_fails_with_equal_but_different_objects
    # Arrange
    subj = assertion_subject
    # "abc" (frozen literal) and String.new("abc") are equal but distinct objects
    # Act & Assert
    assert_raises(AE) { subj.assert_same(actual: "abc", expected: String.new("abc")) }
  end

  def test_refute_same_passes_with_different_objects
    # Arrange
    subj = assertion_subject
    # Act & Assert
    subj.refute_same(actual: "abc", expected: String.new("abc"))
  end

  def test_refute_same_fails_with_identical_object
    # Arrange
    subj = assertion_subject
    obj = :symbol
    # Act & Assert
    assert_raises(AE) { subj.refute_same(actual: obj, expected: obj) }
  end

  # ── assert_raises ──────────────────────────────────────────────────────────

  def test_assert_raises_passes
    # Arrange
    subj = assertion_subject
    # Act & Assert
    subj.assert_raises(RuntimeError) { raise RuntimeError, "boom" }
  end

  def test_assert_raises_returns_exception
    # Arrange
    subj = assertion_subject
    # Act
    err = subj.assert_raises(RuntimeError) { raise RuntimeError, "boom" }
    # Assert
    assert_equal "boom", err.message
  end

  def test_assert_raises_passes_for_subclass
    # Arrange
    subj = assertion_subject
    # Act & Assert
    subj.assert_raises(StandardError) { raise RuntimeError, "boom" }
  end

  def test_assert_raises_fails_when_nothing_raised
    # Arrange
    subj = assertion_subject
    # Act
    err = assert_raises(AE) { subj.assert_raises(RuntimeError) {} }
    # Assert
    assert_match(/nothing was raised/, err.message)
  end

  def test_assert_raises_fails_when_wrong_class_raised
    # Arrange
    subj = assertion_subject
    # Act
    err = assert_raises(AE) { subj.assert_raises(ArgumentError) { raise RuntimeError, "boom" } }
    # Assert
    assert_match(/RuntimeError/, err.message)
  end

  def test_assert_raises_requires_at_least_one_class
    # Arrange
    subj = assertion_subject
    # Act & Assert
    assert_raises(ArgumentError) { subj.assert_raises { raise "x" } }
  end

  def test_assert_raises_match_string_passes
    # Arrange
    subj = assertion_subject
    # Act & Assert
    subj.assert_raises(RuntimeError, match: "boom") { raise RuntimeError, "big boom" }
  end

  def test_assert_raises_match_string_fails_when_no_match
    # Arrange
    subj = assertion_subject
    # Act
    err = assert_raises(AE) { subj.assert_raises(RuntimeError, match: "boom") { raise RuntimeError, "silence" } }
    # Assert
    assert_match(/did not match/, err.message)
  end

  def test_assert_raises_match_regexp_passes
    # Arrange
    subj = assertion_subject
    # Act & Assert
    subj.assert_raises(RuntimeError, match: /\d+/) { raise RuntimeError, "error 42" }
  end

  def test_assert_raises_match_regexp_fails_when_no_match
    # Arrange
    subj = assertion_subject
    # Act & Assert
    assert_raises(AE) { subj.assert_raises(RuntimeError, match: /\d+/) { raise RuntimeError, "no digits" } }
  end

  # ── refute_raises — empty classes, no match ────────────────────────────────

  def test_refute_raises_empty_no_match_passes
    # Arrange
    subj = assertion_subject
    # Act & Assert
    subj.refute_raises { 1 + 1 }
  end

  def test_refute_raises_empty_no_match_fails_when_any_exception_raised
    # Arrange
    subj = assertion_subject
    # Act & Assert
    assert_raises(AE) { subj.refute_raises { raise "oops" } }
  end

  # ── refute_raises — empty classes, with match ──────────────────────────────

  def test_refute_raises_empty_match_passes_when_no_exception
    # Arrange
    subj = assertion_subject
    # Act & Assert
    subj.refute_raises(match: "oops") { 1 + 1 }
  end

  def test_refute_raises_empty_match_string_fails_when_message_matches
    # Arrange
    subj = assertion_subject
    # Act & Assert
    assert_raises(AE) { subj.refute_raises(match: "oops") { raise "big oops" } }
  end

  def test_refute_raises_empty_match_reraises_when_message_does_not_match
    # Arrange
    subj = assertion_subject
    # Act & Assert
    assert_raises(RuntimeError) { subj.refute_raises(match: "oops") { raise RuntimeError, "something else" } }
  end

  def test_refute_raises_empty_match_regexp_fails_when_message_matches
    # Arrange
    subj = assertion_subject
    # Act & Assert
    assert_raises(AE) { subj.refute_raises(match: /\d+/) { raise "error 42" } }
  end

  # ── refute_raises — non-empty classes, no match ────────────────────────────

  def test_refute_raises_classes_no_match_passes_when_no_exception
    # Arrange
    subj = assertion_subject
    # Act & Assert
    subj.refute_raises(RuntimeError) { 1 + 1 }
  end

  def test_refute_raises_classes_no_match_fails_when_listed_class_raised
    # Arrange
    subj = assertion_subject
    # Act & Assert
    assert_raises(AE) { subj.refute_raises(RuntimeError) { raise RuntimeError, "boom" } }
  end

  def test_refute_raises_classes_no_match_propagates_unlisted_exception
    # Arrange
    subj = assertion_subject
    # Act & Assert
    assert_raises(ArgumentError) { subj.refute_raises(RuntimeError) { raise ArgumentError, "wrong" } }
  end

  # ── refute_raises — non-empty classes, with match ──────────────────────────

  def test_refute_raises_classes_match_passes_when_class_matches_but_not_message
    # Arrange
    subj = assertion_subject
    # Act & Assert
    subj.refute_raises(RuntimeError, match: "specific") { raise RuntimeError, "something else" }
  end

  def test_refute_raises_classes_match_fails_when_class_and_message_both_match
    # Arrange
    subj = assertion_subject
    # Act & Assert
    assert_raises(AE) { subj.refute_raises(RuntimeError, match: "boom") { raise RuntimeError, "boom" } }
  end

  # ── assert_in_delta / refute_in_delta ──────────────────────────────────────

  def test_assert_in_delta_passes_within_delta
    # Arrange
    subj = assertion_subject
    # Act & Assert
    subj.assert_in_delta(expected: 1.0, actual: 1.05, delta: 0.1)
  end

  def test_assert_in_delta_passes_at_exact_boundary
    # Arrange
    subj = assertion_subject
    # Act & Assert
    subj.assert_in_delta(expected: 1.0, actual: 1.1, delta: 0.1)
  end

  def test_assert_in_delta_fails_outside_delta
    # Arrange
    subj = assertion_subject
    # Act & Assert
    assert_raises(AE) { subj.assert_in_delta(expected: 1.0, actual: 1.2, delta: 0.1) }
  end

  def test_refute_in_delta_passes_outside_delta
    # Arrange
    subj = assertion_subject
    # Act & Assert
    subj.refute_in_delta(expected: 1.0, actual: 1.2, delta: 0.1)
  end

  def test_refute_in_delta_fails_within_delta
    # Arrange
    subj = assertion_subject
    # Act & Assert
    assert_raises(AE) { subj.refute_in_delta(expected: 1.0, actual: 1.05, delta: 0.1) }
  end

  def test_refute_in_delta_fails_at_exact_boundary
    # Arrange
    subj = assertion_subject
    # Act & Assert
    assert_raises(AE) { subj.refute_in_delta(expected: 1.0, actual: 1.1, delta: 0.1) }
  end

  # ── assert_match / refute_match ────────────────────────────────────────────

  def test_assert_match_passes_with_regexp
    # Arrange
    subj = assertion_subject
    # Act & Assert
    subj.assert_match(pattern: /hel+o/, actual: "hello")
  end

  def test_assert_match_passes_with_string_pattern
    # Arrange
    subj = assertion_subject
    # Act & Assert
    subj.assert_match(pattern: "ell", actual: "hello")
  end

  def test_assert_match_fails_with_non_matching_regexp
    # Arrange
    subj = assertion_subject
    # Act & Assert
    assert_raises(AE) { subj.assert_match(pattern: /\d+/, actual: "no digits") }
  end

  def test_assert_match_fails_with_non_matching_string
    # Arrange
    subj = assertion_subject
    # Act & Assert
    assert_raises(AE) { subj.assert_match(pattern: "xyz", actual: "hello") }
  end

  def test_refute_match_passes_with_non_matching_regexp
    # Arrange
    subj = assertion_subject
    # Act & Assert
    subj.refute_match(pattern: /\d+/, actual: "no digits")
  end

  def test_refute_match_passes_with_non_matching_string
    # Arrange
    subj = assertion_subject
    # Act & Assert
    subj.refute_match(pattern: "xyz", actual: "hello")
  end

  def test_refute_match_fails_with_matching_regexp
    # Arrange
    subj = assertion_subject
    # Act & Assert
    assert_raises(AE) { subj.refute_match(pattern: /hel+o/, actual: "hello") }
  end

  def test_refute_match_fails_with_matching_string
    # Arrange
    subj = assertion_subject
    # Act & Assert
    assert_raises(AE) { subj.refute_match(pattern: "ell", actual: "hello") }
  end

  # ── assert_includes / refute_includes ──────────────────────────────────────

  def test_assert_includes_passes_with_array
    # Arrange
    subj = assertion_subject
    # Act & Assert
    subj.assert_includes(item: 2, collection: [1, 2, 3])
  end

  def test_assert_includes_fails_when_not_in_array
    # Arrange
    subj = assertion_subject
    # Act & Assert
    assert_raises(AE) { subj.assert_includes(item: 5, collection: [1, 2, 3]) }
  end

  def test_assert_includes_passes_with_string_collection
    # Arrange
    subj = assertion_subject
    # Act & Assert
    subj.assert_includes(item: "ell", collection: "hello")
  end

  def test_assert_includes_fails_when_not_in_string
    # Arrange
    subj = assertion_subject
    # Act & Assert
    assert_raises(AE) { subj.assert_includes(item: "xyz", collection: "hello") }
  end

  def test_refute_includes_passes_when_not_in_collection
    # Arrange
    subj = assertion_subject
    # Act & Assert
    subj.refute_includes(item: 5, collection: [1, 2, 3])
  end

  def test_refute_includes_fails_when_in_collection
    # Arrange
    subj = assertion_subject
    # Act & Assert
    assert_raises(AE) { subj.refute_includes(item: 2, collection: [1, 2, 3]) }
  end

  # ── message: Proc laziness ──────────────────────────────────────────────────

  def test_proc_message_not_called_on_passing_assertion
    # Arrange
    subj = assertion_subject
    called = false
    # Act
    subj.assert_equal(actual: 1, expected: 1, message: -> { called = true; "msg" })
    # Assert
    refute(called)
  end

  def test_proc_message_called_on_failing_assertion
    # Arrange
    subj = assertion_subject
    called = false
    # Act
    assert_raises(AE) { subj.assert_equal(actual: 1, expected: 2, message: -> { called = true; "msg" }) }
    # Assert
    assert(called)
  end

  private

  # Fresh delegate so Verity assertions are not confused with Minitest's assert_*.
  def assertion_subject
    Class.new { include Verity::Assertions }.new
  end
end
