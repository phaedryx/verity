# frozen_string_literal: true

module Verity
  module Reporters
    class DotsReporter
      include Verity::Reporter

      def initialize(io = $stdout)
        @io = io
      end

      def on_test_complete(result:, worker_id:)
        char =
          case result.status
          when :pass then "."
          when :fail then "F"
          when :error then "E"
          end
        @io.print char
        @io.flush
      end

      def on_run_finish(summary:, worker_id:)
        t = summary[:total]
        p = summary[:passed]
        f = summary[:failed]
        e = summary[:errored]
        line = "\n\n#{t} tests: #{p} passed, #{f} failed, #{e} errored"
        line += ", #{summary[:skipped]} skipped" if summary[:skipped].to_i.positive?
        line += " (focus)" if summary[:focus]
        @io.puts line
      end

      def on_parallel_complete(counts:, problem_rows:)
        ParallelSummaryReporter.new(@io).emit(counts:, problem_rows:)
      end
    end
  end
end
