# frozen_string_literal: true

module Verity
  module Rails
    # Public: Settings for Verity::Rails.install! (database isolation, fixtures,
    # integration session, and Rails test helpers).
    class Configuration
      # Public: When true, wrap each test in a database transaction and roll back
      # in after_test (requires ActiveRecord).
      attr_accessor :transactional_tests

      # Public: When true, disconnect ActiveRecord connection pools in each forked
      # worker before tests run (default true).
      attr_accessor :reconnect_after_fork

      # Public: When true, set ENV["TEST_ENV_NUMBER"] from the worker id and
      # re-establish the test connection (Rails parallel database naming).
      attr_accessor :per_worker_database

      # Public: Fixture sets to load — Array of Symbols, or :all for every set
      # under #fixture_path. Default [] (no fixtures).
      attr_accessor :fixture_sets

      # Public: Directory containing YAML fixtures. Default nil (resolved at install
      # time to Rails.root/test/fixtures or ./test/fixtures).
      attr_accessor :fixture_path

      # Public: Rack app for integration tests. Default nil (Rails.application when
      # defined).
      attr_accessor :integration_app

      # Public: When true, discard the integration session after each test.
      attr_accessor :reset_integration_session_per_test

      # Public: When true, define top-level get/post/patch/put/delete/head that
      # delegate to #integration_session (default false).
      attr_accessor :delegate_http_methods

      def initialize
        @transactional_tests = false
        @reconnect_after_fork = true
        @per_worker_database = false
        @fixture_sets = []
        @fixture_path = nil
        @integration_app = nil
        @reset_integration_session_per_test = true
        @delegate_http_methods = false
      end
    end
  end
end
