# frozen_string_literal: true

# Triple suite (compare / redundant proof): verity/colored_dots_test.rb · spec/verity/colored_dots_spec.rb

require "minitest/autorun"
require "stringio"
require_relative "../lib/verity"

class ColoredDotsReporterTest < Minitest::Test
  def test_plain_output_when_color_false
    io = StringIO.new
    rep = Verity::Reporters::ColoredDotsReporter.new(io, color: false)
    t = Verity::Test.new(
      fingerprint: "a.rb:#{'a' * 16}",
      description: "x",
      tags: [],
      timeout: nil,
      requires: [],
      resources: {},
      file: "a.rb",
      line: 1,
      fn: -> {},
      group_path: [],
      inherited_group_tags: [], group_scopes: []
    )
    r = Verity::Runner::Result.new(test: t, status: :pass, error: nil)
    rep.on_test_complete(result: r, worker_id: 0)
    assert_equal ".", io.string
  end

  def test_ansi_when_color_true
    io = StringIO.new
    rep = Verity::Reporters::ColoredDotsReporter.new(io, color: true)
    t = Verity::Test.new(
      fingerprint: "a.rb:#{'a' * 16}",
      description: "x",
      tags: [],
      timeout: nil,
      requires: [],
      resources: {},
      file: "a.rb",
      line: 1,
      fn: -> {},
      group_path: [],
      inherited_group_tags: [], group_scopes: []
    )
    rep.on_test_complete(result: Verity::Runner::Result.new(test: t, status: :pass, error: nil), worker_id: 0)
    assert_match(/\e\[32m\.\e\[0m/, io.string)

    io2 = StringIO.new
    rep2 = Verity::Reporters::ColoredDotsReporter.new(io2, color: true)
    rep2.on_test_complete(result: Verity::Runner::Result.new(test: t, status: :fail, error: StandardError.new("x")), worker_id: 0)
    assert_match(/\e\[31mF\e\[0m/, io2.string)

    io3 = StringIO.new
    rep3 = Verity::Reporters::ColoredDotsReporter.new(io3, color: true)
    rep3.on_test_complete(result: Verity::Runner::Result.new(test: t, status: :error, error: RuntimeError.new("x")), worker_id: 0)
    assert_match(/\e\[33mE\e\[0m/, io3.string)
  end

  def test_skip_prints_cyan_s_when_color_enabled
    io = StringIO.new
    rep = Verity::Reporters::ColoredDotsReporter.new(io, color: true)
    t = Verity::Test.new(
      fingerprint: "a.rb:#{'a' * 16}",
      description: "x",
      tags: [],
      timeout: nil,
      requires: [],
      resources: {},
      file: "a.rb",
      line: 1,
      fn: -> {},
      group_path: [],
      inherited_group_tags: [], group_scopes: []
    )
    rep.on_test_complete(result: Verity::Runner::Result.new(test: t, status: :skip, error: nil), worker_id: 0)
    assert_match(/\e\[36mS\e\[0m/, io.string)
  end
end
