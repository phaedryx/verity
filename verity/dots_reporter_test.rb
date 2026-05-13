# frozen_string_literal: true

require "stringio"

# Dogfood mirror of test/dots_reporter_test.rb

test "dots reporter prints dot for pass" do
  io = StringIO.new
  rep = Verity::Reporters::DotsReporter.new(io)
  t = Verity::Test.new(
    fingerprint: "dots.rb:#{"d" * 16}",
    description: "x",
    tags: [],
    timeout: nil,
    requires: [],
    resources: {},
    file: "dots.rb",
    line: 1,
    fn: -> {},
    group_path: [],
    inherited_group_tags: []
  )
  rep.on_test_complete(result: Verity::Runner::Result.new(test: t, status: :pass, error: nil), worker_id: 0)
  assert_equal actual: io.string, expected: "."
end

test "dots reporter prints F for fail" do
  io = StringIO.new
  rep = Verity::Reporters::DotsReporter.new(io)
  t = Verity::Test.new(
    fingerprint: "dots.rb:#{"d" * 16}",
    description: "x",
    tags: [],
    timeout: nil,
    requires: [],
    resources: {},
    file: "dots.rb",
    line: 1,
    fn: -> {},
    group_path: [],
    inherited_group_tags: []
  )
  rep.on_test_complete(
    result: Verity::Runner::Result.new(test: t, status: :fail, error: StandardError.new("x")),
    worker_id: 0
  )
  assert_equal actual: io.string, expected: "F"
end

test "dots reporter prints E for error" do
  io = StringIO.new
  rep = Verity::Reporters::DotsReporter.new(io)
  t = Verity::Test.new(
    fingerprint: "dots.rb:#{"d" * 16}",
    description: "x",
    tags: [],
    timeout: nil,
    requires: [],
    resources: {},
    file: "dots.rb",
    line: 1,
    fn: -> {},
    group_path: [],
    inherited_group_tags: []
  )
  rep.on_test_complete(
    result: Verity::Runner::Result.new(test: t, status: :error, error: RuntimeError.new("x")),
    worker_id: 0
  )
  assert_equal actual: io.string, expected: "E"
end

test "dots reporter skip does not crash" do
  io = StringIO.new
  rep = Verity::Reporters::DotsReporter.new(io)
  t = Verity::Test.new(
    fingerprint: "dots.rb:#{"d" * 16}",
    description: "x",
    tags: [],
    timeout: nil,
    requires: [],
    resources: {},
    file: "dots.rb",
    line: 1,
    fn: -> {},
    group_path: [],
    inherited_group_tags: []
  )
  rep.on_test_complete(
    result: Verity::Runner::Result.new(test: t, status: :skip, error: nil),
    worker_id: 0
  )
  assert_equal actual: io.string, expected: ""
end

test "dots reporter on_run_finish prints summary" do
  io = StringIO.new
  rep = Verity::Reporters::DotsReporter.new(io)
  summary = { total: 5, passed: 3, failed: 1, errored: 1, skipped: 0, focus: false }
  rep.on_run_finish(summary: summary, worker_id: 0)
  assert_match pattern: /5 tests: 3 passed, 1 failed, 1 errored/, actual: io.string
end

test "dots reporter on_run_finish includes skipped" do
  io = StringIO.new
  rep = Verity::Reporters::DotsReporter.new(io)
  summary = { total: 4, passed: 2, failed: 0, errored: 0, skipped: 2, focus: false }
  rep.on_run_finish(summary: summary, worker_id: 0)
  assert_match pattern: /2 skipped/, actual: io.string
end

test "dots reporter on_run_finish includes focus" do
  io = StringIO.new
  rep = Verity::Reporters::DotsReporter.new(io)
  summary = { total: 1, passed: 1, failed: 0, errored: 0, skipped: 0, focus: true }
  rep.on_run_finish(summary: summary, worker_id: 0)
  assert_match pattern: /\(focus\)/, actual: io.string
end
