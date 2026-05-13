# frozen_string_literal: true

require "minitest/autorun"
require "stringio"
require_relative "../lib/verity"

class ParallelSummaryReporterTest < Minitest::Test
  def test_emit_prints_totals_with_no_problems
    io = StringIO.new
    Verity::Reporters::ParallelSummaryReporter.new(io).emit(
      counts: { "passed" => 10, "failed" => 0, "errored" => 0, "pending" => 0, "running" => 0 },
      problem_rows: []
    )
    assert_match(/10 tests in manifest: 10 passed, 0 failed, 0 errored/, io.string)
    refute_match(/Failures and errors/, io.string)
  end

  def test_emit_prints_failures_section
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
    assert_match(/10 tests in manifest/, out)
    assert_match(/Failures and errors/, out)
    assert_match(/failed  bad test \(fp1\)/, out)
    assert_match(/expected true/, out)
    assert_match(/errored  crash \(fp2\)/, out)
    assert_match(/NoMethodError/, out)
  end

  def test_emit_handles_nil_failure_gracefully
    io = StringIO.new
    rows = [{ fingerprint: "fp3", description: "no detail", status: :failed, failure: nil }]
    Verity::Reporters::ParallelSummaryReporter.new(io).emit(
      counts: { "passed" => 0, "failed" => 1 },
      problem_rows: rows
    )
    out = io.string
    assert_match(/failed  no detail \(fp3\)/, out)
  end

  def test_emit_defaults_missing_count_keys_to_zero
    io = StringIO.new
    Verity::Reporters::ParallelSummaryReporter.new(io).emit(
      counts: { "passed" => 3 },
      problem_rows: []
    )
    assert_match(/3 tests in manifest: 3 passed, 0 failed, 0 errored, 0 pending, 0 running/, io.string)
  end
end
