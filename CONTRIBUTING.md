# Contributing

## Triple-suite tests (compare / convert / redundant verification)

Functional scenarios appear in parallel so readers can contrast styles:

| Verity DSL (dogfood) | Minitest | RSpec |
|----------------------|---------|-------|
| `verity/foo_test.rb` | `test/foo_test.rb` | `spec/verity/foo_spec.rb` |

Each Minitest file begins with a one-line banner pointing at its siblings. Scenario titles align on purpose (`rg` / side-by-side diffs).

**Important for dogfood:** `Verity.load_discovery!` clears `Verity::Registry`. Do **not** call it from bodies of files under `verity/**/*_test.rb` when running the aggregated `./bin/verity` suite—use subprocess scripts (like `verity/run_test.rb` and `verity/reporter_test.rb`) or cover that behavior under `test/` and `spec/` instead.

**Runner-focused** in-process coverage lives mainly in **Minitest** and **RSpec** (`spec/verity/runner_spec.rb`), plus SQLite scenarios in **`verity/runner_manifest_test.rb`**. There is intentionally no **`verity/runner_test.rb`** so aggregated dogfood does not wipe the Registry between queued manifest fingerprints.
