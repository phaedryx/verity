# frozen_string_literal: true

module Verity
  module Reporters
    # Public: Like DotsReporter, but uses ANSI colors when outputting to a TTY.
    # Green for pass, red for failure, yellow for error. Respects NO_COLOR,
    # FORCE_COLOR, and VERITY_FORCE_COLOR environment variables.
    class ColoredDotsReporter < DotsReporter
      ESC = "\e["
      RESET = "#{ESC}0m"
      PASS = "#{ESC}32m"
      FAIL = "#{ESC}31m"
      ERR = "#{ESC}33m"

      # Public: Create a new ColoredDotsReporter.
      #
      # io    - IO object for output (default $stdout).
      # color - Boolean to force color on/off, or nil for auto-detect.
      def initialize(io = $stdout, color: nil)
        super(io)
        @color_override = color
      end

      # Public: Print a colored dot, F, or E for the completed test.
      def on_test_complete(result:, worker_id:)
        char, sequence =
          case result.status
          when :pass  then [".", PASS]
          when :fail  then ["F", FAIL]
          when :error then ["E", ERR]
          end
        if color?
          @io.print "#{sequence}#{char}#{RESET}"
        else
          @io.print char
        end
        @io.flush
      end

      private

      def color?
        return @color_override unless @color_override.nil?

        return false if ENV.key?("NO_COLOR")
        return true if truthy_env?(ENV["FORCE_COLOR"]) || truthy_env?(ENV["VERITY_FORCE_COLOR"])

        @io.respond_to?(:tty?) && @io.tty?
      end

      def truthy_env?(value)
        %w[1 true yes].include?(value&.downcase)
      end
    end
  end
end
