# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "verity"
require "verity/rails"
require "verity_test_helper"

class FakeConnection
  attr_reader :events

  def initialize
    @events = []
    @open = 0
  end

  def open_transactions
    @open
  end

  def begin_transaction(joinable: true)
    @events << [:begin, joinable]
    @open += 1
  end

  def rollback_transaction
    @events << :rollback
    @open -= 1 if @open.positive?
  end
end

module FakeActiveRecord
  class Base
    class << self
      attr_accessor :connection_handler, :establish_env

      def connection
        @connection ||= FakeConnection.new
      end

      def establish_connection(env)
        self.establish_env = env
        @connection = FakeConnection.new
      end
    end
  end
end

module FakeIntegration
  Response = Struct.new(:status, :body)

  Session = Class.new do
    def initialize(app)
      @app = app
      @status = nil
      @body = nil
    end

    def get(_path)
      @status, _headers, body = @app.call({})
      @body = body.join
    end

    def post(_path)
      get(_path)
    end

    def response
      FakeIntegration::Response.new(@status, @body)
    end
  end
end

class FakeConnectionHandler
  attr_reader :cleared

  def clear_active_connections!(_role = nil)
    @cleared = true
  end

  def clear_all_connections!
    @cleared = true
  end
end

class VerityRailsTest < Minitest::Test
  include VerityTestHelper

  def setup
    reset_verity_process_state!
    @hooks_seen = []
    stub_active_record!
  end

  def test_install_registers_transactional_hooks
    Verity::Rails.configure { |c| c.transactional_tests = true }
    Verity::Rails.install!

    Verity.hooks[:before_test].each(&:call)
    assert(
      FakeActiveRecord::Base.connection.events.any? do |e|
        e.is_a?(Array) && e.first == :begin && e.last == false
      end
    )

    Verity.hooks[:after_test].each(&:call)
    assert_includes FakeActiveRecord::Base.connection.events, :rollback
  end

  def test_install_is_idempotent
    Verity::Rails.install!
    assert_raises(Verity::Rails::AlreadyInstalledError) { Verity::Rails.install! }
  end

  def test_reconnect_hook_runs_on_worker_start
    Verity::Rails.configure do |c|
      c.reconnect_after_fork = true
      c.per_worker_database = false
    end
    Verity::Rails.install!

    FakeActiveRecord::Base.connection.events << :stale
    Verity.hooks[:before_worker_start].each { |hook| hook.call(0) }

    assert_equal :test, FakeActiveRecord::Base.establish_env
    assert FakeActiveRecord::Base.connection_handler.cleared
    refute_includes FakeActiveRecord::Base.connection.events, :stale
  end

  def test_per_worker_database_sets_test_env_number
    Verity::Rails.configure do |c|
      c.per_worker_database = true
      c.reconnect_after_fork = false
    end
    Verity::Rails.install!

    Verity.hooks[:before_worker_start].each { |hook| hook.call(2) }
    assert_equal "2", ENV["TEST_ENV_NUMBER"]

    Verity.hooks[:before_worker_start].each { |hook| hook.call(0) }
    assert_equal "", ENV["TEST_ENV_NUMBER"]
  ensure
    ENV.delete("TEST_ENV_NUMBER")
  end

  def test_before_worker_start_receives_worker_id
    Verity.before_worker_start { |wid| @hooks_seen << wid }
    Verity::Rails.install!

    Verity.hooks[:before_worker_start].each { |hook| hook.call(7) }
    assert_includes @hooks_seen, 7
  end

  def test_integration_session_requires_app
    Verity::Rails.configure do |c|
      c.integration_app = nil
    end
    Verity::Rails.install!

    err = assert_raises(ArgumentError) { Verity::Rails::Integration::Session.new }
    assert_match(/integration_app is required/, err.message)
  end

  def test_integration_session_delegates_to_rack_session
    app = ->(_env) { [200, { "Content-Type" => "text/plain" }, ["ok"]] }
    stub_action_dispatch_integration!
    Verity::Rails.configure { |c| c.integration_app = app }
    Verity::Rails.install!

    session = Verity::Rails::Integration::Session.new
    session.get "/health"
    assert_equal 200, session.response.status
    assert_equal "ok", session.response.body
  end

  def test_reset_integration_session_clears_thread_local
    app = ->(_env) { [200, {}, [""]] }
    stub_action_dispatch_integration!
    Verity::Rails.configure do |c|
      c.integration_app = app
      c.reset_integration_session_per_test = false
    end
    Verity::Rails.install!

    first = integration_session
    reset_integration_session!
    second = integration_session
    refute_same first, second
  end

  def test_delegate_http_methods_when_enabled
    app = ->(_env) { [201, {}, ["created"]] }
    stub_action_dispatch_integration!
    Verity::Rails.configure do |c|
      c.integration_app = app
      c.delegate_http_methods = true
      c.reset_integration_session_per_test = false
    end
    Verity::Rails.install!

    post "/widgets"
    assert_equal 201, integration_session.response.status
    assert_equal "created", integration_session.response.body
  end

  private

  def stub_active_record!
    Object.send(:remove_const, :ActiveRecord) if defined?(ActiveRecord)
    Object.const_set(:ActiveRecord, Module.new)
    ActiveRecord.const_set(:Base, FakeActiveRecord::Base)

    FakeActiveRecord::Base.connection_handler = FakeConnectionHandler.new
  end

  def stub_action_dispatch_integration!
    return if defined?(ActionDispatch::Integration::Session)

    mod = Module.new
    Object.const_set(:ActionDispatch, Module.new) unless defined?(ActionDispatch)
    ActionDispatch.const_set(:Integration, Module.new) unless defined?(ActionDispatch::Integration)

    ActionDispatch::Integration.const_set(:Session, FakeIntegration::Session)
  end
end
