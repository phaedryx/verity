# frozen_string_literal: true

module Verity
  # Hooks for test run lifecycle.
  #
  # Use a built-in under {Verity::Reporters}, or define your own:
  #
  #   class MyReporter
  #     include Verity::Reporter
  #
  #     def on_test_complete(result:, worker_id:)
  #       puts result.test.description
  #     end
  #   end
  #
  #   Verity.configure { |c| c.reporter = MyReporter.new }
  module Reporter
    # @param total [Integer, nil] expected examples in this process (nil if unknown)
    # @param worker_id [Integer] manifest worker id
    def on_run_start(total:, worker_id:); end

    # @param result [Verity::Runner::Result] final status for one test
    # @param worker_id [Integer]
    def on_test_complete(result:, worker_id:); end

    # @param summary [Hash] +:total+, +:passed+, +:failed+, +:errored+, +:skipped+, +:focus+ (boolean)
    # @param worker_id [Integer]
    def on_run_finish(summary:, worker_id:); end

    # After all forked workers exit; only invoked from the parent in {Verity.run}.
    # @param counts [Hash] String status keys from {Verity::Manifest#count_by_status}
    # @param problem_rows [Array<Hash>] from {Verity::Manifest#failures_for_report}
    def on_parallel_complete(counts:, problem_rows:); end
  end
end
