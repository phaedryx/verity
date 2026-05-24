# frozen_string_literal: true

# Triple suite counterpart: test/dsl_test.rb · spec/verity/dsl_spec.rb
#
# Unique descriptions — this file loads with other DSL dogfood examples; Registry
# is never cleared mid-file.

NEW_DSL = lambda do
  Verity.clear_group_stack!
  Object.new.extend(Verity::DSL)
end

FIND = lambda { |desc| Verity::Registry.all.reverse.find { _1.description == desc } }

test "DSL registers example and keeps metadata" do
  ctx = NEW_DSL.call
  ctx.test("dsl_reg_example_x") { true }
  t = FIND.call("dsl_reg_example_x")
  assert_equal actual: t&.description, expected: "dsl_reg_example_x"
end

test "DSL stores declared tags array" do
  ctx = NEW_DSL.call
  ctx.test("dsl_tag_slow_int", tags: [:slow, :integration]) { true }
  assert_equal actual: FIND.call("dsl_tag_slow_int").tags, expected: [:slow, :integration]
end

test "DSL captures source file path and lineno" do
  ctx = NEW_DSL.call
  ctx.test("dsl_loc_capture") { true }
  t = FIND.call("dsl_loc_capture")
  assert_equal actual: t.file, expected: __FILE__
  assert t.line.is_a?(Integer)
end

test "DSL keeps callable proc body accessible" do
  ctx = NEW_DSL.call
  block = -> { 42 }
  ctx.test("dsl_fn_holder", &block)
  assert_equal actual: FIND.call("dsl_fn_holder").fn.call, expected: 42
end

test "DSL permits nil timeout" do
  ctx = NEW_DSL.call
  ctx.test("dsl_to_nil", timeout: nil) { true }
  assert_nil FIND.call("dsl_to_nil").timeout
end

test "DSL honors positive Numeric timeout" do
  ctx = NEW_DSL.call
  ctx.test("dsl_to_frac", timeout: 3.5) { true }
  assert_equal actual: FIND.call("dsl_to_frac").timeout, expected: 3.5
end

test "DSL rejects string timeout arguments" do
  ctx = NEW_DSL.call
  err = assert_raises(ArgumentError) { ctx.test("dsl_bad_to_str", timeout: "5") { true } }
  assert_match pattern: /test timeout must be nil or a positive finite Numeric/, actual: err.message
end

test "DSL rejects zero and negative timeouts" do
  ctx = NEW_DSL.call
  assert_raises(ArgumentError) { ctx.test("dsl_bad_to_zero", timeout: 0) { true } }
  assert_raises(ArgumentError) { ctx.test("dsl_bad_to_neg", timeout: -1) { true } }
end

test "DSL rejects non-finite timeouts" do
  ctx = NEW_DSL.call
  assert_raises(ArgumentError) { ctx.test("dsl_bad_to_inf", timeout: Float::INFINITY) { true } }
end

test "DSL group attaches group_path to nested example" do
  ctx = NEW_DSL.call
  ctx.group("DSLAuth") do
    ctx.test("dsl_login_under_auth") { true }
  end
  t = FIND.call("dsl_login_under_auth")
  assert_equal actual: t.group_path, expected: ["DSLAuth"]
end

test "DSL nests group_path across levels" do
  ctx = NEW_DSL.call
  ctx.group("DSLOuter") do
    ctx.group("DSLInnerNest") do
      ctx.test("dsl_deep_leaf") { true }
    end
  end
  assert_equal actual: FIND.call("dsl_deep_leaf").group_path, expected: %w[DSLOuter DSLInnerNest]
end

test "DSL flattens inherited group tags" do
  ctx = NEW_DSL.call
  ctx.group("DSL_DB", tags: [:slow]) do
    ctx.group("DSL Mig", tags: [:migration]) do
      ctx.test("dsl_runs_migration") { true }
    end
  end
  assert_equal actual: FIND.call("dsl_runs_migration").inherited_group_tags, expected: [:slow, :migration]
end

test "DSL emits GroupScope list matching nesting" do
  ctx = NEW_DSL.call
  ctx.group("DSLGOuter") do
    ctx.group("DSLGInner") do
      ctx.test("dsl_scopes_deep") { true }
    end
  end
  t = FIND.call("dsl_scopes_deep")
  assert_equal actual: t.group_scopes.size, expected: 2
  assert_equal actual: t.group_scopes.map(&:title), expected: %w[DSLGOuter DSLGInner]
  assert t.group_scopes.map(&:line).max >= 1
  assert_equal actual: t.group_scopes.map(&:file).uniq.size, expected: 1
  assert_equal actual: t.group_scopes.map(&:file).first, expected: __FILE__
end

test "DSL restores empty group stack after group block" do
  ctx = NEW_DSL.call
  ctx.group("DSLTemporary") do
    ctx.test("dsl_inside_grp") { true }
  end
  ctx.test("dsl_outside_grp_line") { true }
  outside = FIND.call("dsl_outside_grp_line")
  assert_equal actual: outside.group_path, expected: []
end

test "DSL group rejects missing block argument" do
  ctx = NEW_DSL.call
  assert_raises(ArgumentError, match: /requires a block/) { ctx.group("DSLNoBlk") }
end
