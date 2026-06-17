---
status: migrated
feature: extension-core
---

# Implementation Plan: Extension Core Infrastructure

**Branch**: `main` | **Date**: 2026-06-17 (migrated) | **Spec**: `specs/001-extension-core/spec.md`

**Note**: This plan was reverse-engineered from the existing implementation (`scripts/install-local.sh`, `extension.yml`, `config-template.yml`). Status is `migrated` — all work is complete.

---

## Summary

Implements the distribution and installation infrastructure for the `knowledge` spec-kit extension. Provides a self-contained Bash install script that copies command files, registers the extension in the spec-kit registry, and generates SKILL.md wrappers for Claude Code.

---

## Technical Context

**Language/Version**: Bash (POSIX-compatible, bash 3.2+), Python 3 (inline heredoc for JSON update), YAML 1.2

**Primary Dependencies**: spec-kit `>= 0.10.0`, git `>= 2.25`, Python 3 (stdlib only — `json` module), `sha256sum` (GNU coreutils) or `shasum -a 256` (macOS fallback)

**Storage**: Files only — copies from extension source into consumer's `.specify/extensions/knowledge/`; generates `.claude/skills/` wrappers; updates `.specify/extensions/.registry` JSON

**Testing**: Manual smoke test — run `bash scripts/install-local.sh` against clean spec-kit project. No automated test harness.

**Target Platform**: macOS (bash 3.2, `shasum`) + Linux (bash 4+, `sha256sum`) — POSIX-compatible

**Project Type**: spec-kit extension package — install script is the sole distribution mechanism (pre-publication)

**Performance Goals**: Install completes in < 5 seconds on local filesystem

**Constraints**:
- No-clobber: must not overwrite existing `knowledge.yml`
- Idempotent: safe to re-run
- Must work with bash 3.2 (macOS system bash): no `declare -A`, no `mapfile`, no `[[ =~ ]]` with capture groups
- Python 3 inline script avoids external JSON tools (`jq` not guaranteed)

**Scale/Scope**: 4 commands, 1 config template, 1 registry entry, 4 SKILL.md files (4 commands × 1 target)

---

## Constitution Check

- ✅ Bash + YAML + Markdown only — no compiled code
- ✅ Install logic confined to `scripts/install-local.sh`
- ✅ No-clobber config install
- ✅ Conventional Commits used throughout development

---

## Project Structure

### Documentation (this feature)

```text
specs/001-extension-core/
├── spec.md      # This spec (migrated)
├── plan.md      # This file (migrated)
└── tasks.md     # Task list (migrated)
```

### Source Code (repository root)

```text
extension.yml                          # Package manifest
config-template.yml                    # User-facing config schema (no-clobber installed)

scripts/
└── install-local.sh                   # Install script — sole distribution mechanism
```

**Consumer-side artifacts produced by install:**

```text
<project>/.specify/extensions/knowledge/
├── commands/
│   ├── speckit.knowledge.configure.md
│   ├── speckit.knowledge.sync.md
│   ├── speckit.knowledge.search.md
│   └── speckit.knowledge.status.md
├── extension.yml
└── knowledge.yml                          # config (no-clobber from config-template.yml)

<project>/.specify/extensions/.registry        # JSON, extension entry appended/updated
<project>/.claude/skills/speckit-knowledge-*/SKILL.md  # 4 wrappers
```

---

## Key Technical Decisions

### Decision 1: Python 3 for JSON Registry Update

Using an inline Python 3 heredoc (`python3 - <<PYEOF ... PYEOF`) to update the JSON registry instead of `jq` or manual string manipulation. Rationale: `jq` is not guaranteed on all developer machines; Python 3 stdlib `json` module is universally available. Bash string manipulation for JSON is brittle.

### Decision 2: SKILL.md Wrapper Generation via awk + heredoc

Body extraction uses `awk` to find the second `---` YAML fence and print everything after it. This preserves the command's Markdown content exactly without requiring a YAML parser. The approach mimics the pattern used by spec-kit's built-in extensions (git, brownfield).

### Decision 3: SHA-256 Dual Implementation

`sha256sum` (GNU) vs `shasum -a 256` (macOS BSD) — both produce identical hex digests. The script detects which is available via `command -v` and branches accordingly. This pattern is also used in the knowledge sync command.

### Decision 4: Skill Name Derivation

Command dot-notation (e.g., `speckit.knowledge.configure`) → kebab-case skill name (`speckit-knowledge-configure`) via `sed 's/\./-/g'`. Consistent with how the brownfield extension's skills are named.

---

## Complexity Tracking

No constitution violations.
