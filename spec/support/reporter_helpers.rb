# frozen_string_literal: true

# Shared factories for reporter specs — triple-suite counterparts live under verity/*_test.rb.
module ReporterSpecHelpers
  def reporter_result(status:, description: "example", error: nil, group_path: [])
    test = Verity::Test.new(
      fingerprint: "fp_spec:aaaaaaaaaaaaaaaa",
      description: description,
      tags: [],
      timeout: nil,
      requires: [],
      resources: {},
      file: __FILE__,
      line: __LINE__,
      fn: -> {},
      group_path: group_path,
      inherited_group_tags: [], group_scopes: []
    )
    Verity::Runner::Result.new(test: test, status: status, error: error)
  end

  def reporter_summary(total: 2, passed: 1, failed: 1, errored: 0, skipped: 0, focus: false)
    { total: total, passed: passed, failed: failed, errored: errored, skipped: skipped, focus: focus }
  end
end
