# frozen_string_literal: true

module Verity
  module Reporters
    # Public: Verbose reporter that prints one indented line per test, nesting
    # output under group headers. Uses ANSI colors (green/red/yellow/magenta)
    # when outputting to a TTY, unless suppressed by NO_COLOR or forced via
    # FORCE_COLOR / VERITY_FORCE_COLOR.
    class DocumentationReporter
      include Verity::Reporter

      ESC = "\e["
      RESET = "#{ESC}0m"
      PASS_STYLE = "#{ESC}32m"
      FAIL_STYLE = "#{ESC}31m"
      SKIP_STYLE = "#{ESC}33m"
      ERROR_STYLE = "#{ESC}35m"

      # Public: Create a new DocumentationReporter.
      #
      # io    - IO object for output (default $stdout).
      # color - Boolean to force color on/off, or nil for auto-detect.
      def initialize(io = $stdout, color: nil)
        @io = io
        @color_override = color
      end

      # Public: Print a "Running N tests..." header.
      def on_run_start(total:, worker_id:)
        @last_group_path = nil
        return if total.nil?

        @io.puts "Running #{total} tests..."
        @io.puts
      end

      # Public: Print a status-labeled line for the completed test, indented
      # under its group headers.
      def on_test_complete(result:, worker_id:)
        path = Array(result.test.group_path)
        emit_group_headers(path)
        indent = "  " * (path.size + 1)
        case result.status
        when :pass
          @io.puts "#{indent}#{paint("pass", PASS_STYLE)}  #{result.test.description}"
        when :fail
          @io.puts "#{indent}#{paint("FAIL", FAIL_STYLE)}  #{result.test.description}\n         #{result.error.message}"
        when :error
          msg = "#{result.error.class}: #{result.error.message}"
          @io.puts "#{indent}#{paint("ERROR", ERROR_STYLE)} #{result.test.description}\n         #{msg}"
        when :skip
          @io.puts "#{indent}#{paint("skip", SKIP_STYLE)}  #{result.test.description}"
        end
      end

      # Public: Print the final summary line with counts and optional color.
      def on_run_finish(summary:, worker_id:)
        t = summary[:total]
        p = summary[:passed]
        f = summary[:failed]
        e = summary[:errored]
        sk = summary[:skipped].to_i
        if color?
          parts = [
            "\n#{t} tests:",
            "#{paint("#{p} passed", PASS_STYLE)},",
            "#{paint("#{f} failed", FAIL_STYLE)},",
            "#{paint("#{e} errored", ERROR_STYLE)}"
          ]
          parts << ", #{paint("#{sk} skipped", SKIP_STYLE)}" if sk.positive?
          line = "#{parts.join(" ")}#{RESET}"
        else
          line = "\n#{t} tests: #{p} passed, #{f} failed, #{e} errored"
          line += ", #{sk} skipped" if sk.positive?
        end
        line += " (focus)" if summary[:focus]
        @io.puts line
      end

      # Public: Delegate to ParallelSummaryReporter for the multi-worker summary.
      def on_parallel_complete(counts:, problem_rows:)
        ParallelSummaryReporter.new(@io).emit(counts:, problem_rows:)
      end

      private

      def paint(text, sequence)
        return text unless color?

        "#{sequence}#{text}#{RESET}"
      end

      def color?
        return @color_override unless @color_override.nil?

        return false if ENV.key?("NO_COLOR")
        return true if truthy_env?(ENV["FORCE_COLOR"]) || truthy_env?(ENV["VERITY_FORCE_COLOR"])

        @io.respond_to?(:tty?) && @io.tty?
      end

      def truthy_env?(value)
        %w[1 true yes].include?(value&.downcase)
      end

      def emit_group_headers(path)
        last = @last_group_path || []
        common = 0
        n = [last.size, path.size].min
        while common < n && last[common] == path[common]
          common += 1
        end

        (common...path.size).each do |i|
          @io.puts "#{"  " * i}#{path[i]}"
        end
        @last_group_path = path.dup
      end
    end
  end
end
