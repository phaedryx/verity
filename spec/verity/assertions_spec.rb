# frozen_string_literal: true

require "spec_helper"

RSpec.describe Verity::Assertions do
  AE = Verity::AssertionError

  def ctx
    Class.new { include Verity::Assertions }.new
  end

  describe "#assert" do
    it("passes with true")    { ctx.assert(true) }
    it("passes with a string") { ctx.assert("value") }
    it("passes with 1")       { ctx.assert(1) }

    it "fails with false" do
      expect { ctx.assert(false) }.to raise_error(AE, /Expected truthy/)
    end

    it "fails with nil" do
      expect { ctx.assert(nil) }.to raise_error(AE)
    end
  end

  describe "#refute" do
    it("passes with false") { ctx.refute(false) }
    it("passes with nil")   { ctx.refute(nil) }

    it "fails with a truthy value" do
      expect { ctx.refute("truthy") }.to raise_error(AE)
    end
  end

  describe "#assert_nil" do
    it("passes with nil") { ctx.assert_nil(nil) }

    it "fails with a non-nil value" do
      expect { ctx.assert_nil(:x) }.to raise_error(AE, /Expected nil/)
    end
  end

  describe "#refute_nil" do
    it("passes with false") { ctx.refute_nil(false) }
    it("passes with zero")  { ctx.refute_nil(0) }

    it "fails with nil" do
      expect { ctx.refute_nil(nil) }.to raise_error(AE, /non-nil/)
    end
  end

  describe "#assert_equal" do
    it "passes when values are equal" do
      ctx.assert_equal(actual: 1, expected: 1)
    end

    it "fails when values differ" do
      expect { ctx.assert_equal(actual: 1, expected: 2) }.to raise_error(AE)
    end
  end

  describe "#refute_equal" do
    it("passes when values differ") { ctx.refute_equal(actual: 1, expected: 2) }

    it "fails when values are equal" do
      expect { ctx.refute_equal(actual: 1, expected: 1) }.to raise_error(AE)
    end
  end

  describe "#assert_same" do
    it "passes with the identical object" do
      obj = Object.new
      ctx.assert_same(actual: obj, expected: obj)
    end

    it "fails with equal but distinct objects" do
      expect { ctx.assert_same(actual: "abc", expected: String.new("abc")) }.to raise_error(AE)
    end
  end

  describe "#refute_same" do
    it("passes with distinct objects") { ctx.refute_same(actual: "a", expected: String.new("a")) }

    it "fails with the identical object" do
      obj = :sym
      expect { ctx.refute_same(actual: obj, expected: obj) }.to raise_error(AE)
    end
  end

  describe "#assert_raises" do
    it "passes when the expected error is raised" do
      ctx.assert_raises(RuntimeError) { raise RuntimeError, "boom" }
    end

    it "returns the caught exception" do
      e = ctx.assert_raises(RuntimeError) { raise RuntimeError, "boom" }
      expect(e.message).to eq("boom")
    end

    it "passes for a subclass" do
      ctx.assert_raises(StandardError) { raise RuntimeError, "boom" }
    end

    it "fails when nothing is raised" do
      expect { ctx.assert_raises(RuntimeError) {} }.to raise_error(AE, /nothing was raised/)
    end

    it "fails when a different error class is raised" do
      expect { ctx.assert_raises(ArgumentError) { raise RuntimeError } }.to raise_error(AE)
    end

    it "requires at least one error class" do
      expect { ctx.assert_raises { raise "x" } }.to raise_error(ArgumentError)
    end

    it "passes when match: string matches" do
      ctx.assert_raises(RuntimeError, match: "boom") { raise RuntimeError, "big boom" }
    end

    it "fails when match: string does not match" do
      expect {
        ctx.assert_raises(RuntimeError, match: "boom") { raise RuntimeError, "silence" }
      }.to raise_error(AE, /did not match/)
    end

    it "passes when match: regexp matches" do
      ctx.assert_raises(RuntimeError, match: /\d+/) { raise RuntimeError, "error 42" }
    end

    it "fails when match: regexp does not match" do
      expect {
        ctx.assert_raises(RuntimeError, match: /\d+/) { raise RuntimeError, "no digits" }
      }.to raise_error(AE)
    end
  end

  describe "#refute_raises" do
    it("passes when nothing is raised") { ctx.refute_raises { 1 + 1 } }

    it "fails when any exception is raised (no classes)" do
      expect { ctx.refute_raises { raise "oops" } }.to raise_error(AE)
    end

    it "fails when a listed class is raised" do
      expect { ctx.refute_raises(RuntimeError) { raise RuntimeError, "boom" } }.to raise_error(AE)
    end

    it "propagates unlisted exceptions" do
      expect {
        ctx.refute_raises(RuntimeError) { raise ArgumentError, "wrong" }
      }.to raise_error(ArgumentError)
    end

    it "passes with match when message doesn't match" do
      ctx.refute_raises(RuntimeError, match: "specific") { raise RuntimeError, "something else" }
    end

    it "fails when both class and message match" do
      expect {
        ctx.refute_raises(RuntimeError, match: "boom") { raise RuntimeError, "boom" }
      }.to raise_error(AE)
    end
  end

  describe "#assert_in_delta" do
    it("passes within delta") { ctx.assert_in_delta(expected: 1.0, actual: 1.05, delta: 0.1) }
    it("passes at boundary")  { ctx.assert_in_delta(expected: 1.0, actual: 1.1, delta: 0.1) }

    it "fails outside delta" do
      expect { ctx.assert_in_delta(expected: 1.0, actual: 1.2, delta: 0.1) }.to raise_error(AE)
    end
  end

  describe "#refute_in_delta" do
    it("passes outside delta") { ctx.refute_in_delta(expected: 1.0, actual: 1.2, delta: 0.1) }

    it "fails within delta" do
      expect { ctx.refute_in_delta(expected: 1.0, actual: 1.05, delta: 0.1) }.to raise_error(AE)
    end

    it "fails at boundary" do
      expect { ctx.refute_in_delta(expected: 1.0, actual: 1.1, delta: 0.1) }.to raise_error(AE)
    end
  end

  describe "#assert_match" do
    it("passes with matching regexp")  { ctx.assert_match(pattern: /hel+o/, actual: "hello") }
    it("passes with matching string")  { ctx.assert_match(pattern: "ell", actual: "hello") }

    it "fails with non-matching regexp" do
      expect { ctx.assert_match(pattern: /\d+/, actual: "no digits") }.to raise_error(AE)
    end

    it "fails with non-matching string" do
      expect { ctx.assert_match(pattern: "xyz", actual: "hello") }.to raise_error(AE)
    end
  end

  describe "#refute_match" do
    it("passes with non-matching regexp") { ctx.refute_match(pattern: /\d+/, actual: "no digits") }
    it("passes with non-matching string") { ctx.refute_match(pattern: "xyz", actual: "hello") }

    it "fails with matching regexp" do
      expect { ctx.refute_match(pattern: /hel+o/, actual: "hello") }.to raise_error(AE)
    end

    it "fails with matching string" do
      expect { ctx.refute_match(pattern: "ell", actual: "hello") }.to raise_error(AE)
    end
  end

  describe "#assert_includes" do
    it("passes when item is in array")  { ctx.assert_includes(item: 2, collection: [1, 2, 3]) }
    it("passes with substring")         { ctx.assert_includes(item: "ell", collection: "hello") }

    it "fails when item not in array" do
      expect { ctx.assert_includes(item: 5, collection: [1, 2, 3]) }.to raise_error(AE)
    end
  end

  describe "#refute_includes" do
    it("passes when item not in collection") { ctx.refute_includes(item: 5, collection: [1, 2, 3]) }

    it "fails when item is in collection" do
      expect { ctx.refute_includes(item: 2, collection: [1, 2, 3]) }.to raise_error(AE)
    end
  end

  describe "custom message" do
    it "uses a string message on failure" do
      expect { ctx.assert(false, message: "custom msg") }.to raise_error(AE, /custom msg/)
    end

    it "calls a Proc message on failure" do
      called = false
      expect {
        ctx.assert(false, message: -> { called = true; "lazy" })
      }.to raise_error(AE, /lazy/)
      expect(called).to be true
    end

    it "does not call a Proc message on pass" do
      called = false
      ctx.assert(true, message: -> { called = true; "msg" })
      expect(called).to be false
    end
  end
end
