# frozen_string_literal: true

require "spec_helper"

RSpec.describe Verity::DSL do
  let(:dsl) { Class.new { include Verity::DSL }.new }

  describe "#test" do
    it "registers a Test in Registry" do
      dsl.test("example") { true }
      all = Verity::Registry.all
      expect(all.size).to eq(1)
      expect(all.first.description).to eq("example")
    end

    it "stores tags on the test" do
      dsl.test("tagged", tags: [:slow, :integration]) { true }
      expect(Verity::Registry.all.first.tags).to eq([:slow, :integration])
    end

    it "captures file and line" do
      dsl.test("located") { true }
      t = Verity::Registry.all.first
      expect(t.file).to eq(__FILE__)
      expect(t.line).to be_a(Integer)
    end

    it "stores the block as fn" do
      block = -> { 42 }
      dsl.test("with_fn", &block)
      expect(Verity::Registry.all.first.fn.call).to eq(42)
    end
  end

  describe "#group" do
    it "sets group_path on enclosed tests" do
      dsl.group("Auth") do
        dsl.test("login") { true }
      end

      t = Verity::Registry.all.first
      expect(t.group_path).to eq(["Auth"])
    end

    it "accumulates nested group paths" do
      dsl.group("Outer") do
        dsl.group("Inner") do
          dsl.test("deep") { true }
        end
      end

      t = Verity::Registry.all.first
      expect(t.group_path).to eq(["Outer", "Inner"])
    end

    it "inherits tags from enclosing groups" do
      dsl.group("DB", tags: [:slow]) do
        dsl.group("Migrations", tags: [:migration]) do
          dsl.test("runs") { true }
        end
      end

      t = Verity::Registry.all.first
      expect(t.inherited_group_tags).to eq([:slow, :migration])
    end

    it "cleans up the group stack after the block" do
      dsl.group("Temp") do
        dsl.test("inside") { true }
      end
      dsl.test("outside") { true }

      outside = Verity::Registry.all.find { |t| t.description == "outside" }
      expect(outside.group_path).to eq([])
    end

    it "requires a block" do
      expect { dsl.group("No Block") }.to raise_error(ArgumentError, /requires a block/)
    end
  end
end
