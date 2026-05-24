# frozen_string_literal: true

module Verity
  module Reporters
    # Internal: Shared helper that emits the multi-worker summary block.
    # Typically called from a reporter's on_parallel_complete to print
    # aggregate counts and list any failures or errors from the manifest.
    class ParallelSummaryReporter
      def initialize(io = $stdout)
        @io = io
      end

      # Public: Write the parallel-run summary to the IO stream.
      #
      # counts       - Hash with String status keys ("passed", "failed", etc.)
      #                and Integer counts.
      # problem_rows - Array of Hashes with :fingerprint, :description, :status,
      #                and :failure from Manifest#failures_for_report.
      #
      # Returns nothing.
      def emit(counts:, problem_rows:)
        passed = counts.fetch("passed", 0)
        failed = counts.fetch("failed", 0)
        errored = counts.fetch("errored", 0)
        pending = counts.fetch("pending", 0)
        running = counts.fetch("running", 0)
        skipped = counts.fetch("skipped", 0)
        total = passed + failed + errored + pending + running

        line = "Parallel run finished (#{total} tests in manifest: #{passed} passed, #{failed} failed, #{errored} errored, #{pending} pending, #{running} running"
        line += ", #{skipped} skipped" if skipped > 0
        line += ")"
        @io.puts "\n#{line}"

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
