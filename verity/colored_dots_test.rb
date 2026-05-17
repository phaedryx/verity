# frozen_string_literal: true

require "stringio"

# Dogfood mirror of test/colored_dots_test.rb

test "colored dots plain when color false" do
  io = StringIO.new
  rep = Verity::Reporters::ColoredDotsReporter.new(io, color: false)
  t = Verity::Test.new(
    fingerprint: "a.rb:#{"a" * 16}",
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
  assert_equal actual: io.string, expected: "."
end

test "colored dots ansi when color true" do
  io = StringIO.new
  rep = Verity::Reporters::ColoredDotsReporter.new(io, color: true)
  t = Verity::Test.new(
    fingerprint: "a.rb:#{"a" * 16}",
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
  assert_match pattern: /\e\[32m\.\e\[0m/, actual: io.string

  io2 = StringIO.new
  rep2 = Verity::Reporters::ColoredDotsReporter.new(io2, color: true)
  rep2.on_test_complete(
    result: Verity::Runner::Result.new(test: t, status: :fail, error: StandardError.new("x")),
    worker_id: 0
  )
  assert_match pattern: /\e\[31mF\e\[0m/, actual: io2.string

  io3 = StringIO.new
  rep3 = Verity::Reporters::ColoredDotsReporter.new(io3, color: true)
  rep3.on_test_complete(
    result: Verity::Runner::Result.new(test: t, status: :error, error: RuntimeError.new("x")),
    worker_id: 0
  )
  assert_match pattern: /\e\[33mE\e\[0m/, actual: io3.string
end
