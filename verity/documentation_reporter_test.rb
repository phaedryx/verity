# frozen_string_literal: true

# Triple suite: test/documentation_reporter_test.rb · spec/verity/documentation_reporter_spec.rb

require "stringio"

DOC_RESULT = lambda do |status:, description: "example", error: nil, group_path: []|
  test = Verity::Test.new(
    fingerprint: "docspec.rb:aaaaaaaaaaaaaaaa",
    description: description,
    tags: [],
    timeout: nil,
    requires: [],
    resources: {},
    file: __FILE__,
    line: __LINE__,
    fn: -> {},
    group_path: group_path,
    inherited_group_tags: [], group_scopes: []
  )
  Verity::Runner::Result.new(test: test, status: status, error: error)
end

DOC_SUMMARY = lambda do |total: 2, passed: 1, failed: 1, errored: 0, skipped: 0, focus: false|
  { total: total, passed: passed, failed: failed, errored: errored, skipped: skipped, focus: focus }
end

test "documentation reporter prints run header with count" do
  io = StringIO.new
  rep = Verity::Reporters::DocumentationReporter.new(io, color: false)
  rep.on_run_start(total: 5, worker_id: 0)
  assert_match pattern: /Running 5 tests/, actual: io.string
end

test "documentation reporter prints pass lines" do
  io = StringIO.new
  rep = Verity::Reporters::DocumentationReporter.new(io, color: false)
  rep.on_test_complete(result: DOC_RESULT.call(status: :pass, description: "works"), worker_id: 0)
  assert_match pattern: /pass/, actual: io.string
  assert_match pattern: /works/, actual: io.string
end

test "documentation reporter prints fail with message" do
  io = StringIO.new
  rep = Verity::Reporters::DocumentationReporter.new(io, color: false)
  err = Verity::AssertionError.new("nope")
  rep.on_test_complete(
    result: DOC_RESULT.call(status: :fail, description: "breaks", error: err),
    worker_id: 0
  )
  assert_match pattern: /FAIL/, actual: io.string
  assert_match pattern: /breaks/, actual: io.string
  assert_match pattern: /nope/, actual: io.string
end

test "documentation reporter prints skip lines" do
  io = StringIO.new
  rep = Verity::Reporters::DocumentationReporter.new(io, color: false)
  rep.on_test_complete(
    result: DOC_RESULT.call(status: :skip, description: "skipped one"),
    worker_id: 0
  )
  assert_match pattern: /skip/, actual: io.string
  assert_match pattern: /skipped one/, actual: io.string
end

test "documentation reporter prints error lines" do
  io = StringIO.new
  rep = Verity::Reporters::DocumentationReporter.new(io, color: false)
  err = RuntimeError.new("boom")
  rep.on_test_complete(
    result: DOC_RESULT.call(status: :error, description: "explodes", error: err),
    worker_id: 0
  )
  assert_match pattern: /ERROR/, actual: io.string
  assert_match pattern: /RuntimeError/, actual: io.string
end

test "documentation reporter emits group headers for nested path" do
  io = StringIO.new
  rep = Verity::Reporters::DocumentationReporter.new(io, color: false)
  rep.on_test_complete(
    result: DOC_RESULT.call(status: :pass, description: "inner", group_path: %w[Outer Inner]),
    worker_id: 0
  )
  assert_match pattern: /Outer/, actual: io.string
  assert_match pattern: /Inner/, actual: io.string
end

test "documentation reporter prints summary on run finish" do
  io = StringIO.new
  rep = Verity::Reporters::DocumentationReporter.new(io, color: false)
  rep.on_run_finish(summary: DOC_SUMMARY.call(total: 3, passed: 2, failed: 1, errored: 0), worker_id: 0)
  assert_match pattern: /3 tests/, actual: io.string
  assert_match pattern: /2 passed/, actual: io.string
end
