# frozen_string_literal: true

require "stringio"
require "fileutils"

# Dogfood mirror of test/group_test.rb — avoid group-level :focus (would narrow entire suite).

test "group requires a block" do
  assert_raises(ArgumentError) { Object.new.extend(Verity::DSL).group("nope") }
end

test "group nests path and inherits tags" do
  Verity.clear_group_stack!
  Object.new.extend(Verity::DSL).instance_eval do
    group "Outer", tags: [:integration] do
      group "Inner" do
        test "dogfood_nested_leaf" do
          assert true
        end
      end
    end
  end
  t = Verity::Registry.all.reverse.find { _1.description == "dogfood_nested_leaf" }
  assert t
  assert_equal actual: t.group_path, expected: %w[Outer Inner]
  assert_equal actual: t.group_scopes.map(&:title), expected: %w[Outer Inner]
  assert_equal actual: t.inherited_group_tags, expected: %i[integration]
  assert_equal actual: Verity.effective_tags(t), expected: %i[integration]
end

test "group skip tags apply to nested test" do
  Verity.clear_group_stack!
  ran = []
  Object.new.extend(Verity::DSL).instance_eval do
    group "WIP", tags: [:skip] do
      test "dogfood_skip_inner" do
        ran << :inside
      end
    end
  end
  t = Verity::Registry.all.reverse.find { _1.description == "dogfood_skip_inner" }
  assert t
  assert Verity.skipped?(t)
  Verity::Runner.new(reporter: Verity::Reporters::NullReporter.new).run([t])
  refute_includes item: :inside, collection: ran
end

test "group tags accumulate for effective_tags" do
  Verity.clear_group_stack!
  Object.new.extend(Verity::DSL).instance_eval do
    group "A", tags: [:skip] do
      group "B", tags: [:slow] do
        test "dogfood_tags_accum", tags: [:integration] do
        end
      end
    end
  end
  t = Verity::Registry.all.reverse.find { _1.description == "dogfood_tags_accum" }
  assert t
  assert_equal actual: Verity.effective_tags(t), expected: %i[skip slow integration]
  assert Verity.skipped?(t)
end

test "inner group without block does not corrupt outer group stack" do
  Verity.clear_group_stack!
  dsl = Object.new.extend(Verity::DSL)
  dsl.group("DFOuter") do
    assert_raises(ArgumentError) { dsl.group("DFBad") }
    dsl.test("dogfood_after_bad_inner") { true }
  end
  t = Verity::Registry.all.reverse.find { _1.description == "dogfood_after_bad_inner" }
  assert t
  assert_equal actual: t.group_path, expected: ["DFOuter"]
  assert_equal actual: t.group_scopes.map(&:title), expected: ["DFOuter"]
end

test "documentation reporter shows nested group headers" do
  io = StringIO.new
  rep = Verity::Reporters::DocumentationReporter.new(io, color: false)
  a = Verity::Test.new(
    fingerprint: "a.rb:#{"a" * 16}",
    description: "one",
    tags: [],
    timeout: nil,
    requires: [],
    resources: {},
    file: "a.rb",
    line: 1,
    fn: -> {},
    group_path: %w[Alpha],
    inherited_group_tags: [], group_scopes: []
  )
  b = Verity::Test.new(
    fingerprint: "b.rb:#{"b" * 16}",
    description: "two",
    tags: [],
    timeout: nil,
    requires: [],
    resources: {},
    file: "b.rb",
    line: 1,
    fn: -> {},
    group_path: %w[Alpha Beta],
    inherited_group_tags: [], group_scopes: []
  )
  rep.on_run_start(total: 2, worker_id: 0)
  rep.on_test_complete(result: Verity::Runner::Result.new(test: a, status: :pass, error: nil), worker_id: 0)
  rep.on_test_complete(result: Verity::Runner::Result.new(test: b, status: :pass, error: nil), worker_id: 0)
  out = io.string
  assert_match pattern: /Alpha\n/, actual: out
  assert_match pattern: /  Beta\n/, actual: out
  assert_match pattern: /      pass  two\n/, actual: out
end
