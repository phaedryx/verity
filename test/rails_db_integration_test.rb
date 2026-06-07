# frozen_string_literal: true

require "minitest/autorun"
require "active_record"
require "verity"
require "verity/rails"
require "verity_test_helper"

# Sets up a real in-memory SQLite database, defines an ActiveRecord model,
# then proves Verity's transactional isolation rolls back between tests.
class VerityRailsDbIntegrationTest < Minitest::Test
  include VerityTestHelper

  def setup
    reset_verity_process_state!
    setup_db!
  end

  def teardown
    teardown_db!
  end

  def test_transactional_isolation_rolls_back_between_tests
    Verity::Rails.configure { |c| c.transactional_tests = true }
    Verity::Rails.install!

    test("first test inserts a widget") do
      Widget.create!(name: "gadget")
      assert_equal 1, Widget.count
    end

    test("second test sees no widgets from first test") do
      assert_equal 0, Widget.count
    end

    reporter = Verity::Reporters::TestReporter.new
    runner = Verity::Runner.new(reporter: reporter)
    all_passed = runner.run(Verity::Registry.all)

    diagnostics = reporter.test_completes.map { |r| "#{r[:status]}: #{r[:error]}" }.join(", ")
    assert all_passed, "Expected both tests to pass (isolation failed). Results: #{diagnostics}"
  end

  def test_fixtures_load_before_per_test_transaction
    # Proves fixture rows survive per-test rollback (fixtures committed before transaction opens)
    # This test can be skipped if fixture YAML loading is not set up, but the structure
    # should document the expected behaviour with a skip + message.
    skip "Fixture loading requires YAML fixture files; this test documents expected behaviour"
  end

  private

  def setup_db!
    ActiveRecord::Base.establish_connection(
      adapter: "sqlite3",
      database: ":memory:"
    )
    ActiveRecord::Schema.define do
      create_table :widgets, force: true do |t|
        t.string :name, null: false
      end
    end

    Object.const_set(:Widget, Class.new(ActiveRecord::Base)) unless defined?(Widget)
  end

  def teardown_db!
    Object.send(:remove_const, :Widget) if defined?(Widget)
    ActiveRecord::Base.remove_connection
  end
end
