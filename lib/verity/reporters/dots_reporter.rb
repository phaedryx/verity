# frozen_string_literal: true

module Verity
  module Reporters
    # Public: Minimal reporter that prints a single character per test:
    # "." for pass, "F" for failure, "E" for error. No color.
    class DotsReporter
      include Verity::Reporter

      # Public: Create a new DotsReporter.
      #
      # io - IO object for output (default $stdout).
      def initialize(io = $stdout)
        @io = io
      end

      # Public: Print a dot, F, E, or S (skip) for the completed test.
      def on_test_complete(result:, worker_id:)
        char =
          case result.status
          when :pass then "."
          when :fail then "F"
          when :error then "E"
          when :skip then "S"
          end
        @io.print char
        @io.flush
      end

      # Public: Print the final summary line with counts.
      def on_run_finish(summary:, worker_id:)
        t = summary[:total]
        p = summary[:passed]
        f = summary[:failed]
        e = summary[:errored]
        line = "\n\n#{t} tests: #{p} passed, #{f} failed, #{e} errored"
        line += ", #{summary[:skipped]} skipped" if summary[:skipped].to_i.positive?
        line += " (focus)" if summary[:focus]
        line += " (tags)" if summary[:tag_filter]
        @io.puts line
      end

      # Public: Delegate to ParallelSummaryReporter for the multi-worker summary.
      def on_parallel_complete(counts:, problem_rows:)
        ParallelSummaryReporter.new(@io).emit(counts:, problem_rows:)
      end
    end
  end
end
