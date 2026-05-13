# frozen_string_literal: true

module Verity
  # Public: Interface module for test-run lifecycle hooks. Include this module
  # and override the methods you need. All methods are no-ops by default.
  #
  # Examples
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
    # Public: Called once when a worker begins its test run.
    #
    # total     - Integer expected number of examples, or nil if unknown.
    # worker_id - Integer manifest worker id.
    #
    # Returns nothing.
    def on_run_start(total:, worker_id:); end

    # Public: Called after each individual test finishes.
    #
    # result    - Verity::Runner::Result with test, status, and error.
    # worker_id - Integer manifest worker id.
    #
    # Returns nothing.
    def on_test_complete(result:, worker_id:); end

    # Public: Called once after all tests in a worker have completed.
    #
    # summary   - Hash with :total, :passed, :failed, :errored, :skipped
    #             (Integers) and :focus (Boolean).
    # worker_id - Integer manifest worker id.
    #
    # Returns nothing.
    def on_run_finish(summary:, worker_id:); end

    # Public: Called from the parent process after all forked workers exit.
    # Only invoked during parallel runs via Verity.run.
    #
    # counts       - Hash with String status keys and Integer counts from
    #                Manifest#count_by_status.
    # problem_rows - Array of Hashes from Manifest#failures_for_report.
    #
    # Returns nothing.
    def on_parallel_complete(counts:, problem_rows:); end
  end
end
