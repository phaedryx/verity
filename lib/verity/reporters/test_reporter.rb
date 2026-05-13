# frozen_string_literal: true

module Verity
  module Reporters
    # Public: In-memory reporter that records every callback for later
    # inspection. Produces no I/O — designed for use in Verity's own tests
    # and tooling.
    class TestReporter
      include Verity::Reporter

      def initialize
        @run_starts = []
        @test_completes = []
        @run_finishes = []
        @parallel_finishes = []
      end

      # Public: Array of Hashes recorded from on_run_start calls.
      # Each Hash contains :total and :worker_id.
      #
      # Public: Array of Hashes recorded from on_test_complete calls.
      # Each Hash contains :status and :worker_id.
      #
      # Public: Array of Hashes recorded from on_run_finish calls.
      # Each Hash contains :summary and :worker_id.
      #
      # Public: Array of Hashes recorded from on_parallel_complete calls.
      # Each Hash contains :counts and :problem_rows.
      attr_reader :run_starts, :test_completes, :run_finishes, :parallel_finishes

      def on_run_start(total:, worker_id:)
        @run_starts << { total: total, worker_id: worker_id }
      end

      def on_test_complete(result:, worker_id:)
        @test_completes << { status: result.status, worker_id: worker_id }
      end

      def on_run_finish(summary:, worker_id:)
        @run_finishes << { summary: summary, worker_id: worker_id }
      end

      def on_parallel_complete(counts:, problem_rows:)
        @parallel_finishes << { counts: counts, problem_rows: problem_rows }
      end
    end
  end
end
