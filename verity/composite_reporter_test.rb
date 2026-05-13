# frozen_string_literal: true

# Dogfood mirror of test/composite_reporter_test.rb

test "composite on_run_start delegates to all reporters" do
  r1 = Verity::Reporters::TestReporter.new
  r2 = Verity::Reporters::TestReporter.new
  r3 = Verity::Reporters::TestReporter.new
  composite = Verity::Reporters::CompositeReporter.new(r1, r2, r3)

  composite.on_run_start(total: 5, worker_id: 0)

  [r1, r2, r3].each do |r|
    assert_equal actual: r.run_starts, expected: [{ total: 5, worker_id: 0 }]
  end
end

test "composite on_test_complete delegates to all reporters" do
  r1 = Verity::Reporters::TestReporter.new
  r2 = Verity::Reporters::TestReporter.new
  composite = Verity::Reporters::CompositeReporter.new(r1, r2)

  t = Verity::Test.new(
    fingerprint: "comp.rb:#{"a" * 16}",
    description: "one",
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
  result = Verity::Runner::Result.new(test: t, status: :pass, error: nil)
  composite.on_test_complete(result: result, worker_id: 1)

  [r1, r2].each do |r|
    assert_equal actual: r.test_completes, expected: [{ status: :pass, worker_id: 1 }]
  end
end

test "composite on_run_finish delegates to all reporters" do
  r1 = Verity::Reporters::TestReporter.new
  r2 = Verity::Reporters::TestReporter.new
  composite = Verity::Reporters::CompositeReporter.new(r1, r2)

  summary = { total: 3, passed: 2, failed: 1, errored: 0, skipped: 0, focus: false }
  composite.on_run_finish(summary: summary, worker_id: 0)

  [r1, r2].each do |r|
    assert_equal actual: r.run_finishes.size, expected: 1
    assert_equal actual: r.run_finishes.first[:summary], expected: summary
    assert_equal actual: r.run_finishes.first[:worker_id], expected: 0
  end
end

test "composite on_parallel_complete delegates to all reporters" do
  r1 = Verity::Reporters::TestReporter.new
  r2 = Verity::Reporters::TestReporter.new
  r3 = Verity::Reporters::TestReporter.new
  composite = Verity::Reporters::CompositeReporter.new(r1, r2, r3)

  counts = { "passed" => 10, "failed" => 1 }
  rows = [{ fingerprint: "x", description: "bad", status: :failed, failure: { "message" => "no" } }]
  composite.on_parallel_complete(counts: counts, problem_rows: rows)

  [r1, r2, r3].each do |r|
    assert_equal actual: r.parallel_finishes.size, expected: 1
    assert_equal actual: r.parallel_finishes.first[:counts], expected: counts
    assert_equal actual: r.parallel_finishes.first[:problem_rows], expected: rows
  end
end
