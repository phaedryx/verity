# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/verity"
require_relative "verity_test_helper"

# Triple suite (compare / redundant proof): ../verity/dsl_test.rb · ../spec/verity/dsl_spec.rb
class DSLTest < Minitest::Test
  include VerityTestHelper

  def find(desc)
    Verity::Registry.all.reverse.find { _1.description == desc }
  end

  def fresh_dsl
    reset_verity_process_state!
    Verity.clear_group_stack!
    Object.new.extend(Verity::DSL)
  end

  def test_dsl_registration_and_basic_metadata_mirrors_dogfood
    dsl = fresh_dsl
    dsl.test("dsl_reg_example_x") { true }
    refute_nil find("dsl_reg_example_x")
  end

  def test_tags_file_line_timeout_and_negative_cases
    dsl = fresh_dsl
    dsl.test("dsl_tag_slow_int", tags: [:slow, :integration]) { true }
    assert_equal [:slow, :integration], find("dsl_tag_slow_int").tags

    dsl.test("dsl_loc_capture") { true }
    t = find("dsl_loc_capture")
    assert_match(/dsl_test\.rb\z/, t.file)
    assert_kind_of Integer, t.line

    block = -> { 42 }
    dsl.test("dsl_fn_holder", &block)
    assert_equal 42, find("dsl_fn_holder").fn.call

    dsl.test("dsl_to_nil", timeout: nil) { true }
    assert_nil find("dsl_to_nil").timeout

    dsl.test("dsl_to_frac", timeout: 3.5) { true }
    assert_in_delta 3.5, find("dsl_to_frac").timeout

    assert_raises(ArgumentError) { dsl.test("bad", timeout: "5") { true } }
    assert_raises(ArgumentError) { dsl.test("bz", timeout: 0) { true } }
    assert_raises(ArgumentError) { dsl.test("bn", timeout: -1) { true } }
    assert_raises(ArgumentError) { dsl.test("bi", timeout: Float::INFINITY) { true } }
  end

  def test_group_metadata_paths_and_block_requirement
    dsl = fresh_dsl
    dsl.group("DSLAuth") { dsl.test("dsl_login_under_auth") { true } }
    assert_equal ["DSLAuth"], find("dsl_login_under_auth").group_path

    dsl.group("DSLOuter") do
      dsl.group("DSLInnerNest") { dsl.test("dsl_deep_leaf") { true } }
    end
    assert_equal %w[DSLOuter DSLInnerNest], find("dsl_deep_leaf").group_path

    dsl.group("DSL_DB", tags: [:slow]) do
      dsl.group("DSL Mig", tags: [:migration]) { dsl.test("dsl_runs_migration") { true } }
    end
    assert_equal [:slow, :migration], find("dsl_runs_migration").inherited_group_tags

    dsl.group("DSLGOuter") do
      dsl.group("DSLGInner") { dsl.test("dsl_scopes_deep") { true } }
    end
    g = find("dsl_scopes_deep").group_scopes
    assert_equal %w[DSLGOuter DSLGInner], g.map(&:title)
    assert_operator g.map(&:line).max, :>=, 1

    dsl.group("DSLTemporary") { dsl.test("dsl_inside_grp") { true } }
    dsl.test("dsl_outside_grp_line") { true }
    assert_empty find("dsl_outside_grp_line").group_path

    err = assert_raises(ArgumentError) { dsl.group("DSLNoBlk") }
    assert_match(/requires a block/, err.message)
  end
end
