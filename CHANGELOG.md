# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `extension.yml` now declares `python3` as a required tool (used by `install-local.sh` for JSON registry update)
- `install-local.sh` auto-appends `.gitignore` entries for `cache/` and `knowledge-index.md` on install (idempotent; skips lines already present)

### Fixed
- `knowledge-index.md` HTML comment header now includes `schema_version=1.0` for forward-compatibility

## [1.0.0] - TBD

### Added

- `speckit.xrepo.configure` command — initialize or edit knowledge source configuration
- `speckit.xrepo.sync` command — fetch and cache all configured knowledge sources via git sparse-checkout with 10s per-source timeout; offline cache fallback with staleness reporting
- `speckit.xrepo.search` command — browse and search the knowledge corpus across all configured sources
- `speckit.xrepo.status` command — display reachability, last-sync timestamp, item count, and cache age per source
- File-based context injection via `knowledge-index.md` — automatically surfaced to `/speckit-specify` and `/speckit-plan` when `before_specify`/`before_plan` hooks are configured
- Path-based conflict detection — items with duplicate relative paths across sources are flagged with `⚠️ CONFLICT` and both versions included with source attribution
- Source-count soft warning when more than 10 sources are configured
- `--verbose` flag on all four commands

[Unreleased]: https://github.com/walmart-developer-experience/spec-kit-shared-knowledge/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/walmart-developer-experience/spec-kit-shared-knowledge/releases/tag/v1.0.0
