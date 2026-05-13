# frozen_string_literal: true

require "minitest/autorun"
require "stringio"
require_relative "../lib/verity"

class DotsReporterTest < Minitest::Test
  def test_on_test_complete_prints_dot_for_pass
    io = StringIO.new
    rep = Verity::Reporters::DotsReporter.new(io)
    rep.on_test_complete(result: make_result(status: :pass), worker_id: 0)
    assert_equal ".", io.string
  end

  def test_on_test_complete_prints_f_for_fail
    io = StringIO.new
    rep = Verity::Reporters::DotsReporter.new(io)
    rep.on_test_complete(result: make_result(status: :fail, error: StandardError.new("x")), worker_id: 0)
    assert_equal "F", io.string
  end

  def test_on_test_complete_prints_e_for_error
    io = StringIO.new
    rep = Verity::Reporters::DotsReporter.new(io)
    rep.on_test_complete(result: make_result(status: :error, error: RuntimeError.new("x")), worker_id: 0)
    assert_equal "E", io.string
  end

  def test_on_test_complete_skip_does_not_crash
    io = StringIO.new
    rep = Verity::Reporters::DotsReporter.new(io)
    rep.on_test_complete(result: make_result(status: :skip), worker_id: 0)
    assert_equal "", io.string
  end

  def test_on_run_finish_prints_summary
    io = StringIO.new
    rep = Verity::Reporters::DotsReporter.new(io)
    summary = { total: 5, passed: 3, failed: 1, errored: 1, skipped: 0, focus: false }
    rep.on_run_finish(summary: summary, worker_id: 0)
    assert_match(/5 tests: 3 passed, 1 failed, 1 errored/, io.string)
  end

  def test_on_run_finish_includes_skipped_when_positive
    io = StringIO.new
    rep = Verity::Reporters::DotsReporter.new(io)
    summary = { total: 4, passed: 2, failed: 0, errored: 0, skipped: 2, focus: false }
    rep.on_run_finish(summary: summary, worker_id: 0)
    assert_match(/2 skipped/, io.string)
  end

  def test_on_run_finish_includes_focus_tag
    io = StringIO.new
    rep = Verity::Reporters::DotsReporter.new(io)
    summary = { total: 1, passed: 1, failed: 0, errored: 0, skipped: 0, focus: true }
    rep.on_run_finish(summary: summary, worker_id: 0)
    assert_match(/\(focus\)/, io.string)
  end

  private

  def make_result(status:, error: nil)
    t = Verity::Test.new(
      fingerprint: "dots.rb:#{'d' * 16}",
      description: "x",
      tags: [],
      timeout: nil,
      requires: [],
      resources: {},
      file: "dots.rb",
      line: 1,
      fn: -> {},
      group_path: [],
      inherited_group_tags: []
    )
    Verity::Runner::Result.new(test: t, status: status, error: error)
  end
end
