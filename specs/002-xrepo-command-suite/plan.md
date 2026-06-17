---
status: migrated
feature: xrepo-command-suite
---

# Implementation Plan: xrepo Command Suite

**Branch**: `main` | **Date**: 2026-06-17 (migrated) | **Spec**: `specs/002-xrepo-command-suite/spec.md`

**Note**: Reverse-engineered from existing command files. All phases complete. Status is `migrated`.

---

## Summary

Four agent-prompt Markdown files that implement the cross-repo knowledge workflow: configure sources → sync cache → search/browse → check status. Each file is a self-contained spec-kit command prompt executed by the AI agent. The commands share two reusable algorithms (Source Slug Generation, Cache Integrity Check) defined in `speckit.xrepo.sync.md` and referenced by `speckit.xrepo.status.md`.

---

## Technical Context

**Language/Version**: Markdown (CommonMark) — agent prompt files, not executable code. Embedded Bash pseudocode for algorithm documentation.

**Primary Dependencies**: spec-kit `>= 0.10.0` (command dispatch), git `>= 2.25` (sparse-checkout, ls-remote), `sha256sum` / `shasum -a 256` (slug + integrity)

**Storage**:
- Reads: `.specify/extensions/shared-knowledge/shared-knowledge.yml` (config), `cache/<slug>/.manifest.json` (integrity), `cache/<slug>/<path>` (file content)
- Writes: `cache/<slug>/` (git clone), `cache/<slug>/.manifest.json`, `.specify/extensions/shared-knowledge/knowledge-index.md`
- Does not modify: `shared-knowledge.yml` (sync/search/status are read-only for config)

**Testing**: No automated tests. Manual verification by running commands against a real spec-kit project with a known source repo.

**Target Platform**: Any POSIX environment with git 2.25+ and spec-kit 0.10+

**Project Type**: Agent prompt files — behavior is implemented by the executing AI agent interpreting the Markdown instructions

**Performance Goals**: Sync < 30s single remote source; search < 1s for ≤ 50 items; status < 10s (dominated by reachability check timeout)

**Constraints**:
- Exit 0 always — degraded operation (cache fallback, unreachable source) is not a failure
- Conflicts must be preserved, not silently resolved
- `.manifest.json` written last (integrity signal — absent manifest = interrupted sync)
- Search must auto-recover (run sync if index absent)

**Scale/Scope**: 4 command files, 646 lines total. Shared algorithms (~60 lines) in sync, referenced by status.

---

## Constitution Check

- ✅ Markdown agent prompts only — no compiled code
- ✅ Commands are self-contained: no hidden runtime dependencies beyond declared `requires`
- ✅ Exit-0 contract (degraded operation): consistent across all 4 commands

---

## Project Structure

### Documentation (this feature)

```text
specs/002-xrepo-command-suite/
├── spec.md      # This spec (migrated)
├── plan.md      # This file (migrated)
└── tasks.md     # Task list (migrated)
```

### Source Code (repository root)

```text
commands/
├── speckit.xrepo.configure.md   # 136 lines
├── speckit.xrepo.sync.md        # 287 lines — includes shared Algorithm Reference
├── speckit.xrepo.search.md      # 110 lines
└── speckit.xrepo.status.md      # 113 lines
```

---

## Key Technical Decisions

### Decision 1: SHA-256 Source Slug (not human-readable label)

Cache directories use a 12-char SHA-256 hex prefix of the normalized URL, not the label. Rationale: labels can change without changing the source (user may rename); URL is the stable identity. Normalized before hashing (strip `.git`, trailing slash, lowercase) so equivalent URLs map to the same cache.

### Decision 2: `.manifest.json` Written Last

The manifest is written as the final step of sync, after all `.md` files are in place. An absent or corrupt manifest is the signal that the previous sync was interrupted — the Cache Integrity Check uses this to decide whether to trust or discard the cache. This is a write-last-to-commit pattern without requiring filesystem transactions.

### Decision 3: Algorithm Reference in sync.md, Referenced by status.md

Source Slug Generation and Cache Integrity Check are defined once in `speckit.xrepo.sync.md § Algorithm Reference` and referenced by `speckit.xrepo.status.md`. This avoids duplication across prompts while keeping each prompt self-contained for execution (the agent reads sync.md's algorithm section when executing status).

### Decision 4: Conflict Preservation (no silent winner)

When the same relative path appears in multiple sources, both items are included in the index with a `⚠️ CONFLICT` annotation. Silently preferring one source would hide information; the developer should see both and decide which applies.

### Decision 5: Auto-Sync in Search

`speckit.xrepo.search` automatically triggers `speckit.xrepo.sync` if `knowledge-index.md` is absent. This removes a manual prerequisite for new users who forget to sync before searching.

### Decision 6: Local Path Support

Sources can be local filesystem paths (prefixed `/`, `~/`, `./`). Local clones use no network flags and no timeout wrapper — they're instant. This enables use in air-gapped environments or with repos already on the developer's machine.

---

## Complexity Tracking

No constitution violations.
