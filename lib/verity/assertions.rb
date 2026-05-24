# frozen_string_literal: true

require "pp"

module Verity
  # Public: Raised when an assertion fails. Distinct from unexpected exceptions
  # so the runner can differentiate assertion failures from errors.
  class AssertionError < StandardError; end

  # Public: Raised when a test body runs longer than its `timeout:` (see DSL).
  class TestTimeoutError < StandardError; end

  # Public: Assertion methods mixed into the DSL. Every assertion has a
  # corresponding `refute_*` negation. All accept an optional `message:`
  # keyword that overrides the default failure text.
  module Assertions
    # Public: Assert that a value is truthy.
    #
    # check   - The value to test.
    # message - Optional String or Proc failure message.
    #
    # Raises AssertionError if check is falsy.
    def assert(check, message: nil)
      return if check
      fail_assertion(message) { "Expected truthy but got #{check.inspect}" }
    end

    # Public: Assert that a value is falsy.
    #
    # check   - The value to test.
    # message - Optional String or Proc failure message.
    #
    # Raises AssertionError if check is truthy.
    def refute(check, message: nil)
      return unless check
      fail_assertion(message) { "Expected falsy but got #{check.inspect}" }
    end

    # Public: Assert that a value is nil.
    #
    # actual  - The value to test.
    # message - Optional String or Proc failure message.
    #
    # Raises AssertionError when actual is not nil.
    def assert_nil(actual, message: nil)
      return if actual.nil?
      fail_assertion(message) { "Expected nil but got #{actual.inspect}" }
    end

    # Public: Assert that a value is not nil.
    #
    # actual  - The value to test.
    # message - Optional String or Proc failure message.
    #
    # Raises AssertionError when actual is nil.
    def refute_nil(actual, message: nil)
      return unless actual.nil?
      fail_assertion(message) { "Expected non-nil but got nil" }
    end

    # Public: Assert that two values are equal using `==`.
    #
    # actual   - The value produced by the code under test.
    # expected - The reference value.
    # message  - Optional String or Proc failure message.
    #
    # Raises AssertionError when actual != expected.
    def assert_equal(actual:, expected:, message: nil)
      return if actual == expected
      fail_assertion(message) { "Expected values to be equal\n#{format_diff(actual, expected)}" }
    end

    # Public: Assert that two values are NOT equal using `==`.
    #
    # actual   - The value produced by the code under test.
    # expected - The reference value that should differ.
    # message  - Optional String or Proc failure message.
    #
    # Raises AssertionError when actual == expected.
    def refute_equal(actual:, expected:, message: nil)
      return unless actual == expected
      fail_assertion(message) { "Expected values to differ, but both were #{actual.inspect}" }
    end

    # Public: Assert that two references point to the same object (identity
    # via `equal?`).
    #
    # actual   - The object produced by the code under test.
    # expected - The exact object expected.
    # message  - Optional String or Proc failure message.
    #
    # Raises AssertionError when the objects are not identical.
    def assert_same(actual:, expected:, message: nil)
      return if actual.equal?(expected)
      fail_assertion(message) do
        "Expected same object\n" \
          "  actual:   #{actual.inspect} (object_id: #{actual.object_id})\n" \
          "  expected: #{expected.inspect} (object_id: #{expected.object_id})"
      end
    end

    # Public: Assert that two references are NOT the same object.
    #
    # actual   - The object produced by the code under test.
    # expected - The object that should be a different instance.
    # message  - Optional String or Proc failure message.
    #
    # Raises AssertionError when the objects are identical.
    def refute_same(actual:, expected:, message: nil)
      return unless actual.equal?(expected)
      fail_assertion(message) do
        "Expected different objects, both were #{actual.inspect} (object_id: #{actual.object_id})"
      end
    end

    # Public: Assert that the block raises one of the given exception classes.
    # Optionally verify the error message matches a pattern.
    #
    # error_classes - One or more Exception subclasses expected.
    # match         - String or Regexp matched against the error message (default nil).
    # message       - Optional String or Proc failure message.
    # block         - Block expected to raise.
    #
    # Examples
    #
    #   assert_raises(ArgumentError) { Integer("nope") }
    #   # => #<ArgumentError: ...>
    #
    # Returns the caught exception on success.
    # Raises ArgumentError if no error classes are given.
    # Raises AssertionError if the block does not raise as expected.
    def assert_raises(*error_classes, match: nil, message: nil, &block)
      raise ArgumentError, "assert_raises requires at least one error class" if error_classes.empty?

      begin
        block.call
      rescue *error_classes => e
        if match
          satisfied = match.is_a?(Regexp) ? e.message =~ match : e.message.include?(match)
          unless satisfied
            fail_assertion(message) do
              "#{e.class} raised but message #{e.message.inspect} did not match #{match.inspect}"
            end
          end
        end
        return e
      rescue => e
        fail_assertion(message) do
          "Expected #{error_class_names(error_classes)} but #{e.class} was raised: #{e.message}"
        end
      end

      fail_assertion(message) { "Expected #{error_class_names(error_classes)} but nothing was raised" }
    end

    # Public: Assert that the block does NOT raise the specified exceptions.
    # When no error classes are given, asserts that nothing is raised at all.
    # When a match pattern is provided, only matching messages trigger failure.
    #
    # error_classes - Zero or more Exception subclasses that must not be raised.
    # match         - String or Regexp; only messages matching this cause failure (default nil).
    # message       - Optional String or Proc failure message.
    # block         - Block to execute.
    #
    # Raises AssertionError if the block raises a matching exception.
    def refute_raises(*error_classes, match: nil, message: nil, &block)
      if error_classes.empty?
        begin
          block.call
        rescue => e
          if match
            satisfied = match.is_a?(Regexp) ? e.message =~ match : e.message.include?(match)
            raise unless satisfied
            fail_assertion(message) do
              "Expected no exception with message matching #{match.inspect}, " \
                "but #{e.class} was raised: #{e.message}"
            end
          else
            fail_assertion(message) { "Expected no exception but #{e.class} was raised: #{e.message}" }
          end
        end
      else
        begin
          block.call
        rescue *error_classes => e
          if match
            satisfied = match.is_a?(Regexp) ? e.message =~ match : e.message.include?(match)
            if satisfied
              fail_assertion(message) do
                "#{e.class} raised with message matching #{match.inspect}: #{e.message}"
              end
            end
          else
            fail_assertion(message) do
              "Expected #{error_class_names(error_classes)} not to be raised, " \
                "but #{e.class} was raised: #{e.message}"
            end
          end
        end
      end
    end

    # Public: Assert that a numeric value is within delta of the expected value.
    # Internally adjusts for floating-point epsilon scaling.
    #
    # expected - Numeric reference value.
    # actual   - Numeric value under test.
    # delta    - Numeric maximum allowed difference.
    # message  - Optional String or Proc failure message.
    #
    # Raises AssertionError when the difference exceeds delta.
    def assert_in_delta(expected:, actual:, delta:, message: nil)
      return if within_delta?(actual, expected, delta)
      fail_assertion(message) do
        "Expected #{actual.inspect} to be within #{delta} of #{expected.inspect}, " \
          "difference was #{(actual - expected).abs}"
      end
    end

    # Public: Assert that a numeric value is NOT within delta of the expected value.
    #
    # expected - Numeric reference value.
    # actual   - Numeric value under test.
    # delta    - Numeric maximum allowed difference.
    # message  - Optional String or Proc failure message.
    #
    # Raises AssertionError when the difference is within delta.
    def refute_in_delta(expected:, actual:, delta:, message: nil)
      return unless within_delta?(actual, expected, delta)
      fail_assertion(message) do
        "Expected #{actual.inspect} to be outside #{delta} of #{expected.inspect}, " \
          "but difference was #{(actual - expected).abs}"
      end
    end

    # Public: Assert that a value matches a Regexp or includes a String.
    #
    # pattern - Regexp or String to match against.
    # actual  - The value under test.
    # message - Optional String or Proc failure message.
    #
    # Raises AssertionError when actual does not match pattern.
    def assert_match(pattern:, actual:, message: nil)
      return if match?(pattern, actual)
      fail_assertion(message) { "Expected #{actual.inspect} to match #{pattern.inspect}" }
    end

    # Public: Assert that a value does NOT match a Regexp or include a String.
    #
    # pattern - Regexp or String to match against.
    # actual  - The value under test.
    # message - Optional String or Proc failure message.
    #
    # Raises AssertionError when actual matches pattern.
    def refute_match(pattern:, actual:, message: nil)
      return unless match?(pattern, actual)
      fail_assertion(message) { "Expected #{actual.inspect} not to match #{pattern.inspect}" }
    end

    # Public: Assert that a collection includes the given item.
    #
    # item       - The element to look for.
    # collection - An object responding to `include?`.
    # message    - Optional String or Proc failure message.
    #
    # Raises AssertionError when item is not found.
    def assert_includes(item:, collection:, message: nil)
      return if collection.include?(item)
      fail_assertion(message) { "Expected collection to include #{item.inspect}" }
    end

    # Public: Assert that a collection does NOT include the given item.
    #
    # item       - The element to look for.
    # collection - An object responding to `include?`.
    # message    - Optional String or Proc failure message.
    #
    # Raises AssertionError when item is found.
    def refute_includes(item:, collection:, message: nil)
      return unless collection.include?(item)
      fail_assertion(message) { "Expected collection not to include #{item.inspect}" }
    end

    private

    def fail_assertion(custom_message, &default_message)
      msg = custom_message ? resolve_message(custom_message) : default_message.call
      raise Verity::AssertionError, msg
    end

    def resolve_message(message)
      message.is_a?(Proc) ? message.call : message
    end

    def within_delta?(actual, expected, delta)
      # Scale epsilon by the magnitude of the operands to account for floating
      # point representation error (e.g. (1.1 - 1.0).abs > 0.1 in IEEE 754).
      tolerance = delta + Float::EPSILON * [actual.abs, expected.abs].max
      (actual - expected).abs <= tolerance
    end

    def match?(pattern, actual)
      pattern.is_a?(Regexp) ? actual =~ pattern : actual.include?(pattern)
    end

    def error_class_names(classes)
      classes.map(&:name).join(", ")
    end

    def format_diff(actual, expected)
      actual_str   = PP.pp(actual,   +"").chomp
      expected_str = PP.pp(expected, +"").chomp
      "  actual:   #{actual_str}\n  expected: #{expected_str}"
    end
  end
end
