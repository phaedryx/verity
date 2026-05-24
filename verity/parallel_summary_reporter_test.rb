# frozen_string_literal: true

require "stringio"

# Dogfood mirror of test/parallel_summary_reporter_test.rb

test "parallel summary emit prints totals with no problems" do
  io = StringIO.new
  Verity::Reporters::ParallelSummaryReporter.new(io).emit(
    counts: { "passed" => 10, "failed" => 0, "errored" => 0, "pending" => 0, "running" => 0 },
    problem_rows: []
  )
  assert_match pattern: /10 tests in manifest: 10 passed, 0 failed, 0 errored/, actual: io.string
  refute_match pattern: /Failures and errors/, actual: io.string
end

test "parallel summary emit prints failures section" do
  io = StringIO.new
  rows = [
    { fingerprint: "fp1", description: "bad test", status: :failed, failure: { "message" => "expected true" } },
    { fingerprint: "fp2", description: "crash", status: :errored, failure: { "message" => "NoMethodError" } }
  ]
  Verity::Reporters::ParallelSummaryReporter.new(io).emit(
    counts: { "passed" => 8, "failed" => 1, "errored" => 1, "pending" => 0, "running" => 0 },
    problem_rows: rows
  )
  out = io.string
  assert_match pattern: /10 tests in manifest/, actual: out
  assert_match pattern: /Failures and errors/, actual: out
  assert_match pattern: /failed  bad test \(fp1\)/, actual: out
  assert_match pattern: /expected true/, actual: out
  assert_match pattern: /errored  crash \(fp2\)/, actual: out
  assert_match pattern: /NoMethodError/, actual: out
end

test "parallel summary emit handles nil failure" do
  io = StringIO.new
  rows = [{ fingerprint: "fp3", description: "no detail", status: :failed, failure: nil }]
  Verity::Reporters::ParallelSummaryReporter.new(io).emit(
    counts: { "passed" => 0, "failed" => 1 },
    problem_rows: rows
  )
  assert_match pattern: /failed  no detail \(fp3\)/, actual: io.string
end

test "parallel summary emit defaults missing count keys" do
  io = StringIO.new
  Verity::Reporters::ParallelSummaryReporter.new(io).emit(
    counts: { "passed" => 3 },
    problem_rows: []
  )
  assert_match pattern: /3 tests in manifest: 3 passed, 0 failed, 0 errored, 0 pending, 0 running/, actual: io.string
end

test "parallel summary emit shows skipped count when nonzero" do
  io = StringIO.new
  Verity::Reporters::ParallelSummaryReporter.new(io).emit(
    counts: { "passed" => 5, "failed" => 0, "errored" => 0, "pending" => 0, "running" => 0, "skipped" => 3 },
    problem_rows: []
  )
  assert_match pattern: /5 tests in manifest.*3 skipped/, actual: io.string
end

test "parallel summary emit omits skipped phrase when zero" do
  io = StringIO.new
  Verity::Reporters::ParallelSummaryReporter.new(io).emit(
    counts: { "passed" => 2, "skipped" => 0 },
    problem_rows: []
  )
  refute_match pattern: /skipped/, actual: io.string
end
