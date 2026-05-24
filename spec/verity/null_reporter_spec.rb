# frozen_string_literal: true

require "spec_helper"

RSpec.describe "NullReporter (triple suite twin of verity/null_reporter_test.rb)" do
  subject(:reporter) { Verity::Reporters::NullReporter.new }

  it "responds to lifecycle hooks without IO" do
    reporter.on_run_start(total: 1, worker_id: 0)
    reporter.on_test_complete(result: reporter_result(status: :pass), worker_id: 0)
    reporter.on_run_finish(summary: reporter_summary(total: 1, passed: 1, failed: 0, errored: 0),
                           worker_id: 0)
    reporter.on_parallel_complete(counts: {}, problem_rows: [])
  end
end
