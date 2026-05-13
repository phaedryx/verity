# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/verity"
require_relative "verity_test_helper"

class CompositeReporterTest < Minitest::Test
  include VerityTestHelper

  def test_on_run_start_delegates_to_all_reporters
    reset_verity_process_state!
    r1 = Verity::Reporters::TestReporter.new
    r2 = Verity::Reporters::TestReporter.new
    r3 = Verity::Reporters::TestReporter.new
    composite = Verity::Reporters::CompositeReporter.new(r1, r2, r3)

    composite.on_run_start(total: 5, worker_id: 0)

    [r1, r2, r3].each do |r|
      assert_equal [{ total: 5, worker_id: 0 }], r.run_starts
    end
  end

  def test_on_test_complete_delegates_to_all_reporters
    reset_verity_process_state!
    r1 = Verity::Reporters::TestReporter.new
    r2 = Verity::Reporters::TestReporter.new
    composite = Verity::Reporters::CompositeReporter.new(r1, r2)

    t = make_test(fingerprint: "comp.rb:#{'a' * 16}", description: "one")
    result = Verity::Runner::Result.new(test: t, status: :pass, error: nil)
    composite.on_test_complete(result: result, worker_id: 1)

    [r1, r2].each do |r|
      assert_equal [{ status: :pass, worker_id: 1 }], r.test_completes
    end
  end

  def test_on_run_finish_delegates_to_all_reporters
    reset_verity_process_state!
    r1 = Verity::Reporters::TestReporter.new
    r2 = Verity::Reporters::TestReporter.new
    composite = Verity::Reporters::CompositeReporter.new(r1, r2)

    summary = { total: 3, passed: 2, failed: 1, errored: 0, skipped: 0, focus: false }
    composite.on_run_finish(summary: summary, worker_id: 0)

    [r1, r2].each do |r|
      assert_equal 1, r.run_finishes.size
      assert_equal summary, r.run_finishes.first[:summary]
      assert_equal 0, r.run_finishes.first[:worker_id]
    end
  end

  def test_on_parallel_complete_delegates_to_all_reporters
    reset_verity_process_state!
    r1 = Verity::Reporters::TestReporter.new
    r2 = Verity::Reporters::TestReporter.new
    r3 = Verity::Reporters::TestReporter.new
    composite = Verity::Reporters::CompositeReporter.new(r1, r2, r3)

    counts = { "passed" => 10, "failed" => 1 }
    rows = [{ fingerprint: "x", description: "bad", status: :failed, failure: { "message" => "no" } }]
    composite.on_parallel_complete(counts: counts, problem_rows: rows)

    [r1, r2, r3].each do |r|
      assert_equal 1, r.parallel_finishes.size
      assert_equal counts, r.parallel_finishes.first[:counts]
      assert_equal rows, r.parallel_finishes.first[:problem_rows]
    end
  end

  private

  def make_test(fingerprint:, description:)
    Verity::Test.new(
      fingerprint: fingerprint,
      description: description,
      tags: [],
      timeout: nil,
      requires: [],
      resources: {},
      file: "a.rb",
      line: 1,
      fn: -> {},
      group_path: [],
      inherited_group_tags: []
    )
  end
end
