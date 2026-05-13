# frozen_string_literal: true

module Verity
  module Reporters
    # Emits the multi-worker summary block (typically from a reporter's +on_parallel_complete+).
    class ParallelSummaryReporter
      def initialize(io = $stdout)
        @io = io
      end

      def emit(counts:, problem_rows:)
        passed = counts.fetch("passed", 0)
        failed = counts.fetch("failed", 0)
        errored = counts.fetch("errored", 0)
        pending = counts.fetch("pending", 0)
        running = counts.fetch("running", 0)
        total = passed + failed + errored + pending + running

        @io.puts "\nParallel run finished (#{total} tests in manifest: #{passed} passed, #{failed} failed, #{errored} errored, #{pending} pending, #{running} running)"

        return if problem_rows.empty?

        @io.puts "\nFailures and errors:"
        problem_rows.each do |row|
          fp = row[:fingerprint]
          desc = row[:description]
          st = row[:status]
          @io.puts "  #{st}  #{desc} (#{fp})"
          next if row[:failure].nil? || row[:failure].empty?

          msg = row[:failure]["message"] || row[:failure][:message]
          @io.puts "         #{msg}" if msg
        end
      end
    end
  end
end
