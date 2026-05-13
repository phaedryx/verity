# frozen_string_literal: true

module Verity
  module Reporters
    # Records {Reporter} callbacks in memory for tests and tooling (no I/O).
    class TestReporter
      include Verity::Reporter

      def initialize
        @run_starts = []
        @test_completes = []
        @run_finishes = []
        @parallel_finishes = []
      end

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
