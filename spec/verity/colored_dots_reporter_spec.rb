# frozen_string_literal: true

require "spec_helper"
require "stringio"

RSpec.describe "ColoredDotsReporter (triple suite twin of verity/colored_dots_test.rb)" do
  let(:io) { StringIO.new }

  it "prints ANSI sequences when color is enabled" do
    reporter = Verity::Reporters::ColoredDotsReporter.new(io, color: true)
    reporter.on_test_complete(result: reporter_result(status: :pass), worker_id: 0)
    expect(io.string).to include("\e[32m")
  end

  it "prints plain '.' when color is disabled" do
    reporter = Verity::Reporters::ColoredDotsReporter.new(io, color: false)
    reporter.on_test_complete(result: reporter_result(status: :pass), worker_id: 0)
    expect(io.string).to eq(".")
    expect(io.string).not_to include("\e[")
  end

  it "prints red ANSI for failures when color enabled" do
    reporter = Verity::Reporters::ColoredDotsReporter.new(io, color: true)
    reporter.on_test_complete(
      result: reporter_result(status: :fail, error: StandardError.new("x")),
      worker_id: 0
    )
    expect(io.string).to include("\e[31m")
  end

  it "prints yellow ANSI for errors when color enabled" do
    reporter = Verity::Reporters::ColoredDotsReporter.new(io, color: true)
    reporter.on_test_complete(
      result: reporter_result(status: :error, error: RuntimeError.new("x")),
      worker_id: 0
    )
    expect(io.string).to include("\e[33m")
  end

  it "prints cyan skip when color enabled" do
    reporter = Verity::Reporters::ColoredDotsReporter.new(io, color: true)
    reporter.on_test_complete(result: reporter_result(status: :skip), worker_id: 0)
    expect(io.string).to include("\e[36m")
    expect(io.string).to include("S")
    expect(io.string).to include("\e[0m")
  end
end
