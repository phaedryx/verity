# frozen_string_literal: true

require "forwardable"

module Verity
  module Rails
    # Public: HTTP integration testing via ActionDispatch::Integration::Session.
    module Integration
      # Public: Thin wrapper around ActionDispatch::Integration::Session.
      class Session
        extend Forwardable

        def_delegators :@session, :get, :post, :patch, :put, :delete, :head, :response, :redirect?,
                                   :follow_redirect!, :cookies, :flash, :host!, :https!

        def initialize(app: nil)
          @app = app || Verity::Rails.configuration.integration_app
          @app ||= ::Rails.application if defined?(::Rails)
          unless @app
            raise ArgumentError,
                  "integration_app is required (set Verity::Rails.configuration.integration_app " \
                  "or boot Rails before calling integration_session)"
          end

          require_integration!
          @session = ActionDispatch::Integration::Session.new(@app)
        end

        attr_reader :session

        # Public: Assert that the response has the expected status.
        #
        # type - Integer status code, or one of :success, :redirect, :missing, :error.
        #
        # Raises Verity::AssertionError when the response status does not match.
        def assert_response(type)
          status = @session.response.status
          expected_range =
            case type
            when :success  then 200..299
            when :redirect then 300..399
            when :missing  then 404..404
            when :error    then 500..599
            when Integer   then type..type
            else
              raise ArgumentError, "assert_response expects an Integer or one of :success, " \
                                   ":redirect, :missing, :error — got #{type.inspect}"
            end
          return if expected_range.cover?(status)

          raise Verity::AssertionError,
                "Expected response to be #{type.inspect} but was #{status}"
        end

        # Public: Assert that the response is a redirect to the given location.
        #
        # pattern - String (exact match) or Regexp matched against the Location header.
        #
        # Raises Verity::AssertionError when the response is not a 3xx redirect, or the
        # Location header does not match pattern.
        def assert_redirected_to(pattern)
          status = @session.response.status
          unless (300..399).cover?(status)
            raise Verity::AssertionError,
                  "Expected redirect (3xx) but response status was #{status}"
          end

          location = @session.response.location
          matched =
            if pattern.is_a?(Regexp)
              location =~ pattern
            else
              location == pattern
            end

          return if matched

          raise Verity::AssertionError,
                "Expected redirect to #{pattern.inspect} but Location was #{location.inspect}"
        end

        private

        def require_integration!
          return if defined?(ActionDispatch::Integration::Session)

          raise LoadError,
                "ActionDispatch::Integration::Session is required for integration tests " \
                "(add actionpack / rails to the test bundle)"
        end
      end

      # Public: Top-level helpers mixed into Object when Verity::Rails.install! runs.
      module DSL
        HTTP_METHODS = %i[get post patch put delete head].freeze

        class << self
          def apply!
            mod = Module.new do
              define_method(:integration_session) do
                Thread.current[:verity_rails_integration_session] ||=
                  Verity::Rails::Integration::Session.new
              end

              define_method(:reset_integration_session!) do
                Thread.current[:verity_rails_integration_session] = nil
              end

              if Verity::Rails.configuration.delegate_http_methods
                HTTP_METHODS.each do |verb|
                  define_method(verb) do |*args, **kwargs, &block|
                    integration_session.public_send(verb, *args, **kwargs, &block)
                  end
                end
              end
            end
            Object.include(mod)
            Verity::Rails.register_dsl_extension!(mod)
          end
        end
      end

      class << self
        # Internal: Reset thread-local session state after each test when configured.
        def apply!
          Verity::Rails::Integration::DSL.apply!
          return unless Verity::Rails.configuration.reset_integration_session_per_test

          Verity.after_test do
            Thread.current[:verity_rails_integration_session] = nil
          end
        end
      end
    end
  end
end
