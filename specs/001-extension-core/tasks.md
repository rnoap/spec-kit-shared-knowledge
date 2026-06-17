---
status: migrated
feature: extension-core
---

# Tasks: Extension Core Infrastructure

**Input**: `specs/001-extension-core/spec.md`, `specs/001-extension-core/plan.md`

**Note**: All tasks are marked `[x]` — this feature exists in the current implementation. Migrated on 2026-06-17.

**Gaps identified**: See end of file.

---

## Phase 1: Setup

**Purpose**: Create extension manifest and config schema

- [x] T001 Create `extension.yml` with `id: shared-knowledge`, `version: 1.0.0`, 4 commands under `provides.commands`, 2 hooks (`before_specify`, `before_plan`), `requires.speckit_version >= 0.10.0`
- [x] T002 Create `config-template.yml` with `schema_version: "1.0"` and empty `sources: []`; include commented example entry with all supported fields (`url`, `label`, `path_filter`, `enabled`)

---

## Phase 2: Foundational

**Purpose**: Core install script — file copying and registry update

- [x] T003 Create `scripts/install-local.sh` skeleton with `set -euo pipefail`, variable declarations (`EXTENSION_ID`, `PROJECT_DIR`, `REGISTRY`, `EXT_DIR`), and optional positional argument for target path
- [x] T004 [P] Add spec-kit project validation (check `.specify/extensions` exists, exit 1 if absent)
- [x] T005 [US1] Implement command file copy loop (`for src in commands/speckit.xrepo.*.md`) → `EXT_DIR/commands/`; report count
- [x] T006 [US1] Implement `extension.yml` copy to `EXT_DIR/extension.yml`
- [x] T007 [US1] Implement no-clobber config copy: skip if `shared-knowledge.yml` already exists in consumer project
- [x] T008 [US1] Implement registry update via inline Python 3 heredoc: read existing `.registry` JSON, upsert extension entry with `version`, `source: local`, `manifest_hash`, `registered_commands`, `installed_at`
- [x] T009 [US1] Add SHA-256 dual implementation: `sha256sum` (Linux) with `shasum -a 256` (macOS) fallback

**Checkpoint**: Install installs files and registers extension. `specify extension list` shows `shared-knowledge`.

---

## Phase 3: User Story 1 Complete — bash 3.2 Compatibility (Priority: P1)

**Goal**: Ensure install works on macOS with system bash (3.2)

- [x] T010 [US1] Replace `SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")` with `cd "$(dirname "${BASH_SOURCE[0]}")" && pwd` pattern (bash 3.2 compatible)
- [x] T011 [US1] Verify no use of `declare -A`, `mapfile`, or other bash 4+ features in script

**Checkpoint**: Install works on macOS default bash (3.2) and modern Linux bash (5.x).

---

## Phase 4: User Story 3 — SKILL.md Wrappers (Priority: P2)

**Goal**: Generate discoverable SKILL.md files for Wibey and Claude Code

- [x] T012 [US3] Implement `generate_skill()` function: accepts `cmd_file` and `target_dir`; derives skill name via `sed 's/\./-/g'`; extracts description from frontmatter via `grep '^description:'`
- [x] T013 [US3] Implement body extraction using `awk` to skip YAML frontmatter block (lines between first and second `---` delimiters)
- [x] T014 [US3] Write `SKILL.md` with YAML frontmatter (`name`, `description`, `compatibility`, `metadata.author`, `metadata.source`) + extracted body
- [x] T015 [US3] Call `generate_skill` for both `.wibey/skills/` and `.claude/skills/` targets for each installed command
- [x] T016 [US3] Print `.gitignore` reminder for cache and knowledge-index files at end of install

**Checkpoint**: After install, `.wibey/skills/speckit-xrepo-*/SKILL.md` and `.claude/skills/speckit-xrepo-*/SKILL.md` exist with correct content.

---

## Phase N: Polish

- [x] TXXX Add `README.md` with install instructions, command table, manual hook setup steps, troubleshooting for proxy (407) errors
- [x] TXXX Add `CHANGELOG.md` with Keep-a-Changelog format; document v1.0.0 features
- [ ] TXXX (GAP) Add automated smoke test for install script (e.g., `tests/test-install.sh` that creates a temp spec-kit project, runs install, and verifies output)

---

## Gaps Identified

| Gap | Severity | Recommendation |
|-----|----------|---------------|
| No automated test for `install-local.sh` | Medium | Add `tests/test-install.sh` — creates temp dir, runs `specify init`, runs install, asserts file presence and `specify extension list` output |
| No test for bash 3.2 compatibility | Low | Add CI job on macOS with system bash, or document tested bash version in README |
| ~~`.gitignore` reminder is printed but not automated~~ | ~~Low~~ | ✅ Fixed — `install-local.sh` now auto-appends `.gitignore` entries (idempotent) |
| ~~`python3` hard dependency not documented in `extension.yml` `requires`~~ | ~~Low~~ | ✅ Fixed — `python3` added to `requires.tools` in `extension.yml` |
