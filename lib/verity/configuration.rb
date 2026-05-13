# frozen_string_literal: true

require "etc"

module Verity
  class Configuration
    # @!attribute [rw] reporter
    #   Receives {Verity::Reporter} lifecycle callbacks from {Runner} and the parent process after parallel runs.
    #   Default: {Verity::Reporters::ColoredDotsReporter} writing to `$stdout` (colors when TTY; see {Verity::Reporters::ColoredDotsReporter}).
    #   Set your own object — typically `include Verity::Reporter` and override selected hooks.
    #
    # @!attribute [rw] worker_count
    #   Fixed pool as Integer (or decimal string), or +:cpus+ / +:cpu+ / +"cpus"+ to use one worker per {::Etc.nprocessors} (minimum +1+).
    attr_accessor :manifest_path, :test_globs, :worker_count, :reporter

    def initialize
      set_defaults!
    end

    def set_defaults!
      @manifest_path = ":memory:"
      @test_globs = ["verity/**/*_test.rb"]
      @worker_count = 1
      @reporter = Verity::Reporters::ColoredDotsReporter.new($stdout)
    end

    # Integer worker count used by {Verity.run} (resolves +:cpus+ and compatible string forms).
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

    def memory_manifest?
      manifest_path == ":memory:"
    end

    def test_files
      test_globs.flat_map { |pattern| Dir.glob(pattern) }.uniq.sort
    end

    class << self
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
