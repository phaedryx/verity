# frozen_string_literal: true

require "spec_helper"
require "stringio"

RSpec.describe "Reporters" do
  let(:io) { StringIO.new }

  def make_result(status:, description: "example", error: nil)
    test = Verity::Test.new(
      fingerprint: "fp:abcdef0123456789",
      description: description,
      tags: [],
      timeout: nil,
      requires: [],
      resources: {},
      file: __FILE__,
      line: __LINE__,
      fn: -> {},
      group_path: [],
      inherited_group_tags: []
    )
    Verity::Runner::Result.new(test: test, status: status, error: error)
  end

  def make_result_with_group(status:, description:, group_path:, error: nil)
    test = Verity::Test.new(
      fingerprint: "fp:abcdef0123456789",
      description: description,
      tags: [],
      timeout: nil,
      requires: [],
      resources: {},
      file: __FILE__,
      line: __LINE__,
      fn: -> {},
      group_path: group_path,
      inherited_group_tags: []
    )
    Verity::Runner::Result.new(test: test, status: status, error: error)
  end

  def summary(total: 2, passed: 1, failed: 1, errored: 0, skipped: 0, focus: false)
    { total: total, passed: passed, failed: failed, errored: errored, skipped: skipped, focus: focus }
  end

  describe Verity::Reporters::DotsReporter do
    subject(:reporter) { described_class.new(io) }

    it "prints . for pass" do
      reporter.on_test_complete(result: make_result(status: :pass), worker_id: 0)
      expect(io.string).to eq(".")
    end

    it "prints F for fail" do
      reporter.on_test_complete(result: make_result(status: :fail, error: StandardError.new("bad")), worker_id: 0)
      expect(io.string).to eq("F")
    end

    it "prints E for error" do
      reporter.on_test_complete(result: make_result(status: :error, error: RuntimeError.new("boom")), worker_id: 0)
      expect(io.string).to eq("E")
    end

    it "prints summary on run finish" do
      reporter.on_run_finish(summary: summary, worker_id: 0)
      output = io.string
      expect(output).to include("2 tests")
      expect(output).to include("1 passed")
      expect(output).to include("1 failed")
    end

    it "includes skipped count when positive" do
      reporter.on_run_finish(summary: summary(skipped: 3), worker_id: 0)
      expect(io.string).to include("3 skipped")
    end

    it "includes (focus) when focus is active" do
      reporter.on_run_finish(summary: summary(focus: true), worker_id: 0)
      expect(io.string).to include("(focus)")
    end
  end

  describe Verity::Reporters::ColoredDotsReporter do
    it "prints ANSI codes when color is enabled" do
      reporter = described_class.new(io, color: true)
      reporter.on_test_complete(result: make_result(status: :pass), worker_id: 0)
      expect(io.string).to include("\e[32m")
    end

    it "prints plain characters when color is disabled" do
      reporter = described_class.new(io, color: false)
      reporter.on_test_complete(result: make_result(status: :pass), worker_id: 0)
      expect(io.string).to eq(".")
      expect(io.string).not_to include("\e[")
    end

    it "prints red for failures" do
      reporter = described_class.new(io, color: true)
      reporter.on_test_complete(result: make_result(status: :fail, error: StandardError.new("x")), worker_id: 0)
      expect(io.string).to include("\e[31m")
    end

    it "prints yellow for errors" do
      reporter = described_class.new(io, color: true)
      reporter.on_test_complete(result: make_result(status: :error, error: RuntimeError.new("x")), worker_id: 0)
      expect(io.string).to include("\e[33m")
    end
  end

  describe Verity::Reporters::DocumentationReporter do
    subject(:reporter) { described_class.new(io, color: false) }

    it "prints a run header with the test count" do
      reporter.on_run_start(total: 5, worker_id: 0)
      expect(io.string).to include("Running 5 tests")
    end

    it "prints pass lines" do
      reporter.on_test_complete(result: make_result(status: :pass, description: "works"), worker_id: 0)
      expect(io.string).to include("pass")
      expect(io.string).to include("works")
    end

    it "prints fail lines with error message" do
      err = Verity::AssertionError.new("nope")
      reporter.on_test_complete(result: make_result(status: :fail, description: "breaks", error: err), worker_id: 0)
      expect(io.string).to include("FAIL")
      expect(io.string).to include("breaks")
      expect(io.string).to include("nope")
    end

    it "prints skip lines" do
      reporter.on_test_complete(result: make_result(status: :skip, description: "skipped one"), worker_id: 0)
      expect(io.string).to include("skip")
      expect(io.string).to include("skipped one")
    end

    it "prints error lines" do
      err = RuntimeError.new("boom")
      reporter.on_test_complete(result: make_result(status: :error, description: "explodes", error: err), worker_id: 0)
      expect(io.string).to include("ERROR")
      expect(io.string).to include("RuntimeError")
    end

    it "emits group headers before nested tests" do
      result = make_result_with_group(status: :pass, description: "inner", group_path: ["Outer", "Inner"])
      reporter.on_test_complete(result: result, worker_id: 0)
      output = io.string
      expect(output).to include("Outer")
      expect(output).to include("Inner")
    end

    it "prints summary on run finish" do
      reporter.on_run_finish(summary: summary(total: 3, passed: 2, failed: 1, errored: 0), worker_id: 0)
      output = io.string
      expect(output).to include("3 tests")
      expect(output).to include("2 passed")
    end
  end

  describe Verity::Reporters::NullReporter do
    subject(:reporter) { described_class.new }

    it "implements all hooks without raising" do
      expect { reporter.on_run_start(total: 1, worker_id: 0) }.not_to raise_error
      expect { reporter.on_test_complete(result: make_result(status: :pass), worker_id: 0) }.not_to raise_error
      expect { reporter.on_run_finish(summary: summary, worker_id: 0) }.not_to raise_error
      expect { reporter.on_parallel_complete(counts: {}, problem_rows: []) }.not_to raise_error
    end
  end

  describe Verity::Reporters::TestReporter do
    subject(:reporter) { described_class.new }

    it "records run_start events" do
      reporter.on_run_start(total: 5, worker_id: 0)
      expect(reporter.run_starts).to eq([{ total: 5, worker_id: 0 }])
    end

    it "records test_complete events" do
      reporter.on_test_complete(result: make_result(status: :pass), worker_id: 0)
      expect(reporter.test_completes.size).to eq(1)
      expect(reporter.test_completes.first[:status]).to eq(:pass)
    end

    it "records run_finish events" do
      s = summary
      reporter.on_run_finish(summary: s, worker_id: 0)
      expect(reporter.run_finishes).to eq([{ summary: s, worker_id: 0 }])
    end

    it "records parallel_complete events" do
      reporter.on_parallel_complete(counts: { "passed" => 1 }, problem_rows: [])
      expect(reporter.parallel_finishes.size).to eq(1)
    end
  end

  describe Verity::Reporters::CompositeReporter do
    it "delegates all hooks to every child reporter" do
      r1 = Verity::Reporters::TestReporter.new
      r2 = Verity::Reporters::TestReporter.new
      composite = described_class.new(r1, r2)

      composite.on_run_start(total: 3, worker_id: 0)
      result = make_result(status: :pass)
      composite.on_test_complete(result: result, worker_id: 0)
      composite.on_run_finish(summary: summary, worker_id: 0)
      composite.on_parallel_complete(counts: {}, problem_rows: [])

      [r1, r2].each do |r|
        expect(r.run_starts.size).to eq(1)
        expect(r.test_completes.size).to eq(1)
        expect(r.run_finishes.size).to eq(1)
        expect(r.parallel_finishes.size).to eq(1)
      end
    end
  end

  describe Verity::Reporters::ParallelSummaryReporter do
    subject(:reporter) { described_class.new(io) }

    it "emits a summary with counts" do
      counts = { "passed" => 3, "failed" => 1, "errored" => 0, "pending" => 0, "running" => 0 }
      reporter.emit(counts: counts, problem_rows: [])
      output = io.string
      expect(output).to include("4 tests in manifest")
      expect(output).to include("3 passed")
      expect(output).to include("1 failed")
    end

    it "emits failure details" do
      counts = { "passed" => 0, "failed" => 1, "errored" => 0 }
      rows = [{
        fingerprint: "fp:abc",
        description: "broken test",
        status: :failed,
        failure: { "class" => "RuntimeError", "message" => "boom" }
      }]
      reporter.emit(counts: counts, problem_rows: rows)
      output = io.string
      expect(output).to include("Failures and errors")
      expect(output).to include("broken test")
      expect(output).to include("boom")
    end

    it "omits failure section when there are no problems" do
      counts = { "passed" => 2 }
      reporter.emit(counts: counts, problem_rows: [])
      expect(io.string).not_to include("Failures and errors")
    end
  end
end
