# frozen_string_literal: true

require "minitest/autorun"
require "verity"
require "verity/rails"
require "verity_test_helper"

# Fake ActionMailer::Base with a deliveries array, mirroring the FakeActiveRecord
# pattern in rails_test.rb.
module FakeActionMailer
  class Base
    class << self
      def deliveries
        @deliveries ||= []
      end

      def deliveries=(val)
        @deliveries = val
      end
    end
  end
end

# Fake ActionMailer::TestHelper so build_helper_module returns non-nil without
# requiring a real Rails environment.
module FakeActionMailerTestHelper
end

class VerityRailsHelpersTest < Minitest::Test
  include VerityTestHelper

  def setup
    reset_verity_process_state!
    stub_action_mailer!
  end

  # Verify that ActionMailer::Base.deliveries is cleared by the after_test hook.
  def test_deliveries_cleared_between_tests
    Verity::Rails::TestHelpers.apply!

    # Simulate email sent during a test.
    ActionMailer::Base.deliveries << "message1"
    assert_equal 1, ActionMailer::Base.deliveries.size

    # Fire the after_test hooks (as the runner would between tests).
    Verity.hooks[:after_test].each(&:call)

    assert_empty ActionMailer::Base.deliveries,
                 "expected ActionMailer::Base.deliveries to be cleared after test"
  end

  # Verify that the cleanup hook is robust when optional helpers are absent —
  # travel_back and clear_enqueued_jobs are not defined on main:Object here, but
  # the hook must not raise.
  def test_cleanup_hook_does_not_raise_when_helpers_absent
    Verity::Rails::TestHelpers.apply!

    assert_silent do
      Verity.hooks[:after_test].each(&:call)
    end
  end

  # Verify that applying twice (across reset boundaries) still registers a fresh
  # cleanup hook that clears deliveries.
  def test_deliveries_cleared_after_reset_and_reapply
    Verity::Rails::TestHelpers.apply!
    Verity.hooks[:after_test].each(&:call)

    # Reset and reapply (simulates a new test process run in tests).
    reset_verity_process_state!
    stub_action_mailer!
    Verity::Rails::TestHelpers.apply!

    ActionMailer::Base.deliveries << "message2"
    Verity.hooks[:after_test].each(&:call)

    assert_empty ActionMailer::Base.deliveries,
                 "expected deliveries cleared after reset + reapply"
  end

  private

  def stub_action_mailer!
    # Stub ActionMailer::Base
    if defined?(ActionMailer)
      ActionMailer.send(:remove_const, :Base) if ActionMailer.const_defined?(:Base, false)
    else
      Object.const_set(:ActionMailer, Module.new)
    end
    ActionMailer.const_set(:Base, FakeActionMailer::Base)
    FakeActionMailer::Base.deliveries = []

    # Stub ActionMailer::TestHelper so build_helper_module includes something.
    ActionMailer.const_set(:TestHelper, FakeActionMailerTestHelper) unless ActionMailer.const_defined?(:TestHelper, false)
  end
end
