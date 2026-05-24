# frozen_string_literal: true

require "spec_helper"
require "stringio"

RSpec.describe "DocumentationReporter (triple suite twin of verity/documentation_reporter_test.rb)" do
  let(:io) { StringIO.new }
  subject(:reporter) { Verity::Reporters::DocumentationReporter.new(io, color: false) }

  it "prints a run header with the test count" do
    reporter.on_run_start(total: 5, worker_id: 0)
    expect(io.string).to include("Running 5 tests")
  end

  it "prints pass lines" do
    reporter.on_test_complete(result: reporter_result(status: :pass, description: "works"), worker_id: 0)
    expect(io.string).to include("pass").and include("works")
  end

  it "prints fail lines with assertion message" do
    err = Verity::AssertionError.new("nope")
    reporter.on_test_complete(result: reporter_result(status: :fail, description: "breaks", error: err),
                                worker_id: 0)
    expect(io.string).to include("FAIL").and include("breaks").and include("nope")
  end

  it "prints skip lines" do
    reporter.on_test_complete(result: reporter_result(status: :skip, description: "skipped one"), worker_id: 0)
    expect(io.string).to include("skip").and include("skipped one")
  end

  it "prints error lines" do
    err = RuntimeError.new("boom")
    reporter.on_test_complete(
      result: reporter_result(status: :error, description: "explodes", error: err),
      worker_id: 0
    )
    expect(io.string).to include("ERROR").and include("RuntimeError")
  end

  it "emits nested group headings" do
    reporter.on_test_complete(
      result: reporter_result(status: :pass, description: "inner", group_path: %w[Outer Inner]),
      worker_id: 0
    )
    expect(io.string).to include("Outer").and include("Inner")
  end

  it "prints summary on finish" do
    reporter.on_run_finish(summary: reporter_summary(total: 3, passed: 2, failed: 1, errored: 0),
                           worker_id: 0)
    expect(io.string).to include("3 tests").and include("2 passed")
  end
end
