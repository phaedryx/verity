# frozen_string_literal: true

module Verity
  module Rails
    # Public: Bootstraps a Rails app test helper and runs Verity::CLI.
    module Runner
      HELPER_RELATIVE_PATHS = [
        "test/verity_helper.rb"
      ].freeze

      class HelperNotFound < Verity::Rails::Error
        def initialize
          super(
            "Verity helper not found. Run `bin/rails generate verity:install` " \
            "or create test/verity_helper.rb."
          )
        end
      end

      class << self
        # Public: Load test/verity_helper.rb from Rails.root unless already loaded.
        #
        # Returns Pathname of the helper file.
        # Raises HelperNotFound when no helper exists.
        def load_helper!
          path = helper_path or raise HelperNotFound

          expanded = path.expand_path.to_s
          unless @loaded_helper_path == expanded
            load expanded
            @loaded_helper_path = expanded
          end
          path
        end

        # Public: Resolve the Verity helper path under Rails.root.
        #
        # Returns Pathname or nil.
        def helper_path
          root = ::Rails.root
          HELPER_RELATIVE_PATHS.each do |relative|
            candidate = root.join(relative)
            return candidate if candidate.file?
          end
          nil
        end

        # Public: Load the helper (when present) and run the CLI.
        #
        # argv - Array of CLI tokens (file globs and options).
        #
        # Returns Integer exit code.
        def run!(argv)
          require "verity/cli"
          load_helper!
          Verity::CLI.run(Array(argv))
        end

        # Public: Extract verity CLI args from a Rake ARGV after `--`.
        #
        # When present, `--` separates rake arguments from passthrough options.
        # Otherwise returns an empty Array.
        #
        # argv - Array, typically ARGV from a rake task (default: ARGV).
        #
        # Returns Array of String CLI tokens.
        def rake_argv(argv = ARGV)
          separator = argv.index("--")
          separator ? argv[(separator + 1)..] || [] : []
        end
      end
    end
  end
end
