# frozen_string_literal: true

require "optparse"

module Verity
  # Public: Command-line interface for the verity executable and Rails rake task.
  module CLI
    class ParseError < StandardError; end

    class << self
      # Public: Parse argv, apply configuration, and run the suite.
      #
      # argv - Array of String CLI tokens (typically ARGV or a copy).
      #
      # Returns Integer exit code (0 success, 1 test failure, 2 usage/config error).
      def run(argv)
        parse!(argv)
        Verity.run ? 0 : 1
      rescue ParseError, OptionParser::InvalidOption, OptionParser::MissingArgument => e
        warn "verity: #{e.message}"
        2
      rescue ArgumentError => e
        warn "verity: #{e.message}"
        2
      end

      # Public: Parse argv and mutate Verity configuration. Positional paths remain
      # in argv after options are consumed.
      #
      # Raises ParseError on invalid user input.
      def parse!(argv)
        OptionParser.new do |o|
          o.banner = "Usage: verity [options] [file-or-glob ...]"
          o.separator ""
          o.separator "If file-or-glob arguments are given, only those paths are loaded."
          o.separator "Use path/to/file.rb:LINE to run the test on that line or every test in the group opened there."
          o.separator "Otherwise the configured default is used (see Verity::Configuration#test_globs)."
          o.separator ""
          apply_option_definitions(o)
        end.parse!(argv)

        apply_positional_paths!(argv)
      end

      private

      def apply_option_definitions(parser)
        parser.on(
          "-r",
          "--reporter NAME",
          "Output reporter: colored (default), colored_dots, dots, documentation, doc, null, none, silent;",
          "or path/to/reporter.rb:ClassName for a custom class (include Verity::Reporter)."
        ) do |name|
          Verity.configure { |c| c.reporter = Verity.build_reporter(name) }
        end
        parser.on(
          "-w",
          "--workers COUNT",
          "Parallel worker processes: a positive integer or cpus (one worker per CPU via Etc.nprocessors)."
        ) do |v|
          Verity.configure { |c| c.worker_count = v.strip }
        end
        parser.on("--order MODE", "Test order: random (default; use --seed to fix RNG) or fingerprint (sorted).") do |v|
          mode = v.to_s.strip.downcase
          unless %w[fingerprint random].include?(mode)
            raise ParseError, "--order must be fingerprint or random (got #{v.inspect})"
          end

          Verity.configure { |c| c.test_order = mode.to_sym }
        end
        parser.on(
          "-t",
          "--tag NAME",
          "Run only tests whose effective tags include NAME (see group/test tags:).",
          "Repeat for OR semantics: a test runs if it has any of the named tags."
        ) do |raw|
          tok = Verity.parse_tag_filter_token(raw)
          raise ParseError, "--tag requires a non-empty name (got #{raw.inspect})" unless tok

          Verity.configure { |c| c.included_tags += [tok] }
        end
        parser.on(
          "--exclude-tag NAME",
          "Do not run tests whose effective tags include NAME (after any --tag narrowing).",
          "Repeat to exclude when any of the named tags is present."
        ) do |raw|
          tok = Verity.parse_tag_filter_token(raw)
          raise ParseError, "--exclude-tag requires a non-empty name (got #{raw.inspect})" unless tok

          Verity.configure { |c| c.excluded_tags += [tok] }
        end
        parser.on("--seed INTEGER", Integer, "RNG seed for shuffled order (printed only when auto-chosen).") do |n|
          Verity.configure { |c| c.shuffle_seed = n }
        end
        parser.on("-h", "--help", "Show this help") do
          puts parser
          exit 0
        end
      end

      def apply_positional_paths!(argv)
        return if argv.empty?

        globs = []
        filters = []
        argv.each do |raw|
          if (m = raw.match(/\A(.+):(\d+)\z/))
            path_part = m[1]
            line_part = Integer(m[2], 10)
            abs = File.expand_path(path_part)
            unless File.file?(abs)
              raise ParseError,
                    "#{raw.inspect} — line filter requires an existing file (got #{abs.inspect})"
            end
            globs << abs
            filters << [abs, line_part]
          else
            globs << File.expand_path(raw)
          end
        end
        Verity.configure do |c|
          c.test_globs = globs.uniq
          c.location_filters = filters unless filters.empty?
        end
      end
    end
  end
end
