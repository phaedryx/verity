# frozen_string_literal: true

require "etc"

module Verity
  # Public: Holds all user-configurable settings for a Verity test run.
  # Access via `Verity.configuration` or inside a `Verity.configure` block.
  #
  # Examples
  #
  #   Verity.configure do |c|
  #     c.test_globs    = ["test/**/*_test.rb"]
  #     c.worker_count  = :cpus
  #     c.reporter      = Verity::Reporters::DotsReporter.new($stdout)
  #   end
  class Configuration
    # Public: String path for the SQLite manifest database. Use ":memory:" for
    # an in-process database (single-worker only; cannot be used with parallel
    # workers). Default: "verity/manifest.db" (relative to the process working
    # directory, typically the project root).
    #
    # Public: Array of glob Strings matched against the working directory to
    # discover test files. Default: ["verity/**/*_test.rb"].
    #
    # Public: Integer worker count, or :cpus / "cpus" to auto-detect from
    # Etc.nprocessors. Default: 1.
    #
    # Public: Object implementing the Verity::Reporter interface that receives
    # lifecycle callbacks. Default: ColoredDotsReporter writing to $stdout.
    #
    # Public: Test dispatch order for manifest runs: :random (default; shuffled
    # once in the coordinator) or :fingerprint (sorted). A non-nil #shuffle_seed
    # always implies a shuffle, even if test_order is :fingerprint.
    #
    # Public: Integer RNG seed for shuffled order. When nil and order is random,
    # a seed is chosen, stored here, and printed to stderr (the number only)
    # before workers start.
    #
    # Public: Optional Array of [absolute_path, Integer line] pairs (from CLI
    # file:line). When non-empty, only tests whose #line matches, or that have
    # an enclosing #group opened on that file:line, are runnable.
    attr_accessor :manifest_path, :test_globs, :worker_count, :reporter,
                  :test_order, :shuffle_seed, :location_filters

    def initialize
      set_defaults!
    end

    def set_defaults!
      @manifest_path = "verity/manifest.db"
      @test_globs = ["verity/**/*_test.rb"]
      @worker_count = :cpus
      @reporter = Verity::Reporters::ColoredDotsReporter.new($stdout)
      @test_order = :random
      @shuffle_seed = nil
      @location_filters = []
    end

    # Public: Resolve worker_count to an Integer, expanding :cpus to the
    # number of available processors.
    #
    # Returns a positive Integer.
    # Raises ArgumentError if the value cannot be resolved or is less than 1.
    def resolved_worker_count
      n =
        if self.class.cpus_worker_token?(worker_count)
          [Etc.nprocessors, 1].max
        else
          begin
            Integer(worker_count)
          rescue TypeError, ArgumentError
            raise ArgumentError,
                  "worker_count must be a positive Integer or :cpus / \"cpus\" (got #{worker_count.inspect})"
          end
        end
      raise ArgumentError, "worker_count must be >= 1 (got #{n})" if n < 1

      n
    end

    # Public: Check whether the manifest is configured as in-memory.
    #
    # Returns true when manifest_path is ":memory:".
    def memory_manifest?
      manifest_path == ":memory:"
    end

    # Public: Expand test_globs into a sorted, deduplicated list of file paths.
    #
    # Returns a sorted Array of String file paths.
    def test_files
      test_globs.flat_map { |pattern| Dir.glob(pattern) }.uniq.sort
    end

    class << self
      # Internal: Determine whether a value represents the :cpus worker token.
      # Accepts :cpus, :cpu, "cpus", or "cpu" (case-insensitive).
      #
      # value - Symbol or String to check.
      #
      # Returns true if the value is a cpus token.
      def cpus_worker_token?(value)
        case value
        when :cpus, :cpu
          true
        when String
          s = value.strip.downcase
          s == "cpus" || s == "cpu"
        else
          false
        end
      end
    end
  end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
