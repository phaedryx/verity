# frozen_string_literal: true

require "spec_helper"

# Triple suite twin of verity/dsl_test.rb — description strings intentionally parallel for diffing tools.
RSpec.describe Verity::DSL do
  def ctx
    Verity.clear_group_stack!
    Object.new.extend(described_class)
  end

  def find(description)
    Verity::Registry.all.reverse.find { _1.description == description }
  end

  describe "registration" do
    it "DSL registers example and keeps metadata" do
      dsl = ctx
      dsl.test("dsl_reg_example_x") { true }
      expect(find("dsl_reg_example_x")&.description).to eq("dsl_reg_example_x")
    end

    it "DSL stores declared tags array" do
      dsl = ctx
      dsl.test("dsl_tag_slow_int", tags: [:slow, :integration]) { true }
      expect(find("dsl_tag_slow_int").tags).to eq([:slow, :integration])
    end

    it "DSL captures source file path and lineno" do
      dsl = ctx
      dsl.test("dsl_loc_capture") { true }
      t = find("dsl_loc_capture")
      expect(t.file).to eq(__FILE__)
      expect(t.line).to be_a(Integer)
    end

    it "DSL keeps callable proc body accessible" do
      dsl = ctx
      block = -> { 42 }
      dsl.test("dsl_fn_holder", &block)
      expect(find("dsl_fn_holder").fn.call).to eq(42)
    end
  end

  describe "timeout validation" do
    it "DSL permits nil timeout" do
      dsl = ctx
      dsl.test("dsl_to_nil", timeout: nil) { true }
      expect(find("dsl_to_nil").timeout).to be_nil
    end

    it "DSL honors positive Numeric timeout" do
      dsl = ctx
      dsl.test("dsl_to_frac", timeout: 3.5) { true }
      expect(find("dsl_to_frac").timeout).to eq(3.5)
    end

    it "DSL rejects string timeout arguments" do
      dsl = ctx
      expect {
        dsl.test("dsl_bad_to_str", timeout: "5") { true }
      }.to raise_error(ArgumentError, /test timeout must be nil or a positive finite Numeric/)
    end

    it "DSL rejects zero and negative timeouts" do
      dsl = ctx
      expect { dsl.test("dsl_bad_to_zero", timeout: 0) { true } }.to raise_error(ArgumentError)
      expect { dsl.test("dsl_bad_to_neg", timeout: -1) { true } }.to raise_error(ArgumentError)
    end

    it "DSL rejects non-finite timeouts" do
      dsl = ctx
      expect { dsl.test("dsl_bad_to_inf", timeout: Float::INFINITY) { true } }.to raise_error(ArgumentError)
    end
  end

  describe "#group metadata" do
    it "DSL group attaches group_path to nested example" do
      dsl = ctx
      dsl.group("DSLAuth") { dsl.test("dsl_login_under_auth") { true } }
      expect(find("dsl_login_under_auth").group_path).to eq(["DSLAuth"])
    end

    it "DSL nests group_path across levels" do
      dsl = ctx
      dsl.group("DSLOuter") do
        dsl.group("DSLInnerNest") do
          dsl.test("dsl_deep_leaf") { true }
        end
      end
      expect(find("dsl_deep_leaf").group_path).to eq(%w[DSLOuter DSLInnerNest])
    end

    it "DSL flattens inherited group tags" do
      dsl = ctx
      dsl.group("DSL_DB", tags: [:slow]) do
        dsl.group("DSL Mig", tags: [:migration]) do
          dsl.test("dsl_runs_migration") { true }
        end
      end
      expect(find("dsl_runs_migration").inherited_group_tags).to eq([:slow, :migration])
    end

    it "DSL emits GroupScope list matching nesting" do
      dsl = ctx
      dsl.group("DSLGOuter") do
        dsl.group("DSLGInner") do
          dsl.test("dsl_scopes_deep") { true }
        end
      end
      t = find("dsl_scopes_deep")
      expect(t.group_scopes.map(&:title)).to eq(%w[DSLGOuter DSLGInner])
      expect(t.group_scopes.map(&:line).max).to be >= 1
      expect(t.group_scopes.map(&:file).uniq.size).to eq(1)
      expect(t.group_scopes.first.file).to eq(__FILE__)
    end

    it "DSL restores empty group stack after group block" do
      dsl = ctx
      dsl.group("DSLTemporary") do
        dsl.test("dsl_inside_grp") { true }
      end
      dsl.test("dsl_outside_grp_line") { true }
      expect(find("dsl_outside_grp_line").group_path).to eq([])
    end

    it "DSL group rejects missing block argument" do
      dsl = ctx
      expect { dsl.group("DSLNoBlk") }.to raise_error(ArgumentError, /requires a block/)
    end
  end
end
