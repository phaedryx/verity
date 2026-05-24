# frozen_string_literal: true

require "spec_helper"

RSpec.describe Verity::Reporters::CompositeReporter do
  it "delegates every hook to all children (verity/composite_reporter_test.rb twin)" do
    r1 = Verity::Reporters::TestReporter.new
    r2 = Verity::Reporters::TestReporter.new
    composite = described_class.new(r1, r2)

    composite.on_run_start(total: 3, worker_id: 0)
    composite.on_test_complete(result: reporter_result(status: :pass), worker_id: 0)
    composite.on_run_finish(summary: reporter_summary, worker_id: 0)
    composite.on_parallel_complete(counts: {}, problem_rows: [])

    [r1, r2].each do |r|
      expect(r.run_starts.size).to eq(1)
      expect(r.test_completes.size).to eq(1)
      expect(r.run_finishes.size).to eq(1)
      expect(r.parallel_finishes.size).to eq(1)
    end
  end
end
