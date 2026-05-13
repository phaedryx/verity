# frozen_string_literal: true

module Verity
  module Reporters
    # Public: Multiplexer that forwards every Reporter callback to multiple
    # child reporters. Useful when you need both console output and
    # machine-readable logging from the same run.
    #
    # Examples
    #
    #   Verity.configure do |c|
    #     c.reporter = Verity::Reporters::CompositeReporter.new(
    #       Verity::Reporters::DotsReporter.new($stdout),
    #       Verity::Reporters::TestReporter.new
    #     )
    #   end
    class CompositeReporter
      include Verity::Reporter

      # Public: Create a new CompositeReporter wrapping one or more reporters.
      #
      # reporters - One or more objects implementing Verity::Reporter.
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
