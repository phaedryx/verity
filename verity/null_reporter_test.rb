# frozen_string_literal: true

# Triple suite: test/null_reporter_test.rb · spec/verity/null_reporter_spec.rb

NR_RESULT = lambda do |status: :pass|
  test = Verity::Test.new(
    fingerprint: "nullspec.rb:aaaaaaaaaaaaaaaa",
    description: "ex",
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
  Verity::Runner::Result.new(test: test, status: status, error: nil)
end

NR_SUMMARY = { total: 1, passed: 1, failed: 0, errored: 0, skipped: 0, focus: false }.freeze

test "null reporter invokes hooks without raising" do
  rep = Verity::Reporters::NullReporter.new

  rep.on_run_start(total: 1, worker_id: 0)
  rep.on_test_complete(result: NR_RESULT.call(status: :pass), worker_id: 0)
  rep.on_run_finish(summary: NR_SUMMARY.merge({}), worker_id: 0)
  rep.on_parallel_complete(counts: {}, problem_rows: [])
  assert true
end
