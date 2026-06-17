---
status: migrated
feature: extension-core
migrated_from: scripts/install-local.sh, extension.yml, config-template.yml
migrated_at: 2026-06-17
---

# Feature Specification: Extension Core Infrastructure

**Feature Branch**: `main`

**Created**: 2026-06-17 (migrated from existing implementation)

**Status**: migrated

**Input**: Reverse-engineered from `scripts/install-local.sh`, `extension.yml`, `config-template.yml`

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Install Extension into a spec-kit Project (Priority: P1)

A developer working on a spec-kit project wants to use cross-repo knowledge injection. They run the install script to make the 4 knowledge extension commands available in their project without publishing to a registry.

**Why this priority**: Core distribution mechanism — nothing works without this.

**Independent Test**: Run `bash scripts/install-local.sh /path/to/project` against a clean spec-kit project; verify `specify extension list` shows `knowledge` and all 4 commands are available.

**Acceptance Scenarios**:

1. **Given** a valid spec-kit project (`.specify/extensions` exists), **When** `bash scripts/install-local.sh` is run, **Then** all 4 command files are copied to `.specify/extensions/knowledge/commands/`, `extension.yml` is copied, and the extension appears in `specify extension list`
2. **Given** the target project has no existing `knowledge.yml`, **When** install runs, **Then** `config-template.yml` is copied as `knowledge.yml` (initial config with empty sources)
3. **Given** the target project already has a `knowledge.yml`, **When** install runs again, **Then** the existing config is preserved (no-clobber) and the script prints `ℹ️  knowledge.yml already exists — not overwriting`
4. **Given** the target directory is not a spec-kit project (no `.specify/extensions`), **When** install runs, **Then** the script prints `❌ Error: ... does not look like a spec-kit project` and exits with code 1

---

### User Story 2 — Upgrade an Existing Installation (Priority: P1)

A developer upgrades the extension after new commands or fixes have been released.

**Why this priority**: Idempotent installs are critical for maintenance without destroying config.

**Independent Test**: Run `bash scripts/install-local.sh` twice on the same project; verify the second run updates commands and registry without errors, and the existing `knowledge.yml` is unchanged.

**Acceptance Scenarios**:

1. **Given** the extension is already installed, **When** install runs again, **Then** command files are overwritten with latest versions, the registry entry is updated (`ℹ️  Already registered — updating entry`), and config is preserved
2. **Given** the registry entry exists, **When** install runs, **Then** `manifest_hash` is recalculated from the newly copied `extension.yml`

---

### User Story 3 — SKILL.md Wrappers for AI Agents (Priority: P2)

After installation, the 4 knowledge extension commands must be discoverable as skills in `.claude/skills/`, following the same pattern as built-in Claude Code skills.

**Why this priority**: Without SKILL.md wrappers, AI agents that consume `.claude/skills/` cannot invoke the commands via the `/` autocomplete.

**Independent Test**: After `bash scripts/install-local.sh`, verify `.claude/skills/speckit-knowledge-configure/SKILL.md` exists with correct frontmatter and body extracted from the command file.

**Acceptance Scenarios**:

1. **Given** install completes successfully, **When** `.claude/skills/speckit-knowledge-*/SKILL.md` is read, **Then** it contains valid YAML frontmatter (`name`, `description`, `compatibility`, `metadata`) and the command body (everything after the second `---` in the source command file)
2. **Given** install completes, **When** `.claude/skills/speckit-knowledge-*/SKILL.md` is read, **Then** the body is identical to the markdown body of the corresponding source command file

---

### Edge Cases

- What happens when Python 3 is not available? → `python3` call in registry update fails; install halts (set -euo pipefail)
- What happens when `sha256sum` is not available (macOS)? → Script falls back to `shasum -a 256`
- What happens when `.registry` file is absent? → Script prints `❌ Error: .registry not found` and exits 1
- What happens when install is run from a directory other than the project root? → `PROJECT_DIR="${1:-$(pwd)}"` is used; caller must pass the correct path or `cd` first

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Install script MUST copy all `commands/speckit.knowledge.*.md` files to `.specify/extensions/knowledge/commands/`
- **FR-002**: Install script MUST copy `extension.yml` to `.specify/extensions/knowledge/extension.yml`
- **FR-003**: Install script MUST copy `config-template.yml` as `knowledge.yml` ONLY if no config file already exists (no-clobber)
- **FR-004**: Install script MUST register the extension in `.specify/extensions/.registry` (JSON), computing `manifest_hash` via SHA-256 of the installed `extension.yml`
- **FR-005**: Install script MUST generate SKILL.md wrappers in `.claude/skills/<skill-name>/SKILL.md` for each installed command
- **FR-006**: SKILL.md wrappers MUST use the command's dot-notation filename converted to kebab-case as the skill name (e.g., `speckit.knowledge.configure` → `speckit-knowledge-configure`)
- **FR-007**: Install script MUST accept an optional positional argument as the target project path; default to `$(pwd)`
- **FR-008**: Install script MUST validate the target is a spec-kit project before proceeding
- **FR-009**: `extension.yml` MUST declare `id: knowledge`, `version: 1.0.0`, all 4 commands under `provides.commands`, and two hooks (`before_specify`, `before_plan`)
- **FR-010**: `config-template.yml` MUST declare `schema_version: "1.0"` and `sources: []` as the default empty config

### Key Entities

- **Extension Manifest** (`extension.yml`): Declares the package identity, version, commands, hooks, and requirements. Source of truth for registry registration.
- **Config Template** (`config-template.yml`): User-facing YAML schema with schema_version and sources list. No-clobber installed to consumer project.
- **Registry Entry** (`.specify/extensions/.registry`): JSON record per extension: version, source, manifest_hash, enabled, priority, registered_commands.
- **SKILL.md Wrapper**: Generated Markdown file in `.claude/skills/` per command; contains YAML frontmatter + command body extracted from source.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: `bash scripts/install-local.sh` completes with exit code 0 on a clean spec-kit project in under 5 seconds
- **SC-002**: `specify extension list` shows `knowledge` with all 4 commands after install
- **SC-003**: Re-running install on a project with existing config preserves `knowledge.yml` (md5 of config file unchanged)
- **SC-004**: Generated SKILL.md files contain valid YAML frontmatter (parseable by any YAML parser)

---

## Assumptions

- Consumers have spec-kit `>= 0.10.0` installed and have run `specify init` to create `.specify/`
- `python3` is available in PATH (used for JSON registry update)
- `git >= 2.25` is available in PATH
- Consumer's project has a `.specify/extensions/.registry` JSON file (created by `specify init`)
- macOS and Linux are the only supported platforms (POSIX bash)
