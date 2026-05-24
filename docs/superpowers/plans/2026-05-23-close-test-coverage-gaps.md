# Close Test Coverage Gaps — Minitest & RSpec Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add all missing tests to `test/` (Minitest) and `spec/` (RSpec) so every test in the `verity/` dogfood suite has a counterpart in both mirror suites.

**Architecture:** Sequential file-by-file additions. Each task touches one file, writes the missing tests, runs them green, then commits. No production code changes.

**Tech Stack:** Ruby, Minitest (stdlib), RSpec 3, SQLite3, Verity (self-referential)

---

## File Map

| File | Action | What changes |
|---|---|---|
| `test/verity_test_helper.rb` | Modify | Add `Verity.resource_resolvers.clear` to `reset_verity_process_state!` |
| `spec/spec_helper.rb` | Modify | Add `Verity.resource_resolvers.clear` to `before(:each)` |
| `test/manifest_test.rb` | Modify | Add 4 tests: `claim_next exclude:`, `running_resources` ×2 |
| `test/runner_manifest_test.rb` | Modify | Add `resources:` to `passing_test` helper; add 5 tests |
| `test/null_reporter_test.rb` | Create | 1 test: NullReporter hooks don't raise |
| `test/test_reporter_test.rb` | Create | 4 tests: TestReporter recording |
| `test/documentation_reporter_test.rb` | Create | 7 tests: DocumentationReporter output |
| `test/group_focus_test.rb` | Create | 1 test: subprocess group-focus narrowing |
| `spec/verity/manifest_spec.rb` | Modify | Add 4 examples: `#claim_next exclude:`, `#running_resources` ×2 |
| `spec/verity/runner_spec.rb` | Modify | Add 4 examples: `.conflict_exclusion_list` ×3, `#run_manifest` defer |

---

### Task 1: Update test helpers to clear resource_resolvers

**Files:**
- Modify: `test/verity_test_helper.rb`
- Modify: `spec/spec_helper.rb`

- [ ] **Step 1: Add resource_resolvers cleanup to Minitest helper**

In `test/verity_test_helper.rb`, update `reset_verity_process_state!`:

```ruby
def reset_verity_process_state!
  Verity.reset_configuration!
  Verity::Registry.clear
  Verity.hooks.each_value(&:clear)
  Verity.resource_resolvers.clear
  Verity.configure { |c| c.test_order = :fingerprint }
end
```

- [ ] **Step 2: Add resource_resolvers cleanup to RSpec before hook**

In `spec/spec_helper.rb`, update the `before(:each)` block:

```ruby
RSpec.configure do |config|
  config.include ReporterSpecHelpers
  config.before(:each) do
    Verity::Registry.clear
    Verity.reset_configuration!
    Verity.clear_group_stack!
    Verity.hooks.each_value(&:clear)
    Verity.resource_resolvers.clear
  end
end
```

- [ ] **Step 3: Run the full suite to confirm nothing broke**

```bash
ruby -Ilib:test test/runner_manifest_test.rb
bundle exec rspec spec/verity/runner_spec.rb
```

Expected: all tests pass (no new failures).

- [ ] **Step 4: Commit**

```bash
git add test/verity_test_helper.rb spec/spec_helper.rb
git commit -m "test: clear resource_resolvers in Minitest and RSpec setup helpers"
```

---

### Task 2: Add claim_next exclude + running_resources to Minitest manifest test

**Files:**
- Modify: `test/manifest_test.rb` (add 4 tests before the `private` line)

- [ ] **Step 1: Add the four new tests**

Insert the following before the `private` keyword in `test/manifest_test.rb`:

```ruby
  def test_claim_next_returns_nil_when_all_pending_tests_are_excluded
    manifest = open_memory_manifest
    lone = make_test(fingerprint: "a.rb:1111111111111111")
    manifest.replace_tests([lone])

    begin
      claimed = manifest.claim_next(1, exclude: [lone.fingerprint])
      assert_nil claimed
    ensure
      manifest.close
    end
  end

  def test_claim_next_with_exclude_skips_the_listed_fingerprints
    manifest = open_memory_manifest
    first = make_test(fingerprint: "a.rb:1111111111111111")
    second = make_test(fingerprint: "b.rb:2222222222222222")
    manifest.replace_tests([first, second])

    begin
      claimed = manifest.claim_next(1, exclude: [first.fingerprint])
      assert_equal second.fingerprint, claimed.fingerprint
    ensure
      manifest.close
    end
  end

  def test_running_resources_returns_resource_hashes_for_running_rows_only
    manifest = open_memory_manifest
    running = make_test(fingerprint: "r.rb:1111111111111111", resources: { tables: [:users, :posts] })
    pending = make_test(fingerprint: "p.rb:2222222222222222", resources: { tables: [:orders] })
    manifest.replace_tests([running, pending])
    manifest.claim_next(1)

    begin
      assert_equal [{ "tables" => ["users", "posts"] }], manifest.running_resources
    ensure
      manifest.close
    end
  end

  def test_running_resources_returns_empty_when_no_rows_are_running
    manifest = open_memory_manifest

    begin
      assert_equal [], manifest.running_resources
    ensure
      manifest.close
    end
  end
```

- [ ] **Step 2: Run to verify all pass**

```bash
ruby -Ilib:test test/manifest_test.rb
```

Expected: all tests pass, no failures.

- [ ] **Step 3: Commit**

```bash
git add test/manifest_test.rb
git commit -m "test: add claim_next exclude and running_resources Minitest coverage"
```

---

### Task 3: Add conflict_exclusion_list + deferred + timeout to Minitest runner test

**Files:**
- Modify: `test/runner_manifest_test.rb`

- [ ] **Step 1: Update passing_test helper to accept resources keyword**

In `test/runner_manifest_test.rb`, update the `passing_test` private helper:

```ruby
  def passing_test(fingerprint: "ok.rb:aaaaaaaaaaaaaaaa", description: "passes", resources: {})
    Verity::Test.new(
      fingerprint:,
      description:,
      tags: [],
      timeout: nil,
      requires: [],
      resources:,
      file: "ok.rb",
      line: 1,
      fn: -> {},
      group_path: [],
      inherited_group_tags: [], group_scopes: []
    )
  end
```

- [ ] **Step 2: Add the five new tests**

Insert the following before the `private` keyword in `test/runner_manifest_test.rb`:

```ruby
  def test_conflict_exclusion_list_returns_empty_when_no_resolvers_registered
    reset_verity_process_state!
    t = passing_test(fingerprint: "cx.rb:aaaaaaaaaaaaaaaa", resources: { tables: [:users] })
    result = Verity.conflict_exclusion_list([{ "tables" => ["users"] }], tests: [t])
    assert_equal [], result
  end

  def test_conflict_exclusion_list_returns_fingerprints_that_conflict_with_running_resources
    reset_verity_process_state!
    Verity.register_resource :tables, conflicts_with: ->(mine, theirs) { (mine & theirs).any? }
    conflicting = passing_test(fingerprint: "cx.rb:1111111111111111", resources: { tables: [:users] })
    safe        = passing_test(fingerprint: "cx.rb:2222222222222222", resources: { tables: [:posts] })
    none        = passing_test(fingerprint: "cx.rb:3333333333333333", resources: {})
    running     = [{ "tables" => ["users"] }]

    begin
      result = Verity.conflict_exclusion_list(running, tests: [conflicting, safe, none])
      assert_equal [conflicting.fingerprint], result
    ensure
      Verity.resource_resolvers.clear
    end
  end

  def test_conflict_exclusion_list_normalizes_symbol_vs_string_values_before_comparing
    reset_verity_process_state!
    Verity.register_resource :tables, conflicts_with: ->(mine, theirs) { (mine & theirs).any? }
    t       = passing_test(fingerprint: "cx.rb:4444444444444444", resources: { tables: [:users] })
    running = [{ "tables" => ["users"] }]

    begin
      result = Verity.conflict_exclusion_list(running, tests: [t])
      assert_equal [t.fingerprint], result
    ensure
      Verity.resource_resolvers.clear
    end
  end

  def test_run_manifest_defers_conflicting_test_until_blocker_finishes
    reset_verity_process_state!
    ran_while_blocked = false
    manifest   = open_memory_manifest
    runner     = Verity::Runner.new(reporter: Verity::Reporters::NullReporter.new)
    blocker_fp = "blk.rb:1111111111111111"
    deferred   = Verity::Test.new(
      fingerprint: "def.rb:2222222222222222", description: "deferred",
      tags: [], timeout: nil, requires: [], resources: { tables: [:users] },
      file: "def.rb", line: 1,
      fn: -> {
        ran_while_blocked = manifest.db.get_first_value(
          "SELECT status FROM tests WHERE fingerprint = ?", blocker_fp
        ) == "running"
      },
      group_path: [], inherited_group_tags: [], group_scopes: []
    )
    blocker = passing_test(fingerprint: blocker_fp, resources: { tables: [:users] })
    manifest.replace_tests([blocker, deferred])
    manifest.claim_next(99)
    Verity::Registry.register(deferred)
    Verity.register_resource :tables, conflicts_with: ->(mine, theirs) { (mine & theirs).any? }
    release = Thread.new { sleep 0.1; manifest.record_pass(blocker_fp) }

    begin
      result = runner.run_manifest(manifest, worker_id: 1)
      release.join
      assert result
      refute ran_while_blocked, "deferred test ran while blocker was still in running status"
    ensure
      cleanup_verity_and_close(manifest)
    end
  end

  def test_run_manifest_records_timeout_as_errored
    reset_verity_process_state!
    manifest = open_memory_manifest
    runner   = Verity::Runner.new(reporter: Verity::Reporters::NullReporter.new)
    slow     = Verity::Test.new(
      fingerprint: "timeoutm.rb:eeeeeeeeeeeeeeee",
      description: "manifest_timeout",
      tags: [], timeout: 0.05, requires: [], resources: {},
      file: "slow.rb", line: 1,
      fn: -> { sleep 0.5 },
      group_path: [], inherited_group_tags: [], group_scopes: []
    )
    Verity::Registry.register(slow)
    manifest.replace_tests([slow])

    begin
      refute runner.run_manifest(manifest, worker_id: 0)
      assert_equal 1, manifest.count_by_status["errored"]
    ensure
      cleanup_verity_and_close(manifest)
    end
  end
```

- [ ] **Step 3: Run to verify all pass**

```bash
ruby -Ilib:test test/runner_manifest_test.rb
```

Expected: all tests pass.

- [ ] **Step 4: Commit**

```bash
git add test/runner_manifest_test.rb
git commit -m "test: add conflict_exclusion_list, deferred, and timeout Minitest coverage"
```

---

### Task 4: Create test/null_reporter_test.rb

**Files:**
- Create: `test/null_reporter_test.rb`

- [ ] **Step 1: Write the file**

```ruby
# frozen_string_literal: true

# Triple suite (compare / redundant proof): verity/null_reporter_test.rb · spec/verity/null_reporter_spec.rb

require "minitest/autorun"
require_relative "../lib/verity"

class NullReporterTest < Minitest::Test
  def make_result(status: :pass)
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

  def test_null_reporter_invokes_hooks_without_raising
    rep     = Verity::Reporters::NullReporter.new
    summary = { total: 1, passed: 1, failed: 0, errored: 0, skipped: 0, focus: false }

    rep.on_run_start(total: 1, worker_id: 0)
    rep.on_test_complete(result: make_result(status: :pass), worker_id: 0)
    rep.on_run_finish(summary: summary, worker_id: 0)
    rep.on_parallel_complete(counts: {}, problem_rows: [])
    assert true
  end
end
```

- [ ] **Step 2: Run to verify it passes**

```bash
ruby -Ilib:test test/null_reporter_test.rb
```

Expected: 1 test, 0 failures.

- [ ] **Step 3: Commit**

```bash
git add test/null_reporter_test.rb
git commit -m "test: add NullReporter Minitest coverage"
```

---

### Task 5: Create test/test_reporter_test.rb

**Files:**
- Create: `test/test_reporter_test.rb`

- [ ] **Step 1: Write the file**

```ruby
# frozen_string_literal: true

# Triple suite (compare / redundant proof): verity/test_reporter_test.rb · spec/verity/test_reporter_spec.rb

require "minitest/autorun"
require_relative "../lib/verity"

class TestReporterTest < Minitest::Test
  def make_result(status:, error: nil)
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

  def make_summary(total: 2, passed: 1, failed: 1)
    { total: total, passed: passed, failed: failed, errored: 0, skipped: 0, focus: false }
  end

  def test_records_run_start
    rep = Verity::Reporters::TestReporter.new
    rep.on_run_start(total: 5, worker_id: 0)
    assert_equal [{ total: 5, worker_id: 0 }], rep.run_starts
  end

  def test_records_test_complete
    rep = Verity::Reporters::TestReporter.new
    rep.on_test_complete(result: make_result(status: :pass), worker_id: 0)
    assert_equal 1, rep.test_completes.size
    assert_equal :pass, rep.test_completes.first[:status]
  end

  def test_records_run_finish
    rep = Verity::Reporters::TestReporter.new
    s = make_summary
    rep.on_run_finish(summary: s, worker_id: 0)
    assert_equal [{ summary: s, worker_id: 0 }], rep.run_finishes
  end

  def test_records_parallel_complete
    rep = Verity::Reporters::TestReporter.new
    rep.on_parallel_complete(counts: { "passed" => 1 }, problem_rows: [])
    assert_equal 1, rep.parallel_finishes.size
  end
end
```

- [ ] **Step 2: Run to verify all pass**

```bash
ruby -Ilib:test test/test_reporter_test.rb
```

Expected: 4 tests, 0 failures.

- [ ] **Step 3: Commit**

```bash
git add test/test_reporter_test.rb
git commit -m "test: add TestReporter Minitest coverage"
```

---

### Task 6: Create test/documentation_reporter_test.rb

**Files:**
- Create: `test/documentation_reporter_test.rb`

- [ ] **Step 1: Write the file**

```ruby
# frozen_string_literal: true

# Triple suite (compare / redundant proof): verity/documentation_reporter_test.rb · spec/verity/documentation_reporter_spec.rb

require "minitest/autorun"
require "stringio"
require_relative "../lib/verity"

class DocumentationReporterTest < Minitest::Test
  def make_result(status:, description: "example", error: nil, group_path: [])
    test = Verity::Test.new(
      fingerprint: "docspec.rb:aaaaaaaaaaaaaaaa",
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

  def make_summary(total: 2, passed: 1, failed: 1, errored: 0)
    { total: total, passed: passed, failed: failed, errored: errored, skipped: 0, focus: false }
  end

  def test_prints_run_header_with_count
    io = StringIO.new
    rep = Verity::Reporters::DocumentationReporter.new(io, color: false)
    rep.on_run_start(total: 5, worker_id: 0)
    assert_match(/Running 5 tests/, io.string)
  end

  def test_prints_pass_lines
    io = StringIO.new
    rep = Verity::Reporters::DocumentationReporter.new(io, color: false)
    rep.on_test_complete(result: make_result(status: :pass, description: "works"), worker_id: 0)
    assert_match(/pass/, io.string)
    assert_match(/works/, io.string)
  end

  def test_prints_fail_with_message
    io = StringIO.new
    rep = Verity::Reporters::DocumentationReporter.new(io, color: false)
    err = Verity::AssertionError.new("nope")
    rep.on_test_complete(
      result: make_result(status: :fail, description: "breaks", error: err),
      worker_id: 0
    )
    assert_match(/FAIL/, io.string)
    assert_match(/breaks/, io.string)
    assert_match(/nope/, io.string)
  end

  def test_prints_skip_lines
    io = StringIO.new
    rep = Verity::Reporters::DocumentationReporter.new(io, color: false)
    rep.on_test_complete(
      result: make_result(status: :skip, description: "skipped one"),
      worker_id: 0
    )
    assert_match(/skip/, io.string)
    assert_match(/skipped one/, io.string)
  end

  def test_prints_error_lines
    io = StringIO.new
    rep = Verity::Reporters::DocumentationReporter.new(io, color: false)
    err = RuntimeError.new("boom")
    rep.on_test_complete(
      result: make_result(status: :error, description: "explodes", error: err),
      worker_id: 0
    )
    assert_match(/ERROR/, io.string)
    assert_match(/RuntimeError/, io.string)
  end

  def test_emits_group_headers_for_nested_path
    io = StringIO.new
    rep = Verity::Reporters::DocumentationReporter.new(io, color: false)
    rep.on_test_complete(
      result: make_result(status: :pass, description: "inner", group_path: %w[Outer Inner]),
      worker_id: 0
    )
    assert_match(/Outer/, io.string)
    assert_match(/Inner/, io.string)
  end

  def test_prints_summary_on_run_finish
    io = StringIO.new
    rep = Verity::Reporters::DocumentationReporter.new(io, color: false)
    rep.on_run_finish(summary: make_summary(total: 3, passed: 2, failed: 1, errored: 0), worker_id: 0)
    assert_match(/3 tests/, io.string)
    assert_match(/2 passed/, io.string)
  end
end
```

- [ ] **Step 2: Run to verify all pass**

```bash
ruby -Ilib:test test/documentation_reporter_test.rb
```

Expected: 7 tests, 0 failures.

- [ ] **Step 3: Commit**

```bash
git add test/documentation_reporter_test.rb
git commit -m "test: add DocumentationReporter Minitest coverage"
```

---

### Task 7: Create test/group_focus_test.rb

**Files:**
- Create: `test/group_focus_test.rb`

- [ ] **Step 1: Write the file**

```ruby
# frozen_string_literal: true

# Triple suite (compare / redundant proof): verity/group_focus_test.rb · spec/verity/group_focus_spec.rb
# Runs in subprocess so :focus in this scenario never narrows the rest of Minitest CI.

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "rbconfig"

class GroupFocusTest < Minitest::Test
  def test_group_focus_narrows_runnable_list
    lib = File.expand_path("../lib", __dir__)
    Dir.mktmpdir do |tmp|
      verity_dir = File.join(tmp, "verity")
      FileUtils.mkdir_p(verity_dir)
      File.write(File.join(verity_dir, "only_test.rb"), <<~RUBY)
        group "Focused block", tags: [:focus] do
          test "inside" do
            assert true
          end
        end
        test "outside" do
          assert true
        end
      RUBY

      script = <<~RUBY
        require "verity"
        Dir.chdir(#{tmp.inspect}) do
          Verity.reset_configuration!
          Verity.configure do |c|
            c.test_globs = ["verity/**/*_test.rb"]
            c.manifest_path = ":memory:"
            c.reporter = Verity::Reporters::NullReporter.new
            c.worker_count = 1
          end
          Verity.load_discovery!
          names = Verity.runnable_tests.map(&:description).sort
          without_skip = Verity::Registry.all.reject { Verity.skipped?(_1) }
          unless names == ["inside"] && Verity.focus_filter_active?(without_skip)
            warn names.inspect
            exit 1
          end
        end
      RUBY

      assert system(RbConfig.ruby, "-I#{lib}", "-e", script, out: File::NULL, err: File::NULL)
    end
  end
end
```

- [ ] **Step 2: Run to verify it passes**

```bash
ruby -Ilib:test test/group_focus_test.rb
```

Expected: 1 test, 0 failures.

- [ ] **Step 3: Commit**

```bash
git add test/group_focus_test.rb
git commit -m "test: add group focus Minitest coverage"
```

---

### Task 8: Add claim_next exclude + running_resources to RSpec manifest spec

**Files:**
- Modify: `spec/verity/manifest_spec.rb`

- [ ] **Step 1: Add two cases inside the existing `describe "#claim_next"` block**

After the existing `it "claims tests one at a time"` example (around line 90), add:

```ruby
    it "returns nil when all pending tests are excluded" do
      t = make_test("excluded", fingerprint: "exc:abcdef0123456789")
      manifest.replace_tests([t])

      expect(manifest.claim_next(1, exclude: [t.fingerprint])).to be_nil
    end

    it "skips excluded fingerprints" do
      t1 = make_test("first",  fingerprint: "aaa:abcdef0123456789")
      t2 = make_test("second", fingerprint: "bbb:abcdef0123456789")
      manifest.replace_tests([t1, t2])

      claimed = manifest.claim_next(1, exclude: [t1.fingerprint])
      expect(claimed.fingerprint).to eq(t2.fingerprint)
    end
```

- [ ] **Step 2: Add a new `describe "#running_resources"` block**

After the closing `end` of `describe "#reclaim_abandoned_running!"` (around line 230), add:

```ruby
  describe "#running_resources" do
    before { manifest.migrate! }

    it "returns resource hashes for running rows only" do
      t1 = make_test("running", fingerprint: "aaa:abcdef0123456789")
      t2 = make_test("pending", fingerprint: "bbb:abcdef0123456789")
      manifest.replace_tests([t1, t2])
      manifest.claim_next(1)

      expect(manifest.running_resources).to eq([{ "cpu" => 1 }])
    end

    it "returns empty when no rows are running" do
      expect(manifest.running_resources).to eq([])
    end
  end
```

Note: `make_test` in this spec sets `resources: { cpu: 1 }`, so the running row produces `[{ "cpu" => 1 }]` after JSON round-trip.

- [ ] **Step 3: Run to verify all pass**

```bash
bundle exec rspec spec/verity/manifest_spec.rb
```

Expected: all examples pass.

- [ ] **Step 4: Commit**

```bash
git add spec/verity/manifest_spec.rb
git commit -m "test: add claim_next exclude and running_resources RSpec coverage"
```

---

### Task 9: Add conflict_exclusion_list + deferred test to RSpec runner spec

**Files:**
- Modify: `spec/verity/runner_spec.rb`

- [ ] **Step 1: Add the deferred-test case inside the existing `describe "#run_manifest"` block**

After the existing `it "records timeouts as errored in the manifest"` example (around line 243), add:

```ruby
    it "defers conflicting test until blocker finishes" do
      runner     = Verity::Runner.new(reporter: Verity::Reporters::NullReporter.new)
      blocker_fp = "blk:abcdef0123456789"
      ran_while_blocked = false

      manifest = Verity::Manifest.open(":memory:")
      manifest.migrate!

      deferred = Verity::Test.new(
        fingerprint: "def:abcdef0123456789", description: "deferred",
        tags: [], timeout: nil, requires: [], resources: { tables: [:users] },
        file: __FILE__, line: __LINE__,
        fn: -> {
          ran_while_blocked = manifest.db.get_first_value(
            "SELECT status FROM tests WHERE fingerprint = ?", blocker_fp
          ) == "running"
        },
        group_path: [], inherited_group_tags: [], group_scopes: []
      )
      blocker = Verity::Test.new(
        fingerprint: blocker_fp, description: "blocker",
        tags: [], timeout: nil, requires: [], resources: { tables: [:users] },
        file: __FILE__, line: __LINE__, fn: -> {},
        group_path: [], inherited_group_tags: [], group_scopes: []
      )

      manifest.replace_tests([blocker, deferred])
      manifest.claim_next(99)
      register(deferred)
      Verity.register_resource :tables, conflicts_with: ->(mine, theirs) { (mine & theirs).any? }
      release = Thread.new { sleep 0.1; manifest.record_pass(blocker_fp) }

      result = runner.run_manifest(manifest, worker_id: 1)
      release.join
      manifest.close

      expect(result).to be true
      expect(ran_while_blocked).to be false
    end
```

- [ ] **Step 2: Add a new `RSpec.describe Verity` block at the bottom of the file**

After the final `end` of the existing `RSpec.describe Verity::Runner` block, append:

```ruby
RSpec.describe Verity do
  def make_passing_test(fingerprint:, resources: {})
    Verity::Test.new(
      fingerprint: fingerprint,
      description: "passes",
      tags: [],
      timeout: nil,
      requires: [],
      resources: resources,
      file: __FILE__,
      line: __LINE__,
      fn: -> {},
      group_path: [],
      inherited_group_tags: [], group_scopes: []
    )
  end

  describe ".conflict_exclusion_list" do
    it "returns empty when no resolvers are registered" do
      t = make_passing_test(fingerprint: "cx:abcdef0123456789", resources: { tables: [:users] })
      result = Verity.conflict_exclusion_list([{ "tables" => ["users"] }], tests: [t])
      expect(result).to eq([])
    end

    it "returns fingerprints that conflict with running resources" do
      Verity.register_resource :tables, conflicts_with: ->(mine, theirs) { (mine & theirs).any? }
      conflicting = make_passing_test(fingerprint: "cx1:abcdef0123456789", resources: { tables: [:users] })
      safe        = make_passing_test(fingerprint: "cx2:abcdef0123456789", resources: { tables: [:posts] })
      none        = make_passing_test(fingerprint: "cx3:abcdef0123456789", resources: {})
      running     = [{ "tables" => ["users"] }]

      result = Verity.conflict_exclusion_list(running, tests: [conflicting, safe, none])
      expect(result).to eq([conflicting.fingerprint])
    end

    it "normalizes symbol vs string resource values before comparing" do
      Verity.register_resource :tables, conflicts_with: ->(mine, theirs) { (mine & theirs).any? }
      t       = make_passing_test(fingerprint: "cx4:abcdef0123456789", resources: { tables: [:users] })
      running = [{ "tables" => ["users"] }]

      result = Verity.conflict_exclusion_list(running, tests: [t])
      expect(result).to eq([t.fingerprint])
    end
  end
end
```

- [ ] **Step 3: Run to verify all pass**

```bash
bundle exec rspec spec/verity/runner_spec.rb
```

Expected: all examples pass.

- [ ] **Step 4: Commit**

```bash
git add spec/verity/runner_spec.rb
git commit -m "test: add conflict_exclusion_list and deferred-test RSpec coverage"
```

---

### Task 10: Final verification

- [ ] **Step 1: Run the full triple suite**

```bash
bin/test_all
```

Expected output:
```
======================================================
1/3 Dogfood — bin/verity (verity/**/*_test.rb)
======================================================
... all pass

======================================================
2/3 Minitest — test/**/*_test.rb
======================================================
... all pass

======================================================
3/3 RSpec — spec/
======================================================
... all pass

test_all: all suites passed
```

- [ ] **Step 2: Confirm test counts increased correctly**

Minitest should now include the four previously missing files and the new individual tests. RSpec should show the new examples under `manifest_spec` and `runner_spec`. Zero pending, zero failures.
