# Changelog

All notable changes to this project are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this project is
pre-1.0 and may make breaking changes between minor versions.

## [Unreleased]

### Added

- **`Verity::Rails`** (`require "verity/rails"`) — optional Rails adapter for
  day-to-day app testing: transactional test hooks, ActiveRecord reconnect after
  fork, per-worker `TEST_ENV_NUMBER` setup, YAML fixture accessors (`users(:one)`),
  `integration_session` for request specs, and mixing in
  `ActiveSupport::Testing::TimeHelpers`, `ActiveJob::TestHelper`, and
  `ActionMailer::TestHelper` when present. See `examples/rails/` and README.
- **`Verity::Railtie`** — auto-loaded in Rails apps; defines `rake verity` /
  `rake verity:run` (pass options after `--`).
- **`rails generate verity:install`** — scaffolds `test/verity_helper.rb`,
  `bin/verity`, and `test/verity/sample_test.rb`.
- **`Verity::CLI`** — shared option parsing for `bin/verity` and the rake task.
- `before_worker_start` hooks receive the worker id when invoked from the
  manifest runner.
- Tag-based narrowing via `Verity.configure` `included_tags` / `excluded_tags`
  (group-inherited labels included through `Verity.effective_tags`). New CLI
  flags `--tag` / `-t` and `--exclude-tag` are repeatable; inclusion is OR
  across the list and exclusion wins when a tag appears in both. Summaries
  append `(tags)` when a tag filter is active; the `on_run_finish` summary
  hash gains `:tag_filter`.

### Changed (breaking)

- `skip` and `focus` are now explicit keyword arguments on `test` and `group`
  (`test "x", skip: true`, `group "G", focus: true`) instead of magic tags.
  `tags: [:skip]` / `tags: [:focus]` no longer skip or focus — `tags:` is now
  purely descriptive (labels for filtering/CI), with no reserved behavior.
- `Verity.focus_tag?` is renamed to `Verity.focused?`.
- `Verity.effective_tags` now returns the descriptive tag union only and no
  longer determines skip/focus.
- `Verity::Test` gains `skip` and `focus` fields (effective booleans: the test's
  own value OR'd with any enclosing group).

### Migration

Replace `tags: [:skip]` with `skip: true` and `tags: [:focus]` with
`focus: true` on `test` and `group`. Group-level `skip:`/`focus:` cascade to all
nested tests, as the tags did before. "Skip wins over focus" is unchanged.
