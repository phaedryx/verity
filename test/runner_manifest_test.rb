# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/verity"
require_relative "verity_test_helper"

class RunnerManifestTest < Minitest::Test
  include VerityTestHelper

  def test_run_manifest_empty
    # Arrange
    reset_verity_process_state!
    manifest = open_memory_manifest
    runner = Verity::Runner.new(reporter: Verity::Reporters::NullReporter.new)

    begin
      # Act
      outcome = runner.run_manifest(manifest, worker_id: 42)

      # Assert
      assert_equal true, outcome
    ensure
      cleanup_verity_and_close(manifest)
    end
  end

  def test_run_manifest_executes_queue_and_updates_manifest
    # Arrange
    reset_verity_process_state!
    manifest = open_memory_manifest
    runner = Verity::Runner.new(reporter: Verity::Reporters::NullReporter.new)
    first_test = passing_test(fingerprint: "a.rb:1111111111111111", description: "one")
    second_test = passing_test(fingerprint: "b.rb:2222222222222222", description: "two")
    Verity::Registry.register(first_test)
    Verity::Registry.register(second_test)
    manifest.replace_tests([first_test, second_test])

    begin
      # Act
      outcome = runner.run_manifest(manifest, worker_id: 7)

      # Assert
      assert outcome
      sqlite = sqlite_connection(manifest)
      statuses = sqlite.execute("SELECT fingerprint, status FROM tests ORDER BY fingerprint").to_h
      assert_equal({ "a.rb:1111111111111111" => "passed", "b.rb:2222222222222222" => "passed" }, statuses)
    ensure
      cleanup_verity_and_close(manifest)
    end
  end

  def test_run_manifest_records_failure_and_error
    # Arrange
    reset_verity_process_state!
    manifest = open_memory_manifest
    runner = Verity::Runner.new(reporter: Verity::Reporters::NullReporter.new)
    good = passing_test(fingerprint: "g.rb:aaaaaaaaaaaaaaaa")
    bad = failing_test
    boom = Verity::Test.new(
      fingerprint: "e.rb:cccccccccccccccc",
      description: "raises",
      tags: [],
      timeout: nil,
      requires: [],
      resources: {},
      file: "e.rb",
      line: 1,
      fn: -> { raise "boom" },
      group_path: [],
      inherited_group_tags: []
    )
    Verity::Registry.register(good)
    Verity::Registry.register(bad)
    Verity::Registry.register(boom)
    manifest.replace_tests([good, bad, boom])

    begin
      # Act
      outcome = runner.run_manifest(manifest, worker_id: 1)

      # Assert
      refute outcome
      sqlite = sqlite_connection(manifest)
      assert_equal "passed", sqlite.get_first_value("SELECT status FROM tests WHERE fingerprint = ?", good.fingerprint)
      assert_equal "failed", sqlite.get_first_value("SELECT status FROM tests WHERE fingerprint = ?", bad.fingerprint)
      assert_equal "errored", sqlite.get_first_value("SELECT status FROM tests WHERE fingerprint = ?", boom.fingerprint)
    ensure
      cleanup_verity_and_close(manifest)
    end
  end

  def test_missing_registry_row_becomes_errored
    # Arrange
    reset_verity_process_state!
    manifest = open_memory_manifest
    runner = Verity::Runner.new(reporter: Verity::Reporters::NullReporter.new)
    orphan_row = Verity::Test.new(
      fingerprint: "orphan.rb:dddddddddddddddd",
      description: "orphan",
      tags: [],
      timeout: nil,
      requires: [],
      resources: {},
      file: "orphan.rb",
      line: 1,
      fn: -> {},
      group_path: [],
      inherited_group_tags: []
    )
    manifest.replace_tests([orphan_row])
    Verity::Registry.clear

    begin
      # Act
      outcome = runner.run_manifest(manifest, worker_id: 3)

      # Assert
      refute outcome
      sqlite = sqlite_connection(manifest)
      assert_equal "errored", sqlite.get_first_value("SELECT status FROM tests WHERE fingerprint = ?", orphan_row.fingerprint)
    ensure
      cleanup_verity_and_close(manifest)
    end
  end

  def test_hooks_fire_around_run_manifest
    # Arrange
    reset_verity_process_state!
    manifest = open_memory_manifest
    runner = Verity::Runner.new(reporter: Verity::Reporters::NullReporter.new)
    log = []
    Verity.before_worker_start { log << :worker }
    Verity.before_test { log << :before }
    Verity.after_test { log << :after }
    lone_test = passing_test
    Verity::Registry.register(lone_test)
    manifest.replace_tests([lone_test])

    begin
      # Act
      runner.run_manifest(manifest, worker_id: 0)

      # Assert
      assert_equal %i[worker before after], log
    ensure
      cleanup_verity_and_close(manifest)
    end
  end

  private

  def open_memory_manifest
    Verity::Manifest.open(":memory:").tap(&:migrate!)
  end

  def cleanup_verity_and_close(manifest)
    reset_verity_process_state!
    manifest.close
  end

  def sqlite_connection(manifest)
    manifest.db
  end

  def passing_test(fingerprint: "ok.rb:aaaaaaaaaaaaaaaa", description: "passes")
    Verity::Test.new(
      fingerprint:,
      description:,
      tags: [],
      timeout: nil,
      requires: [],
      resources: {},
      file: "ok.rb",
      line: 1,
      fn: -> {},
      group_path: [],
      inherited_group_tags: []
    )
  end

  def failing_test(fingerprint: "bad.rb:bbbbbbbbbbbbbbbb")
    Verity::Test.new(
      fingerprint:,
      description: "fails",
      tags: [],
      timeout: nil,
      requires: [],
      resources: {},
      file: "bad.rb",
      line: 1,
      fn: -> { raise Verity::AssertionError, "fails" },
      group_path: [],
      inherited_group_tags: []
    )
  end
end
