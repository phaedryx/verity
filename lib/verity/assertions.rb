# frozen_string_literal: true

require "pp"

module Verity
  class AssertionError < StandardError; end

  module Assertions
    def assert(check, message: nil)
      return if check
      fail_assertion(message) { "Expected truthy but got #{check.inspect}" }
    end

    def refute(check, message: nil)
      return unless check
      fail_assertion(message) { "Expected falsy but got #{check.inspect}" }
    end

    def assert_equal(actual:, expected:, message: nil)
      return if actual == expected
      fail_assertion(message) { "Expected values to be equal\n#{format_diff(actual, expected)}" }
    end

    def refute_equal(actual:, expected:, message: nil)
      return unless actual == expected
      fail_assertion(message) { "Expected values to differ, but both were #{actual.inspect}" }
    end

    def assert_same(actual:, expected:, message: nil)
      return if actual.equal?(expected)
      fail_assertion(message) do
        "Expected same object\n" \
          "  actual:   #{actual.inspect} (object_id: #{actual.object_id})\n" \
          "  expected: #{expected.inspect} (object_id: #{expected.object_id})"
      end
    end

    def refute_same(actual:, expected:, message: nil)
      return unless actual.equal?(expected)
      fail_assertion(message) do
        "Expected different objects, both were #{actual.inspect} (object_id: #{actual.object_id})"
      end
    end

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

    def assert_in_delta(expected:, actual:, delta:, message: nil)
      return if within_delta?(actual, expected, delta)
      fail_assertion(message) do
        "Expected #{actual.inspect} to be within #{delta} of #{expected.inspect}, " \
          "difference was #{(actual - expected).abs}"
      end
    end

    def refute_in_delta(expected:, actual:, delta:, message: nil)
      return unless within_delta?(actual, expected, delta)
      fail_assertion(message) do
        "Expected #{actual.inspect} to be outside #{delta} of #{expected.inspect}, " \
          "but difference was #{(actual - expected).abs}"
      end
    end

    def assert_match(pattern:, actual:, message: nil)
      return if match?(pattern, actual)
      fail_assertion(message) { "Expected #{actual.inspect} to match #{pattern.inspect}" }
    end

    def refute_match(pattern:, actual:, message: nil)
      return unless match?(pattern, actual)
      fail_assertion(message) { "Expected #{actual.inspect} not to match #{pattern.inspect}" }
    end

    def assert_includes(item:, collection:, message: nil)
      return if collection.include?(item)
      fail_assertion(message) { "Expected collection to include #{item.inspect}" }
    end

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
