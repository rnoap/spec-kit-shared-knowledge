# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.2.0] - 2026-09-04

Pre-publication hardening release. Verified against `specify 1.0.4` with a real
`extension add --dev` install into a clean project.

### Fixed

- `fix(manifest)!: rename the config target to knowledge-config.yml` — spec-kit rejected `provides.config[].name: knowledge.yml` (`Warning: Config templates not scaffolded: knowledge.yml`), so no config file was ever created on install. `ExtensionManager._target_follows_preserved_convention` only accepts a top-level target ending in `-config.yml` / `-config.local.yml`; anything else is also `rmtree`d by `extension add --force` and by `extension remove --keep-config`, so the old name risked silently destroying a user's source list on reinstall. The project config file is now `.specify/extensions/knowledge/knowledge-config.yml`.
- `fix(manifest): drop the unsupported provides.config[].location key` — not part of the manifest schema; config is always deployed under `.specify/extensions/<id>/`. Replaced with the documented `description` field.
- `fix(packaging): exclude .github/ and .wibey/ from the installed copy` — `.extensionignore` did not cover this repo's own agent command surfaces, so `extension add` copied 110 files into the consumer's `.specify/extensions/knowledge/`, 86 of which were unrelated `speckit.*.agent.md` / `speckit.*.prompt.md` files belonging to other extensions. The installed copy is now 8 files.
- `fix(packaging): add .gitattributes export-ignore for dev-only trees` — the catalog `download_url` is the GitHub source archive, which is produced by `git archive`. Without this, every published archive shipped this repo's own `.specify/` workspace, including four vendored third-party extensions.
- `fix(commands): use agent-neutral __SPECKIT_COMMAND_*__ tokens` — command bodies hard-coded `/speckit-knowledge-sync`, which is correct for slash agents only and breaks on Codex/ZCode (`$speckit-knowledge-sync`), Kimi (`/skill:...`), and dot-separator agents. Spec Kit now renders the invocation per agent.
- `docs(readme): correct the dev-install invocation` — `specify extension add knowledge --dev <path>` fails on spec-kit ≥ 1.0 with `Got unexpected extra argument(s)`. The path is the positional argument: `specify extension add <path> --dev`.
- `docs: status badge now tracks the manifest version` (was pinned at v1.0.0 while the manifest was 1.1.0).

### Changed

- `extension.yml` `version` bumped from `1.1.0` to `1.2.0`.
- Constitution quality gate #1 now asserts a clean install *and* successful config scaffolding.

### Migration

If you installed 1.1.0 with `--dev` and already configured sources, rename the
file before upgrading:

```bash
mv .specify/extensions/knowledge/knowledge.yml \
   .specify/extensions/knowledge/knowledge-config.yml
```

## [1.1.0] - 2026-06-17

### Added

- `feat(sync): emit Context Output for AI Agents block by default; add --no-context-output flag` — `speckit.knowledge.sync` now appends a delimited block (70×`═` rules, four numbered directives) to stdout after every successful or degraded sync, instructing the AI agent to read `knowledge-index.md` and cache files and to cite borrowed information by `<source-label> › <relative-path>`. Pass `--no-context-output` to suppress the block (diagnostic use only).
- `docs(readme): remove obsolete manual hook registration and SKILL.md preamble steps; add migration note` — the "Integration with /speckit-specify and /speckit-plan" section now reflects the auto-registration reality; manual `.specify/extensions.yml` and SKILL.md instructions removed.
- `feat(configure): auto-update .gitignore with cache exclusion entries` — `speckit.knowledge.configure` now appends `.specify/extensions/knowledge/cache/` and `.specify/extensions/knowledge/knowledge-index.md` to the project `.gitignore` (idempotent; never blocks the workflow). Removes the only remaining manual installation step.
- `feat(config): support local-path sources and multi-folder path_filter` — a knowledge source `url` may now be a **local filesystem path** (absolute or `~`-prefixed) in addition to an HTTPS/SSH Git URL. `path_filter` accepts **zero, one, or multiple** folder tokens; multiple tokens are stored as a YAML list and passed to `git sparse-checkout` as separate patterns. Useful when the source repository is already cloned locally or lives on a private network not yet pushed.

### Fixed

- `fix(sync): use --no-cone sparse-checkout so path_filter is honored` — `git sparse-checkout init --cone` always includes root-level files (e.g. `package.json`, `Dockerfile`) regardless of the configured pattern. Switched to `--no-cone` mode with gitignore-style patterns; the warm path additionally re-applies the configuration and calls `git sparse-checkout reapply` to evict stray files left behind by caches originally cloned under the buggy configuration (self-healing — no user intervention required).

### Removed

- `scripts/install-local.sh` and the `scripts/` directory — superseded by `specify extension add --dev <path>` from the official Spec Kit CLI, which covers file copy, registry registration, and (uniquely) hook auto-registration. The local helper script duplicated three of those tasks, missed hook auto-registration, and shipped Claude-specific `SKILL.md` wrappers that became redundant after switching to the GitHub Copilot integration surface. Users now install with `specify extension add --dev /path/to/spec-kit-shared-knowledge`.
- `python3` from `extension.yml#requires.tools` — only the removed install script depended on it; the four agent-prompt commands have no Python dependency.

### Changed

- `extension.yml` `version` bumped from `1.0.0` to `1.1.0`.
- `.specify/memory/constitution.md` Principle I rewritten: install logic is no longer owned by `scripts/install-local.sh`; the spec-kit CLI is now the canonical install mechanism. Source-of-Truth hierarchy collapsed from 5 to 4 levels (script tier removed). Quality gate #1 updated to use `specify extension add --dev` for the pre-tag smoke test.
- README § "Local / Development Install" simplified to a single `specify extension add --dev` invocation.
- README § "Quick Start" and § "Commands" rewritten with four example variants (remote URL, local absolute path, local tilde path, multi-folder filter) and an expanded `/speckit-knowledge-configure` reference.
- `config-template.yml` rewritten with five commented examples covering every source-type and path_filter combination.

## [1.0.0] - 2026-06-11

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
[Unreleased]: https://github.com/rnoap/spec-kit-shared-knowledge/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/rnoap/spec-kit-shared-knowledge/releases/tag/v1.2.0
[1.1.0]: https://github.com/rnoap/spec-kit-shared-knowledge/releases/tag/v1.1.0
[1.0.0]: https://github.com/rnoap/spec-kit-shared-knowledge/releases/tag/v1.0.0
