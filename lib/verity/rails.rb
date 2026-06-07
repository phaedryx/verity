# frozen_string_literal: true

require_relative "rails/configuration"
require_relative "rails/database"
require_relative "rails/fixtures"
require_relative "rails/integration"
require_relative "rails/test_helpers"

module Verity
  # Public: Optional Rails integration for Verity test suites. Requires Rails
  # (or relevant components) in the host app's Gemfile; nothing is loaded until
  # `require "verity/rails"`.
  #
  # Examples
  #
  #   require "verity/rails"
  #
  #   Verity::Rails.configure do |c|
  #     c.transactional_tests = true
  #     c.reconnect_after_fork = true
  #     c.fixture_sets = [:users]
  #   end
  #
  #   Verity::Rails.install!
  module Rails
    class Error < StandardError; end

    class AlreadyInstalledError < Error; end

    require_relative "rails/runner"

    class << self
      # Public: User settings for #install!.
      def configuration
        @configuration ||= Configuration.new
      end

      # Public: Configure Rails integration before #install!.
      def configure
        yield configuration
        self
      end

      # Public: Register hooks and mix Rails helpers into top-level test files.
      # Call once from test/verity_helper.rb after the Rails environment loads.
      #
      # Raises AlreadyInstalledError when called more than once per process.
      def install!
        raise AlreadyInstalledError, "Verity::Rails.install! was already called" if @installed

        Database.apply!
        Fixtures.apply!
        Integration.apply!
        TestHelpers.apply!
        @installed = true
        self
      end

      # Internal: Reset install state (used by Verity's own tests).
      def reset!
        @configuration = nil
        @installed = false
        @dsl_extensions = nil
        Verity::Rails::Runner.instance_variable_set(:@loaded_helper_path, nil)
      end

      # Internal: Track anonymous modules included into Object for debugging.
      def register_dsl_extension!(mod)
        (@dsl_extensions ||= []) << mod
      end

      # Internal: Called from Fixtures.apply! after load hook is registered.
      def apply_fixture_dsl!
        Fixtures::DSL.apply!
      end
    end
  end
end
