# frozen_string_literal: true

require "spec_helper"
require "stringio"

RSpec.describe "DotsReporter (triple suite twin of verity/dots_reporter_test.rb)" do
  let(:io) { StringIO.new }

  subject(:reporter) { Verity::Reporters::DotsReporter.new(io) }

  it 'prints "." for pass' do
    reporter.on_test_complete(result: reporter_result(status: :pass), worker_id: 0)
    expect(io.string).to eq(".")
  end

  it 'prints F for fail' do
    reporter.on_test_complete(
      result: reporter_result(status: :fail, error: StandardError.new("bad")),
      worker_id: 0
    )
    expect(io.string).to eq("F")
  end

  it 'prints E for error' do
    reporter.on_test_complete(
      result: reporter_result(status: :error, error: RuntimeError.new("boom")),
      worker_id: 0
    )
    expect(io.string).to eq("E")
  end

  it 'prints S for skip' do
    reporter.on_test_complete(result: reporter_result(status: :skip), worker_id: 0)
    expect(io.string).to eq("S")
  end

  it "prints summary on run finish (parallel to dogfood wording)" do
    reporter.on_run_finish(summary: reporter_summary(total: 5, passed: 3, failed: 1, errored: 1), worker_id: 0)
    expect(io.string).to match(/5 tests: 3 passed, 1 failed, 1 errored/)
  end

  it "includes skipped count when positive" do
    reporter.on_run_finish(summary: reporter_summary(skipped: 3), worker_id: 0)
    expect(io.string).to match(/3 skipped/)
  end

  it "includes (focus) when focus is active" do
    reporter.on_run_finish(summary: reporter_summary(focus: true, total: 1, passed: 1, failed: 0, errored: 0),
                           worker_id: 0)
    expect(io.string).to include("(focus)")
  end
end
