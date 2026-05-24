# Test Coverage Gap Closure — Minitest & RSpec

**Date:** 2026-05-23
**Scope:** Close all gaps between the canonical `verity/` dogfood suite and the Minitest (`test/`) and RSpec (`spec/`) mirror suites.

---

## Background

Verity maintains three parallel test suites:

- `verity/` — dogfood suite (runs via Verity itself; canonical source of truth)
- `test/` — Minitest mirrors (redundant proof against a standard harness)
- `spec/` — RSpec mirrors (redundant proof against a standard harness)

A recent branch added resource-conflict scheduling (`claim_next exclude:`, `running_resources`, `conflict_exclusion_list`, `run_manifest` deferral). The `verity/` suite was updated but the mirrors were not. A full audit also revealed four entire Minitest files and scattered individual tests missing from both mirror suites.

---

## Complete Gap Inventory

### Minitest — missing entire files

| File to create | Source | Tests |
|---|---|---|
| `test/documentation_reporter_test.rb` | `verity/documentation_reporter_test.rb` | 7 |
| `test/group_focus_test.rb` | `verity/group_focus_test.rb` | 1 |
| `test/null_reporter_test.rb` | `verity/null_reporter_test.rb` | 1 |
| `test/test_reporter_test.rb` | `verity/test_reporter_test.rb` | 4 |

### Minitest — individual tests missing from existing files

**`test/manifest_test.rb`** (add 4 tests):
- `test_claim_next_returns_nil_when_all_pending_tests_are_excluded`
- `test_claim_next_with_exclude_skips_the_listed_fingerprints`
- `test_running_resources_returns_resource_hashes_for_running_rows_only`
- `test_running_resources_returns_empty_when_no_rows_are_running`

**`test/runner_manifest_test.rb`** (add 5 tests + fix helper):
- `test_conflict_exclusion_list_returns_empty_when_no_resolvers_registered`
- `test_conflict_exclusion_list_returns_fingerprints_that_conflict_with_running_resources`
- `test_conflict_exclusion_list_normalizes_symbol_vs_string_values_before_comparing`
- `test_run_manifest_defers_conflicting_test_until_blocker_finishes`
- `test_run_manifest_records_timeout_as_errored`
- `passing_test` helper: add `resources: {}` keyword argument

### RSpec — individual tests missing from existing files

**`spec/verity/manifest_spec.rb`** (add 4 examples):
- Under `describe "#claim_next"`: `it "returns nil when all pending tests are excluded"`
- Under `describe "#claim_next"`: `it "skips excluded fingerprints"`
- New `describe "#running_resources"` block:
  - `it "returns resource hashes for running rows only"`
  - `it "returns empty when no rows are running"`

**`spec/verity/runner_spec.rb`** (add 4 examples):
- New `describe ".conflict_exclusion_list"` block on `Verity` (separate `RSpec.describe`):
  - `it "returns empty when no resolvers are registered"`
  - `it "returns fingerprints that conflict with running resources"`
  - `it "normalizes symbol vs string values before comparing"`
- Under `describe "#run_manifest"`: `it "defers conflicting test until blocker finishes"` (creates its own local manifest; closes it inline, consistent with the other `#run_manifest` specs)

### Infrastructure changes

- `test/verity_test_helper.rb`: add `Verity.resource_resolvers.clear` to `reset_verity_process_state!`
- `spec/spec_helper.rb`: add `Verity.resource_resolvers.clear` to the `before(:each)` block

---

## Implementation Approach

Sequential, file by file, reading the canonical `verity/` test as source of truth before writing each mirror. Order:

1. Infrastructure (`test_helper`, `spec_helper`)
2. `test/manifest_test.rb` additions
3. `test/runner_manifest_test.rb` additions
4. New `test/null_reporter_test.rb`
5. New `test/test_reporter_test.rb`
6. New `test/documentation_reporter_test.rb`
7. New `test/group_focus_test.rb`
8. `spec/verity/manifest_spec.rb` additions
9. `spec/verity/runner_spec.rb` additions

Each step: translate verity-DSL assertions to the target framework idiom, preserve test intent exactly.

---

## Conventions

### Minitest translation rules
- `assert_equal actual: x, expected: y` → `assert_equal y, x`
- `refute_includes item:, collection:` → `refute_includes collection, item`
- `assert_includes item:, collection:` → `assert_includes collection, item`
- `assert_match pattern:, actual:` → `assert_match pattern, actual`
- `refute x, message: "..."` → `refute x, "..."`
- `assert system(...)` → identical
- Resource-resolver tests: use `ensure Verity.resource_resolvers.clear` (belt-and-suspenders alongside helper reset)
- Thread/sleep tests: translate directly; Minitest has no thread restrictions

### RSpec translation rules
- Use `expect(...).to eq(...)` / `expect(...).to be_nil` / `expect(...).to be true`
- `manifest` provided via `let` with `after { manifest.close }`; inline manifests allowed for multi-manifest tests
- Resource-resolver tests: cleanup via `after { Verity.resource_resolvers.clear }` scoped to the describe block (spec_helper covers the global reset, but explicit cleanup is clearer)
- The new `conflict_exclusion_list` specs describe `Verity` (the module), not `Verity::Runner`; open a second `RSpec.describe Verity` block at the bottom of `runner_spec.rb`

---

## Success Criteria

- `bundle exec ruby -Ilib -Itest test/**/*_test.rb` runs green with no skipped tests
- `bundle exec rspec spec/` runs green with no pending examples
- Every test in the `verity/` suite has a counterpart in both `test/` and `spec/`
