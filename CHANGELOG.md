# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - TBD

### Added

- `speckit.knowledge.configure` command — initialize or edit knowledge source configuration
- `speckit.knowledge.sync` command — fetch and cache all configured knowledge sources via git sparse-checkout with 10s per-source timeout; offline cache fallback with staleness reporting
- `speckit.knowledge.search` command — browse and search the knowledge corpus across all configured sources
- `speckit.knowledge.status` command — display reachability, last-sync timestamp, item count, and cache age per source
- File-based context injection via `knowledge-index.md` — automatically surfaced to `/speckit-specify` and `/speckit-plan` when `before_specify`/`before_plan` hooks are configured
- Path-based conflict detection — items with duplicate relative paths across sources are flagged with `⚠️ CONFLICT` and both versions included with source attribution
- Source-count soft warning when more than 10 sources are configured
- `--verbose` flag on all four commands
- `extension.yml` declares `python3` as a required tool (used by `install-local.sh` for JSON registry update)
- `install-local.sh` auto-appends `.gitignore` entries for `cache/` and `knowledge-index.md` on install (idempotent; skips lines already present)
- `knowledge-index.md` HTML comment header includes `schema_version=1.0` for forward-compatibility
- `.extensionignore` excludes dev artifacts (`specs/`, `AGENTS.md`, `scripts/`, etc.) from installed copy

### Naming

- Extension id finalized as `knowledge` (matches the `^speckit\.{ext-id}\.{command}$` validation rule in the Spec Kit Extension Development Guide)
- Display name set to **Shared Knowledge** in `extension.yml`
- Repository name preserved as `spec-kit-shared-knowledge`
- All commands, install paths (`.specify/extensions/knowledge/`), config file (`knowledge.yml`), and `.claude/skills/speckit-knowledge-*/SKILL.md` wrappers aligned with the final id

<!-- Update these links after publishing the repository -->
[Unreleased]: https://github.com/rnoap/spec-kit-shared-knowledge/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/rnoap/spec-kit-shared-knowledge/releases/tag/v1.0.0
