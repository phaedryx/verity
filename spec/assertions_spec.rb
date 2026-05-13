# frozen_string_literal: true

require "rspec/core"
require "rspec/expectations"
require "rspec/mocks"
require_relative "../lib/verity/assertions"

RSpec.describe Verity::Assertions do
  AE = Verity::AssertionError

  def assertion_context
    Class.new { include Verity::Assertions }.new
  end

  # ── assert / refute ────────────────────────────────────────────────────────

  describe "#assert" do
    it "passes with truthy values" do
      # Arrange
      ctx = assertion_context

      # Act
      ctx.assert(true)
      ctx.assert("value")
      ctx.assert(1)

      # Assert — implicit (no exception)
    end

    it "fails with false" do
      # Arrange
      ctx = assertion_context

      # Act & Assert
      expect { ctx.assert(false) }.to raise_error(AE, /Expected truthy/)
    end

    it "fails with nil" do
      # Arrange
      ctx = assertion_context

      # Act & Assert
      expect { ctx.assert(nil) }.to raise_error(AE)
    end

    it "uses a string message on failure" do
      # Arrange
      ctx = assertion_context

      # Act & Assert
      expect { ctx.assert(false, message: "custom msg") }.to raise_error(AE, /custom msg/)
    end

    it "calls a proc message on failure" do
      # Arrange
      ctx = assertion_context
      called = false

      # Act & Assert
      expect {
        ctx.assert(false, message: -> { called = true; "msg" })
      }.to raise_error(AE)

      # Assert
      expect(called).to be true
    end

    it "does not call a proc message on pass" do
      # Arrange
      ctx = assertion_context
      called = false

      # Act
      ctx.assert(true, message: -> { called = true; "msg" })

      # Assert
      expect(called).to be false
    end
  end

  describe "#refute" do
    it "passes with falsy values" do
      # Arrange
      ctx = assertion_context

      # Act
      ctx.refute(false)
      ctx.refute(nil)

      # Assert — implicit
    end

    it "fails with truthy values" do
      # Arrange
      ctx = assertion_context

      # Act & Assert
      expect { ctx.refute("truthy") }.to raise_error(AE)
    end
  end

  # ── assert_equal / refute_equal ────────────────────────────────────────────

  describe "#assert_equal" do
    it "passes when values are equal" do
      # Arrange
      ctx = assertion_context

      # Act
      ctx.assert_equal(actual: 1, expected: 1)
      ctx.assert_equal(actual: "a", expected: "a")

      # Assert — implicit
    end

    it "fails when values differ" do
      # Arrange
      ctx = assertion_context

      # Act & Assert
      expect { ctx.assert_equal(actual: 1, expected: 2) }
        .to raise_error(AE, /actual.*expected/m)
    end

    it "includes both values in the failure message" do
      # Arrange
      ctx = assertion_context

      # Act & Assert
      expect { ctx.assert_equal(actual: "guest", expected: "admin") }
        .to raise_error(AE, /"guest".*"admin"/m)
    end
  end

  describe "#refute_equal" do
    it "passes when values differ" do
      # Arrange
      ctx = assertion_context

      # Act
      ctx.refute_equal(actual: 1, expected: 2)

      # Assert — implicit
    end

    it "fails when values are equal" do
      # Arrange
      ctx = assertion_context

      # Act & Assert
      expect { ctx.refute_equal(actual: 1, expected: 1) }.to raise_error(AE)
    end
  end

  # ── assert_same / refute_same ──────────────────────────────────────────────

  describe "#assert_same" do
    it "passes with the identical object" do
      # Arrange
      ctx = assertion_context
      obj = Object.new

      # Act
      ctx.assert_same(actual: obj, expected: obj)

      # Assert — implicit
    end

    it "fails with equal but distinct objects" do
      # Arrange
      ctx = assertion_context

      # Act & Assert
      expect { ctx.assert_same(actual: "abc", expected: String.new("abc")) }.to raise_error(AE)
    end
  end

  describe "#refute_same" do
    it "passes with distinct objects" do
      # Arrange
      ctx = assertion_context

      # Act
      ctx.refute_same(actual: "abc", expected: String.new("abc"))

      # Assert — implicit
    end

    it "fails with the identical object" do
      # Arrange
      ctx = assertion_context
      obj = :symbol

      # Act & Assert
      expect { ctx.refute_same(actual: obj, expected: obj) }.to raise_error(AE)
    end
  end

  # ── assert_raises ──────────────────────────────────────────────────────────

  describe "#assert_raises" do
    it "passes when the expected error is raised" do
      # Arrange
      ctx = assertion_context

      # Act
      ctx.assert_raises(RuntimeError) { raise RuntimeError, "boom" }

      # Assert — implicit
    end

    it "returns the raised exception" do
      # Arrange
      ctx = assertion_context

      # Act
      e = ctx.assert_raises(RuntimeError) { raise RuntimeError, "boom" }

      # Assert
      expect(e.message).to eq("boom")
    end

    it "passes for a subclass of the expected error" do
      # Arrange
      ctx = assertion_context

      # Act
      ctx.assert_raises(StandardError) { raise RuntimeError, "boom" }

      # Assert — implicit
    end

    it "fails when nothing is raised" do
      # Arrange
      ctx = assertion_context

      # Act & Assert
      expect { ctx.assert_raises(RuntimeError) {} }.to raise_error(AE, /nothing was raised/)
    end

    it "fails when a different error class is raised" do
      # Arrange
      ctx = assertion_context

      # Act & Assert
      expect { ctx.assert_raises(ArgumentError) { raise RuntimeError, "boom" } }
        .to raise_error(AE, /RuntimeError/)
    end

    it "requires at least one error class" do
      # Arrange
      ctx = assertion_context

      # Act & Assert
      expect { ctx.assert_raises { raise "x" } }.to raise_error(ArgumentError)
    end

    context "with match:" do
      it "passes when the message includes the string" do
        # Arrange
        ctx = assertion_context

        # Act
        ctx.assert_raises(RuntimeError, match: "boom") { raise RuntimeError, "big boom" }

        # Assert — implicit
      end

      it "fails when the message does not include the string" do
        # Arrange
        ctx = assertion_context

        # Act & Assert
        expect { ctx.assert_raises(RuntimeError, match: "boom") { raise RuntimeError, "silence" } }
          .to raise_error(AE, /did not match/)
      end

      it "passes when the message matches the regexp" do
        # Arrange
        ctx = assertion_context

        # Act
        ctx.assert_raises(RuntimeError, match: /\d+/) { raise RuntimeError, "error 42" }

        # Assert — implicit
      end

      it "fails when the message does not match the regexp" do
        # Arrange
        ctx = assertion_context

        # Act & Assert
        expect { ctx.assert_raises(RuntimeError, match: /\d+/) { raise RuntimeError, "no digits" } }
          .to raise_error(AE)
      end
    end
  end

  # ── refute_raises ──────────────────────────────────────────────────────────

  describe "#refute_raises" do
    context "with no error classes and no match" do
      it "passes when no exception is raised" do
        # Arrange
        ctx = assertion_context

        # Act
        ctx.refute_raises { 1 + 1 }

        # Assert — implicit
      end

      it "fails when any exception is raised" do
        # Arrange
        ctx = assertion_context

        # Act & Assert
        expect { ctx.refute_raises { raise "oops" } }.to raise_error(AE)
      end
    end

    context "with no error classes and match:" do
      it "passes when no exception is raised" do
        # Arrange
        ctx = assertion_context

        # Act
        ctx.refute_raises(match: "oops") { 1 + 1 }

        # Assert — implicit
      end

      it "fails when the message matches the string" do
        # Arrange
        ctx = assertion_context

        # Act & Assert
        expect { ctx.refute_raises(match: "oops") { raise "big oops" } }.to raise_error(AE)
      end

      it "re-raises when the message does not match" do
        # Arrange
        ctx = assertion_context

        # Act & Assert
        expect { ctx.refute_raises(match: "oops") { raise RuntimeError, "something else" } }
          .to raise_error(RuntimeError, "something else")
      end

      it "fails when the message matches the regexp" do
        # Arrange
        ctx = assertion_context

        # Act & Assert
        expect { ctx.refute_raises(match: /\d+/) { raise "error 42" } }.to raise_error(AE)
      end
    end

    context "with error classes and no match" do
      it "passes when no exception is raised" do
        # Arrange
        ctx = assertion_context

        # Act
        ctx.refute_raises(RuntimeError) { 1 + 1 }

        # Assert — implicit
      end

      it "fails when a listed class is raised" do
        # Arrange
        ctx = assertion_context

        # Act & Assert
        expect { ctx.refute_raises(RuntimeError) { raise RuntimeError, "boom" } }.to raise_error(AE)
      end

      it "propagates unlisted exceptions" do
        # Arrange
        ctx = assertion_context

        # Act & Assert
        expect { ctx.refute_raises(RuntimeError) { raise ArgumentError, "wrong" } }
          .to raise_error(ArgumentError)
      end
    end

    context "with error classes and match:" do
      it "passes when the class matches but the message does not" do
        # Arrange
        ctx = assertion_context

        # Act
        ctx.refute_raises(RuntimeError, match: "specific") { raise RuntimeError, "something else" }

        # Assert — implicit
      end

      it "fails when both the class and message match" do
        # Arrange
        ctx = assertion_context

        # Act & Assert
        expect { ctx.refute_raises(RuntimeError, match: "boom") { raise RuntimeError, "boom" } }
          .to raise_error(AE)
      end
    end
  end

  # ── assert_in_delta / refute_in_delta ──────────────────────────────────────

  describe "#assert_in_delta" do
    it "passes when within delta" do
      # Arrange
      ctx = assertion_context

      # Act
      ctx.assert_in_delta(expected: 1.0, actual: 1.05, delta: 0.1)

      # Assert — implicit
    end

    it "passes at the exact boundary (accounting for float representation)" do
      # Arrange
      ctx = assertion_context

      # Act
      ctx.assert_in_delta(expected: 1.0, actual: 1.1, delta: 0.1)

      # Assert — implicit
    end

    it "fails when outside delta" do
      # Arrange
      ctx = assertion_context

      # Act & Assert
      expect { ctx.assert_in_delta(expected: 1.0, actual: 1.2, delta: 0.1) }.to raise_error(AE)
    end
  end

  describe "#refute_in_delta" do
    it "passes when outside delta" do
      # Arrange
      ctx = assertion_context

      # Act
      ctx.refute_in_delta(expected: 1.0, actual: 1.2, delta: 0.1)

      # Assert — implicit
    end

    it "fails when within delta" do
      # Arrange
      ctx = assertion_context

      # Act & Assert
      expect { ctx.refute_in_delta(expected: 1.0, actual: 1.05, delta: 0.1) }.to raise_error(AE)
    end

    it "fails at the exact boundary (accounting for float representation)" do
      # Arrange
      ctx = assertion_context

      # Act & Assert
      expect { ctx.refute_in_delta(expected: 1.0, actual: 1.1, delta: 0.1) }.to raise_error(AE)
    end
  end

  # ── assert_match / refute_match ────────────────────────────────────────────

  describe "#assert_match" do
    it "passes with a matching regexp" do
      # Arrange
      ctx = assertion_context

      # Act
      ctx.assert_match(pattern: /hel+o/, actual: "hello")

      # Assert — implicit
    end

    it "passes with a matching string pattern" do
      # Arrange
      ctx = assertion_context

      # Act
      ctx.assert_match(pattern: "ell", actual: "hello")

      # Assert — implicit
    end

    it "fails with a non-matching regexp" do
      # Arrange
      ctx = assertion_context

      # Act & Assert
      expect { ctx.assert_match(pattern: /\d+/, actual: "no digits") }.to raise_error(AE)
    end

    it "fails with a non-matching string" do
      # Arrange
      ctx = assertion_context

      # Act & Assert
      expect { ctx.assert_match(pattern: "xyz", actual: "hello") }.to raise_error(AE)
    end
  end

  describe "#refute_match" do
    it "passes with a non-matching regexp" do
      # Arrange
      ctx = assertion_context

      # Act
      ctx.refute_match(pattern: /\d+/, actual: "no digits")

      # Assert — implicit
    end

    it "passes with a non-matching string" do
      # Arrange
      ctx = assertion_context

      # Act
      ctx.refute_match(pattern: "xyz", actual: "hello")

      # Assert — implicit
    end

    it "fails with a matching regexp" do
      # Arrange
      ctx = assertion_context

      # Act & Assert
      expect { ctx.refute_match(pattern: /hel+o/, actual: "hello") }.to raise_error(AE)
    end

    it "fails with a matching string" do
      # Arrange
      ctx = assertion_context

      # Act & Assert
      expect { ctx.refute_match(pattern: "ell", actual: "hello") }.to raise_error(AE)
    end
  end

  # ── assert_includes / refute_includes ──────────────────────────────────────

  describe "#assert_includes" do
    it "passes when item is in the array" do
      # Arrange
      ctx = assertion_context

      # Act
      ctx.assert_includes(item: 2, collection: [1, 2, 3])

      # Assert — implicit
    end

    it "fails when item is not in the array" do
      # Arrange
      ctx = assertion_context

      # Act & Assert
      expect { ctx.assert_includes(item: 5, collection: [1, 2, 3]) }.to raise_error(AE)
    end

    it "passes when item is a substring of the string collection" do
      # Arrange
      ctx = assertion_context

      # Act
      ctx.assert_includes(item: "ell", collection: "hello")

      # Assert — implicit
    end

    it "fails when item is not in the string collection" do
      # Arrange
      ctx = assertion_context

      # Act & Assert
      expect { ctx.assert_includes(item: "xyz", collection: "hello") }.to raise_error(AE)
    end
  end

  describe "#refute_includes" do
    it "passes when item is not in the collection" do
      # Arrange
      ctx = assertion_context

      # Act
      ctx.refute_includes(item: 5, collection: [1, 2, 3])

      # Assert — implicit
    end

    it "fails when item is in the collection" do
      # Arrange
      ctx = assertion_context

      # Act & Assert
      expect { ctx.refute_includes(item: 2, collection: [1, 2, 3]) }.to raise_error(AE)
    end
  end

  # ── message: Proc laziness ──────────────────────────────────────────────────

  describe "message: proc laziness" do
    it "is not called on passing assertions" do
      # Arrange
      ctx = assertion_context
      called = false

      # Act
      ctx.assert_equal(actual: 1, expected: 1, message: -> { called = true; "msg" })

      # Assert
      expect(called).to be false
    end

    it "is called on failing assertions" do
      # Arrange
      ctx = assertion_context
      called = false

      # Act & Assert
      expect {
        ctx.assert_equal(actual: 1, expected: 2, message: -> { called = true; "msg" })
      }.to raise_error(AE)

      # Assert
      expect(called).to be true
    end
  end
end
