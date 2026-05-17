# frozen_string_literal: true

require "spec_helper"
require "stringio"

RSpec.describe Verity::Reporters::ParallelSummaryReporter do
  let(:io) { StringIO.new }

  subject(:reporter) { described_class.new(io) }

  it "emits manifest totals similar to parallel_summary_reporter_test.rb dogfood" do
    counts = { "passed" => 3, "failed" => 1, "errored" => 0, "pending" => 0, "running" => 0 }
    reporter.emit(counts: counts, problem_rows: [])
    output = io.string
    expect(output).to include("4 tests in manifest")
    expect(output).to include("3 passed").and include("1 failed")
  end

  it "shows failure headings when rows present" do
    counts = { "passed" => 0, "failed" => 1, "errored" => 0 }
    rows = [{
      fingerprint: "fp:abc",
      description: "broken test",
      status: :failed,
      failure: { "class" => "RuntimeError", "message" => "boom" }
    }]
    reporter.emit(counts: counts, problem_rows: rows)
    expect(io.string).to include("Failures and errors").and include("broken test").and include("boom")
  end

  it "suppresses failures section without problems" do
    reporter.emit(counts: { "passed" => 2 }, problem_rows: [])
    expect(io.string).not_to include("Failures and errors")
  end
end
