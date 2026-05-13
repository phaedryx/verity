# frozen_string_literal: true

module Verity
  module Reporters
    # Like {DotsReporter}, but uses ANSI colors when enabled (TTY, no +NO_COLOR+, or +FORCE_COLOR+ / +VERITY_FORCE_COLOR+).
    class ColoredDotsReporter < DotsReporter
      ESC = "\e["
      RESET = "#{ESC}0m"
      PASS = "#{ESC}32m"
      FAIL = "#{ESC}31m"
      ERR = "#{ESC}33m"

      # @param io [IO]
      # @param color [true, false, nil] +nil+ means auto-detect from TTY and environment
      def initialize(io = $stdout, color: nil)
        super(io)
        @color_override = color
      end

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
