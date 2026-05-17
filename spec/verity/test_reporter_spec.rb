# frozen_string_literal: true

require "spec_helper"

RSpec.describe Verity::Reporters::TestReporter do
  subject(:reporter) { described_class.new }

  it "records run_start payloads" do
    reporter.on_run_start(total: 5, worker_id: 0)
    expect(reporter.run_starts).to eq([{ total: 5, worker_id: 0 }])
  end

  it "records pass status on test_complete" do
    reporter.on_test_complete(result: reporter_result(status: :pass), worker_id: 0)
    expect(reporter.test_completes.first[:status]).to eq(:pass)
  end

  it "stores run_finish summary" do
    s = reporter_summary
    reporter.on_run_finish(summary: s, worker_id: 0)
    expect(reporter.run_finishes).to eq([{ summary: s, worker_id: 0 }])
  end

  it "captures parallel_complete" do
    reporter.on_parallel_complete(counts: { "passed" => 1 }, problem_rows: [])
    expect(reporter.parallel_finishes.size).to eq(1)
  end
end
