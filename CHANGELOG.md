# Changelog

All notable changes to this project are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this project is
pre-1.0 and may make breaking changes between minor versions.

## [Unreleased]

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
