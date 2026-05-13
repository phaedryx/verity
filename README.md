# Verity

Metadata-first Ruby tests: each case is a structured record (tags, timeouts, resource hints) backed by a SQLite manifest queue. Today the CLI loads discovery files, syncs them into the manifest, and runs tests sequentially for a single worker.

## Requirements

- Ruby **≥ 3.2**

## Installation

Add to your Gemfile:

```ruby
gem "verity"
```

Or install from the repository root:

```bash
gem build verity.gemspec && gem install verity-*.gem
```

## Running

From a checkout, after dependencies are available:

```bash
./bin/verity
# or
bundle exec verity
```

Exit status is **0** if every claimed test passes, **1** otherwise (`exit` in `bin/verity` mirrors that). **2** is used for invalid CLI options or an invalid `--reporter` / `-r` value.

```bash
verity --reporter dots
verity -w cpus
verity --workers 4
verity -r null
verity -r ./reporters/mine.rb:MyReporter
```

Built-in names are the same as for `Verity.build_reporter` (case-insensitive): `colored`, `colored_dots`, `documentation`, `doc`, `dots`, `null`, `none`, `silent`. Custom reporters: `path/to/file.rb:ClassName` (class must `include Verity::Reporter`); the file is `load`ed, then `ClassName.new` is called with no arguments.

`ColoredDotsReporter` (the default) prints green **.** / red **F** / yellow **E** when stdout is a TTY. Set `NO_COLOR` in the environment to disable; set `FORCE_COLOR` or `VERITY_FORCE_COLOR` to `1` to force color when not a TTY.

## Configuration

Use `Verity.configure` before `Verity.run` (or ensure defaults match your layout):

```ruby
Verity.configure do |c|
  c.manifest_path = ":memory:"              # default; use a path for a persistent SQLite file
  c.test_globs = ["verity/**/*_test.rb"]   # default; set to your Verity discovery globs
  # c.worker_count = 1                      # default; or :cpus / "cpus" for Etc.nprocessors workers
  # c.reporter = Verity::Reporters::ColoredDotsReporter.new($stdout)  # default
end
```

- **`test_globs`** — array of patterns passed to `Dir.glob`; merged and de-duplicated for **`test_files`**.
- **`manifest_path`** — SQLite database path, or `":memory:"` for an in-memory DB.
- **`worker_count`** — number of parallel worker processes (`Integer` or decimal string), or **`:cpus`** / **`:cpu`** / **`"cpus"`** / **`"cpu"`** to use `Etc.nprocessors` (minimum **1**). Resolved at run time via **`Configuration#resolved_worker_count`**. Parallel runs need a **file** manifest (not `":memory:"`) and **`Kernel#fork`**.
- **`reporter`** — object that includes `Verity::Reporter` (default: `Verity::Reporters::ColoredDotsReporter` on `$stdout`). See **Custom reporters** below.

`Verity.run(worker_id: 0)` loads all `test_files`, migrates the manifest, replaces the `tests` table from the registry, then runs the manifest-driven runner for that worker.

`Verity.load_discovery!` only clears the registry and loads `test_files` (useful if you build your own harness). For each file it precomputes **fingerprints** with **Prism**: the hash covers the **block body** only (description and metadata changes do not change identity). **`Test#file`** and **`Test#line`** remain the **`test` call** location. If you `load` a file outside that path (no plan installed), fingerprints fall back to a line-based slug.

### Custom reporters

Implement {Verity::Reporter} and assign it on configuration. `Verity.run` and `Runner.new` (no `reporter:` keyword) use `Verity.configuration.reporter`. Built-ins live under `Verity::Reporters` (`ColoredDotsReporter`, `CompositeReporter`, `DocumentationReporter`, `DotsReporter`, `NullReporter`, etc.).

```ruby
class MyReporter
  include Verity::Reporter

  def on_test_complete(result:, worker_id:)
    # See Verity::Runner::Result: :test, :status (:pass | :fail | :error), :error
  end

  def on_run_finish(summary:, worker_id:)
    # summary: :total, :passed, :failed, :errored, :skipped, :focus
  end

  # Optional: after Verity.run with worker_count > 1 (parent process only)
  def on_parallel_complete(counts:, problem_rows:)
  end
end

Verity.configure do |c|
  c.reporter = MyReporter.new
end
```

For a one-off run without changing global config, pass `Verity::Runner.new(reporter: MyReporter.new)`.

## Grouping

Nest tests under titled sections with **`group`**. Each `test` registers with a **`group_path`** (array of titles) used for output and tooling; fingerprints and execution order are unchanged.

```ruby
group "Authentication", tags: [:integration] do
  group "sessions", tags: [:focus] do
    test "creates a session" do
      # ...
    end
  end
end

group "WIP", tags: [:skip] do
  test "not scheduled yet" do
  end
end
```

Tags on a **`group`** apply to **every nested `test`** (and inner groups): they are stored on each test as **`inherited_group_tags`** (outer groups first) and merged with the test’s own **`tags:`** for **`Verity.skipped?`**, **`Verity.focus_tag?`**, and **`Verity.effective_tags`**. **`:skip`** on any ancestor (or on the test) skips the example; **`:focus`** follows the same suite-wide rules as test-level **`:focus`**.

**`Verity::Reporters::DocumentationReporter`** prints new group titles when the path changes (indented like an outline). Dot reporters do not show groups. Custom reporters can read **`result.test.group_path`** and **`result.test.inherited_group_tags`**.

The group stack is cleared before each discovery file is loaded so a stray unclosed `group` in one file does not affect the next.

## Tags

- **`tags: [:skip]`** — The example is **not** enqueued in the manifest and does **not** run. It still appears in **`Verity::Registry.all`**. The summary line includes **`N skipped`** when `N > 0`. String `"skip"` in tags is treated the same (normalized with `to_sym`). A **`group`** may use **`tags: [:skip]`**; that applies to all nested tests (see **Grouping**).
- **`tags: [:focus]`** — If **any** non-skipped registered test has **`:focus`** (including via an enclosing **`group`**), **only** tests that have **`:focus`** in their effective tags are runnable (manifest + direct **`Runner#run`**). If every non-skipped test is focused, the filter does nothing (same as “all focused”). **`Skip` wins:** a test with both **`skip`** and **`focus`** is skipped. When focus narrows the suite, the summary ends with **`(focus)`**.

## Repository layout (this project)

| Directory | Role |
|-----------|------|
| `test/` | Minitest for Verity internals |
| `spec/` | RSpec examples |
| `verity/` | Verity DSL files (default discovery glob targets `verity/**/*_test.rb`) |
| `lib/` | Gem implementation |

## Design notes

See [verity-notes.md](verity-notes.md) for schema, fingerprints, and planned execution model.

## License

MIT — see [LICENSE](LICENSE).
