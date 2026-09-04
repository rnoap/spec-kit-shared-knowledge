# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.5.0] - 2026-09-04

A ceiling on how much the agent is told to read, and a written trust model for the
committed configuration. Two views of one concern: what an uncontrolled corpus does
to the agent, and what an uncontrolled configuration grants to whoever edits it.

### Added

- `feat(config): context budget` — optional `max_items` and `max_bytes`, project-wide and settable per source. When the corpus exceeds them the index carries only what fits. Until now every sync told the agent to read the index in full and open **every** file it referenced, with no upper bound; the corpus grows with the team and nothing pushed back.
- `feat(sync): withholding report` — per-source injected-of-total counts and sizes with the limit that produced them, plus individually named oversized items, starved sources, and conflict withdrawals. A budget that trimmed the corpus without saying so would convert a visible context overflow into an invisible knowledge gap, so the reporting is not optional polish — it ships in the same release as the ceiling.
- `feat(sync): partial-corpus marker` — the index header and the agent-facing context block both state when the corpus is partial, so the agent cannot present a trimmed corpus as everything the project knows.
- `feat(sync): --verbose lists withheld identities` — derived as *manifest items − indexed items*, so no third record is maintained. Kept out of the default output because sync runs at four automatic points per feature cycle, and out of the index because that is the one document the agent reads in full.
- `feat(sync): advisory threshold` — with **no** budget configured, a corpus past 200 items or 2 mb produces one informational line naming both the measured value and the threshold. Same standing as the existing "more than ten sources" warning: it alters nothing. Without it, an opt-in guard would never reach the projects that most need one.
- `feat(status): budget column` — indexed-of-total per source, with the limit applied named. Mirrors the existing rule that a reported freshness state always states its threshold.
- `docs(readme): trust model` — states that merging a config change causes a fetch on every teammate's machine and every automated environment, including via hooks the reviewer may never run. Names the defenses **with their limits**, names three exposures as undefended, and gives a reviewer checklist. No new mechanism: the exposures already existed and the defenses were already implemented; they were simply not written down anywhere a reviewer would look.

### Fixed

- `fix(search): read the manifests, not the index` — `search` iterated the items *in* `knowledge-index.md`. Once the index is bounded by a budget, a withheld item would have been absent from the only file search read — unfindable rather than merely un-injected, collapsing the distinction the whole feature rests on. Search now builds its inventory from the per-source `.manifest.json` files, which are written **before** the budget is applied and always hold the complete list. Found during planning research, not during implementation.

### Security

- **Symlink following is documented as an open exposure, not fixed.** Indexing enumerates `.md` files after checkout, and `git checkout` recreates symlinks faithfully — so a source containing `notes.md -> ~/.ssh/id_rsa` yields an index entry the agent is instructed to read into its context, and from there potentially into a committed spec. Nothing in the pipeline resolves or rejects it. Refusing to index links that escape the cache root is the intended fix and is **not** in this release; naming it is what the trust model requires, and omitting it because it is inconvenient would be the failure the trust model exists to prevent.

### Changed

- `extension.yml` `version` bumped from `1.4.0` to `1.5.0`. **Command count stays 5** and no hook changes, so Constitution Quality Gates §2, §5 and §10 are untouched.
- `config-template.yml` documents both keys and carries a security block pointing at the trust model. **`schema_version` stays `"1.0"`**: both keys are optional and default to prior behaviour.
- A per-source budget is a **sub-ceiling**, deliberately unlike `max_cache_age` — which occupies the same two positions in the file but whose per-source value *replaces* the project value. A per-source ceiling above the project ceiling is clamped and reported rather than skipping the source, since the value is well-formed and has exactly one safe reading.
- The Configuration Validation Rules block gained two rows in all three copies at once, as Quality Gate §11 requires.

### Compatibility

A project that upgrades and configures no budget observes identical behaviour: same
indexed item set, same output, same index — apart from the generation timestamp
every sync has always written. No default budget is applied, because a default
would have been the first break in the "upgrade and change nothing, observe nothing
different" guarantee the last two releases made explicitly.

## [1.4.0] - 2026-09-04

Source lifecycle, per-source revision pinning, and a cache freshness policy. The
three ship together on purpose: the freshness policy is what makes the four
automatic sync hooks affordable, and revision pinning is what makes a long-lived
cache safe to trust.

**This release also carries the 1.3.0 hooks**, which were implemented but never
tagged. Publishing them alone would have shipped four sync points per feature
cycle without the policy that keeps them cheap.

### Added

- `feat(remove): speckit.knowledge.remove` — a fifth command owning the whole activation lifecycle of a source: remove (entry deleted, cache purged), `--disable` (entry and cache both retained), `--enable`. Previously the only way to stop consuming a source was to hand-edit YAML. Takes a **label**; a URL is accepted only when it resolves to exactly one source, and lists the candidates instead of guessing when it does not.
- `feat(config): per-source revision pinning` — an optional `revision` key accepting a branch, tag, or full commit SHA, settable with `--revision <rev>` or the `<url>@<rev>` shorthand. Two revisions of one repository can now be configured side by side; they hold separate caches and cannot contaminate each other. A source that pins none keeps the exact cache identity it already has, so upgrading re-downloads nothing.
- `feat(config): cache freshness policy` — an optional `max_cache_age` duration (`30m`, `4h`, `7d`), settable project-wide and overridable per source. A source whose cache is younger than its policy is served from disk with no network access at all, reported as `⏭️ current` so the skip stays visible. With `4h` configured, a full feature cycle performs one fetch per source instead of four.
- `feat(sync): --force` — ignores the freshness policy. Structurally unreachable from an automatic trigger, because the hook entries declare no arguments.
- `feat(sync): orphaned cache pruning` — changing a source's `revision` gives it a new cache identity and strands the previous directory. Sync now deletes any cache belonging to no configured source. The keep-set is computed over **disabled sources too**, or `--disable` would silently behave like `remove`.
- `feat(status): revision column and policy-aware freshness` — `status` shows each source's effective revision, and its `fresh`/`cached` labels now follow the configured policy rather than a fixed 24-hour threshold. The threshold actually applied is printed, so a label is never unexplained.
- `feat(hooks): sync before clarify and task generation` — carried over from the untagged 1.3.0. `before_clarify` and `before_tasks` join `before_specify` and `before_plan`. All four are `optional: true`.

### Fixed

- `fix(validation): validate configuration on read, not only on write` — the inherited `path_filter` checks ran only inside `configure`, so a value arriving by hand-edit, by pull request, or from an older version of this extension was consumed unchecked. The full rule set now runs every time `knowledge-config.yml` is read. A failing value skips **only its own source**, naming the field and the value; every other source still synchronizes and the command still exits 0.
- `fix(security): reject option-shaped configuration values and separate git arguments` — `url`, `revision`, and `path_filter` are interpolated into `git` command lines, so a value beginning with `-` is parsed as an option rather than data. A `revision` of `--upload-pack=<command>` handed to `git fetch` is remote code execution triggered by nothing more than a pull request editing a YAML file. Two independent defenses are now required: such values are rejected, **and** every `git` invocation places `--` before configuration-derived operands so a value that bypassed validation still cannot be read as an option.
- `fix(sync): empty configuration deletes the knowledge index` — when no enabled sources remain, sync reported success and left the previous index in place, letting an agent keep citing knowledge the project no longer declares. The index is now deleted and the agent context block is suppressed. Exit code stays 0.
- `fix(configure): enforce label uniqueness` — a label is the identity of a source, but two local paths sharing a final component, or one repository added twice at different revisions, both produced duplicates. Collisions are now resolved before writing.
- `fix(sync): scope conflict reporting by repository identity` — with revision pinning, identical file paths across two revisions of one repository are the normal case, not a disagreement. Conflicts are reported only between sources whose repository identity differs. Identity ignores the access protocol, so HTTPS and SSH for the same repo no longer report every shared file as conflicting.
- `fix(search): distinguish "no sources configured" from "sources unreachable"` — the missing-index message blamed unreachability for a state that index deletion now makes reachable.
- `fix(sync): make slug generation shell-independent` — the inherited algorithm hashed `echo -n "$normalized"`, but `echo -n` is not portable: under a POSIX shell (`/bin/sh` on macOS is bash in POSIX mode) it emits the literal `-n ` before the string. The same URL therefore hashed to a different cache slug depending on which shell the executing agent happened to use — `1dcedc6df20c` under `/bin/sh` versus `18dbb51ec4eb` under bash or zsh. Now uses `printf '%s'`, which is portable. **Consequence**: a project whose agent had been running the snippet under POSIX `sh` re-downloads its sources once, then stays stable. Projects on bash or zsh — the overwhelming majority — see no change at all.
- `fix(docs): use the dot-separated invocation form` — README examples showed `/speckit-knowledge-*`, which does not match the separator this integration renders.

### Changed

- `extension.yml` `version` bumped from `1.3.0` to `1.4.0`. Command count 4 → 5.
- `configure` merges an existing entry only when the URL **and** the revision both match. The previous URL-only rule would have made it impossible to configure two revisions of one repository — the second `configure` would have silently overwritten the first.
- `config-template.yml` documents `revision` and `max_cache_age`. **`schema_version` stays `"1.0"`**: both keys are optional and default to prior behavior, so no existing configuration becomes invalid.
- Constitution Quality Gate §2 amended from "all four commands" to five, and § Code Boundaries exempted `memory/` from its no-hand-edit rule — which § Governance had always required contradicting.

### Compatibility

A project that upgrades and changes nothing observes identical behavior: same cache
directories, same sync results, same index contents, same agent-facing output. The
revision is folded into the cache slug **only** when one is pinned, which is what
makes that guarantee hold without a migration step.

## [1.3.0] - 2026-09-04

### Added

- `feat(hooks): sync knowledge before clarify and task generation` — `extension.yml` now declares `before_clarify` and `before_tasks` in addition to `before_specify` and `before_plan`. Shared contracts and decisions are as relevant when resolving spec ambiguities and breaking work into tasks as they are when drafting a spec, but those two commands previously ran against whatever the cache happened to hold. Both new hooks are `optional: true`, so spec-kit prompts before each sync.

### Known limitation

- Going from two hooks to four means up to four clone/fetch operations per feature cycle. Every hook is declinable, but the real fix is a cache TTL (`max_age`) that lets sync no-op when the cache is still fresh. That work is tracked separately and is not in this release.

### Changed

- `extension.yml` `version` bumped from `1.2.0` to `1.3.0`.
- README § "Integration with /speckit-specify and /speckit-plan" renamed to "Integration with the spec-kit lifecycle" and rewritten as a four-row hook table with a note on the per-cycle sync cost.

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
[Unreleased]: https://github.com/rnoap/spec-kit-shared-knowledge/compare/v1.4.0...HEAD
[1.4.0]: https://github.com/rnoap/spec-kit-shared-knowledge/releases/tag/v1.4.0
[1.3.0]: https://github.com/rnoap/spec-kit-shared-knowledge/releases/tag/v1.3.0
[1.2.0]: https://github.com/rnoap/spec-kit-shared-knowledge/releases/tag/v1.2.0
[1.1.0]: https://github.com/rnoap/spec-kit-shared-knowledge/releases/tag/v1.1.0
[1.0.0]: https://github.com/rnoap/spec-kit-shared-knowledge/releases/tag/v1.0.0
