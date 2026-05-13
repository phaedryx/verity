# frozen_string_literal: true

module Verity
  module Reporters
    class CompositeReporter
      include Verity::Reporter

      def initialize(*reporters)
        @reporters = reporters
      end

      def on_run_start(total:, worker_id:)
        @reporters.each { _1.on_run_start(total:, worker_id:) }
      end

      def on_test_complete(result:, worker_id:)
        @reporters.each { _1.on_test_complete(result:, worker_id:) }
      end

      def on_run_finish(summary:, worker_id:)
        @reporters.each { _1.on_run_finish(summary:, worker_id:) }
      end

      def on_parallel_complete(counts:, problem_rows:)
        @reporters.each { _1.on_parallel_complete(counts:, problem_rows:) }
      end
    end
  end
end
