# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.0] - TBD

### Added

- `feat(sync): emit Context Output for AI Agents block by default; add --no-context-output flag` — `speckit.knowledge.sync` now appends a delimited block (70×`═` rules, four numbered directives) to stdout after every successful or degraded sync, instructing the AI agent to read `knowledge-index.md` and cache files and to cite borrowed information by `<source-label> › <relative-path>`. Pass `--no-context-output` to suppress the block (diagnostic use only).
- `docs(readme): remove obsolete manual hook registration and SKILL.md preamble steps; add migration note` — the "Integration with /speckit-specify and /speckit-plan" section now reflects the auto-registration reality; manual `.specify/extensions.yml` and SKILL.md instructions removed.

### Removed

- `scripts/install-local.sh` and the `scripts/` directory — superseded by `specify extension add --dev <path>` from the official Spec Kit CLI, which covers file copy, registry registration, and (uniquely) hook auto-registration. The local helper script duplicated three of those tasks, missed hook auto-registration, and shipped Claude-specific `SKILL.md` wrappers that became redundant after switching to the GitHub Copilot integration surface. Users now install with `specify extension add knowledge --dev /path/to/spec-kit-shared-knowledge` and add the two `cache/` + `knowledge-index.md` lines to their project `.gitignore` manually (documented in README).
- `python3` from `extension.yml#requires.tools` — only the removed install script depended on it; the four agent-prompt commands have no Python dependency.

### Changed

- `extension.yml` `version` bumped from `1.0.0` to `1.1.0`.
- `.specify/memory/constitution.md` Principle I rewritten: install logic is no longer owned by `scripts/install-local.sh`; the spec-kit CLI is now the canonical install mechanism. Source-of-Truth hierarchy collapsed from 5 to 4 levels (script tier removed). Quality gate #1 updated to use `specify extension add --dev` for the pre-tag smoke test.
- README § "Local / Development Install" simplified to a single `specify extension add --dev` invocation plus a 2-line `.gitignore` snippet.

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
