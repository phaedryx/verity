# frozen_string_literal: true

require "minitest/autorun"
require "verity"
require "verity/rails"
require "verity_test_helper"

# ---------------------------------------------------------------------------
# Richer fake that covers the new delegation surface
# ---------------------------------------------------------------------------
module FakeIntegration2
  Response = Struct.new(:status, :body, :location)

  Session = Class.new do
    attr_reader :calls, :host_value, :https_value, :cookies, :flash

    def initialize(_app)
      @calls       = []
      @status      = 200
      @body        = ""
      @location    = nil
      @host_value  = nil
      @https_value = nil
      @cookies     = { "session" => "abc" }
      @flash       = { "notice" => "saved" }
    end

    # Stubbed HTTP methods (enough for delegation checks)
    def get(_path) = @calls << :get
    def post(_path) = @calls << :post

    def response
      FakeIntegration2::Response.new(@status, @body, @location)
    end

    def redirect?
      (300..399).cover?(@status)
    end

    # Configurable helpers used by individual tests
    def set_status(s)   = @status   = s
    def set_location(l) = @location = l

    # Delegated methods under test
    def follow_redirect!
      @calls << :follow_redirect!
    end

    def host!(name)
      @host_value = name
      @calls << :host!
    end

    def https!(flag = true)
      @https_value = flag
      @calls << :https!
    end
  end
end

# ---------------------------------------------------------------------------
# Test class
# ---------------------------------------------------------------------------
class RailsIntegrationSessionTest < Minitest::Test
  include VerityTestHelper

  def setup
    reset_verity_process_state!
    stub_action_dispatch!
    @app     = ->(_env) { [200, {}, [""]] }
    Verity::Rails.configure { |c| c.integration_app = @app }
    Verity::Rails.install!
    @session = Verity::Rails::Integration::Session.new
    # Expose the inner fake session for direct state manipulation
    @inner = @session.session
  end

  # -------------------------------------------------------------------------
  # Delegation of follow_redirect!, cookies, flash, host!, https!
  # -------------------------------------------------------------------------

  def test_follow_redirect_is_delegated
    @session.follow_redirect!
    assert_includes @inner.calls, :follow_redirect!
  end

  def test_cookies_is_delegated
    assert_equal({ "session" => "abc" }, @session.cookies)
  end

  def test_flash_is_delegated
    assert_equal({ "notice" => "saved" }, @session.flash)
  end

  def test_host_bang_is_delegated
    @session.host!("example.com")
    assert_equal "example.com", @inner.host_value
    assert_includes @inner.calls, :host!
  end

  def test_https_bang_is_delegated
    @session.https!
    assert_equal true, @inner.https_value
    assert_includes @inner.calls, :https!
  end

  def test_https_bang_with_false_is_delegated
    @session.https!(false)
    assert_equal false, @inner.https_value
  end

  # -------------------------------------------------------------------------
  # assert_response
  # -------------------------------------------------------------------------

  def test_assert_response_passes_on_matching_integer
    @inner.set_status(200)
    @session.assert_response(200) # must not raise
  end

  def test_assert_response_raises_on_wrong_integer
    @inner.set_status(404)
    err = assert_raises(Verity::AssertionError) { @session.assert_response(200) }
    assert_match(/Expected response to be 200/, err.message)
  end

  def test_assert_response_success_passes_for_2xx
    @inner.set_status(201)
    @session.assert_response(:success)
  end

  def test_assert_response_success_raises_for_404
    @inner.set_status(404)
    assert_raises(Verity::AssertionError) { @session.assert_response(:success) }
  end

  def test_assert_response_redirect_passes_for_302
    @inner.set_status(302)
    @session.assert_response(:redirect)
  end

  def test_assert_response_redirect_raises_for_200
    @inner.set_status(200)
    assert_raises(Verity::AssertionError) { @session.assert_response(:redirect) }
  end

  def test_assert_response_missing_passes_for_404
    @inner.set_status(404)
    @session.assert_response(:missing)
  end

  def test_assert_response_missing_raises_for_200
    @inner.set_status(200)
    assert_raises(Verity::AssertionError) { @session.assert_response(:missing) }
  end

  def test_assert_response_error_passes_for_500
    @inner.set_status(500)
    @session.assert_response(:error)
  end

  def test_assert_response_error_raises_for_200
    @inner.set_status(200)
    assert_raises(Verity::AssertionError) { @session.assert_response(:error) }
  end

  def test_assert_response_raises_argument_error_for_unknown_symbol
    @inner.set_status(200)
    assert_raises(ArgumentError) { @session.assert_response(:banana) }
  end

  # -------------------------------------------------------------------------
  # assert_redirected_to
  # -------------------------------------------------------------------------

  def test_assert_redirected_to_raises_when_not_redirect
    @inner.set_status(200)
    @inner.set_location("/dashboard")
    err = assert_raises(Verity::AssertionError) { @session.assert_redirected_to("/dashboard") }
    assert_match(/Expected redirect \(3xx\)/, err.message)
  end

  def test_assert_redirected_to_passes_with_exact_string
    @inner.set_status(302)
    @inner.set_location("/dashboard")
    @session.assert_redirected_to("/dashboard")
  end

  def test_assert_redirected_to_raises_on_wrong_string
    @inner.set_status(302)
    @inner.set_location("/home")
    err = assert_raises(Verity::AssertionError) { @session.assert_redirected_to("/dashboard") }
    assert_match(/Expected redirect to/, err.message)
    assert_match(%r{/dashboard}, err.message)
  end

  def test_assert_redirected_to_passes_with_matching_regexp
    @inner.set_status(301)
    @inner.set_location("/users/42")
    @session.assert_redirected_to(%r{/users/\d+})
  end

  def test_assert_redirected_to_raises_with_non_matching_regexp
    @inner.set_status(301)
    @inner.set_location("/products/42")
    assert_raises(Verity::AssertionError) { @session.assert_redirected_to(%r{/users/\d+}) }
  end

  private

  def stub_action_dispatch!
    # Replace any previously stubbed const so this test file is self-contained.
    if defined?(ActionDispatch)
      ActionDispatch::Integration.send(:remove_const, :Session) if defined?(ActionDispatch::Integration::Session)
    else
      Object.const_set(:ActionDispatch, Module.new)
      ActionDispatch.const_set(:Integration, Module.new)
    end
    ActionDispatch::Integration.const_set(:Session, FakeIntegration2::Session)
  end
end
