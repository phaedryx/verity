# frozen_string_literal: true

# Triple suite: test/test_reporter_test.rb · spec/verity/test_reporter_spec.rb

TR_RESULT = lambda do |status:, error: nil|
  test = Verity::Test.new(
    fingerprint: "testsrec.rb:aaaaaaaaaaaaaaaa",
    description: "example",
    tags: [],
    timeout: nil,
    requires: [],
    resources: {},
    file: __FILE__,
    line: __LINE__,
    fn: -> {},
    group_path: [],
    inherited_group_tags: [], group_scopes: []
  )
  Verity::Runner::Result.new(test: test, status: status, error: error)
end

TR_SUMMARY = lambda do |total: 2, passed: 1, failed: 1|
  { total: total, passed: passed, failed: failed, errored: 0, skipped: 0, focus: false }
end

test "test reporter records run_start" do
  rep = Verity::Reporters::TestReporter.new
  rep.on_run_start(total: 5, worker_id: 0)
  assert_equal actual: rep.run_starts, expected: [{ total: 5, worker_id: 0 }]
end

test "test reporter records test_complete" do
  rep = Verity::Reporters::TestReporter.new
  rep.on_test_complete(result: TR_RESULT.call(status: :pass), worker_id: 0)
  assert_equal actual: rep.test_completes.size, expected: 1
  assert_equal actual: rep.test_completes.first[:status], expected: :pass
end

test "test reporter records run_finish" do
  rep = Verity::Reporters::TestReporter.new
  s = TR_SUMMARY.call
  rep.on_run_finish(summary: s, worker_id: 0)
  assert_equal actual: rep.run_finishes, expected: [{ summary: s, worker_id: 0 }]
end

test "test reporter records parallel_complete" do
  rep = Verity::Reporters::TestReporter.new
  rep.on_parallel_complete(counts: { "passed" => 1 }, problem_rows: [])
  assert_equal actual: rep.parallel_finishes.size, expected: 1
end
