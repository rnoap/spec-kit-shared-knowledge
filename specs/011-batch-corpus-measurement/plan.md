# Implementation Plan: Shell-recorded manifests, so a full knowledge sync fits in one turn

**Branch**: `011-batch-corpus-measurement` | **Date**: 2026-10-26 | **Spec**: [batch-corpus-measurement.spec.md](./batch-corpus-measurement.spec.md) | **Research**: [research.md](./research.md)

## Summary

Sync stops asking the agent to copy every item's path and hash into `.manifest.json`. One shell run per source, assembled from three blocks of the sync command, collects, measures, hashes and encodes the items, writes the manifest atomically, and prints the path-and-size report the agent builds the index from. The shared Cache Integrity Check becomes a block too: it renders the manifest the record run would write and compares bytes, so status, search and sync get pass or fail from one run. File names reach the encoder only as hex bytes from `od`, so one POSIX awk program validates UTF-8 and escapes JSON without the shell ever parsing a name. Two recovery bugs found while planning ship in the same release (FR-020, FR-021). The feasibility spike gates all other work.

## Project Structure

```text
commands/
├── speckit.knowledge.sync.md      # Freshness Gate, Corpus Measurement, Indexable Items,
│                                  # new Item Records, Cache Integrity Check; steps 4, 5, 6, 9
├── speckit.knowledge.status.md    # step 2 runs the shared check
└── speckit.knowledge.search.md    # the check returns a verdict; search sets a failing source aside
.github/scripts/test-sync-git.sh   # new --records and --recovery groups
specs/007-shell-safe-config/research.md   # §7 notes the revision by 011, manifest only
README.md                          # Troubleshooting entries, version badge and install URL
CHANGELOG.md                       # [1.10.0]
extension.yml                      # version 1.10.0
```

**Structure Decision**: runtime behavior stays in command Markdown, as fenced `bash` blocks under unique `###` headings that the harness extracts by heading. The tests extend the existing harness.

## Calls

The record run for one source, sync step 5, is one shell invocation of three blocks:

```text
sync step 5 → § Indexable Items   cd cache/<slug>; $items, $links (LC_ALL=C, -z links, no LF paths, byte order)
            → § Item Records      per item: wc -c, sha256sum or shasum, od → awk encoder;
                                  sets the item lines, report, skipped names; defines the manifest renderer
            → step 6 block        date -u → .manifest.json.tmp → mv -f → .manifest.json; prints the report
```

The check run uses the same first two blocks with the check block as its tail:

```text
status step 2 ┐
search step 1 ├→ § Indexable Items → § Item Records → § Cache Integrity Check block
sync fallbacks│                                       (read synced_at line, render, cmp; print verdict and report)
sync step 4   ┘  (policy-fresh path)
```

## States

The cache directory of one source, after this change:

```text
Absent: no cache/<slug>/. Sync takes the cold path.
Interrupted: cache/<slug>/ without .git or without .manifest.json. Sync removes it and takes the cold path (FR-020).
Recorded: the record run wrote .manifest.json, and the check passes. shows sync-report
Policy-fresh: the manifest is younger than max_cache_age. Sync runs the check instead of git: pass keeps it, fail makes it stale (FR-012). A missing manifest is stale, never fresh (FR-021).
Corrupted: the check fails. Status shows corrupted, search sets the source aside, and sync's next successful run records it again.
```

## Screens

```screen sync-report Sync summary for one source
title: payment-service
row:
  chip: ✅ synced
  text: 142 items (synced 2026-10-26T14:00:00Z)
text: 🔗 2 symbolic links not followed: specs/notes.md, specs/shared
text: ⚠️ 1 file skipped, name not valid UTF-8: specs/caf\xE9.md
```

The third line is new (FR-006). It follows the links line, and names are escaped as § Values in messages requires, with each invalid byte as `\xHH`.

## Constitution Check

Checked before Phase 0 and again after Phase 1. Unchanged.

| Principle | Assessment |
|---|---|
| I. Extension-Package Discipline | PASS. The procedures live in `commands/*.md`. They use git and the tools the commands already rely on (`awk`, `sed`, `grep`, `find`, `wc`, `sha256sum` or `shasum`) plus POSIX `od`, `date` and `mv`, present on every macOS and Linux install. `extension.yml` keeps declaring only git. |
| II. Source-of-Truth Hierarchy | PASS. The version moves in `extension.yml`, the README badge and the CHANGELOG together. README troubleshooting mirrors the command text. |
| III. Simplicity (YAGNI) | PASS. Shell blocks inside command Markdown, as § Indexable Items already is, and no separate script. Prose alone is what fails today: an agent cannot reliably copy 14 KB of hashes. Tests extend the existing harness. |
| IV. Conventional Commits | PASS. `feat(sync)` for the procedure, `fix(sync)` for FR-020 and FR-021. Nothing is committed without the maintainer's approval. |
| Naming and Code Boundaries | PASS. Edits stay in `commands/`, `.github/scripts/`, `specs/`, README, CHANGELOG and `extension.yml`. |
| Requirements & Compatibility | PASS, pending the spike. `ls-files -s -z` and `-c core.quotePath` predate git 2.25, and the spike runs git 2.25. |
| Quality Gates | PASS. Gate 11: the duplicated validation block stays byte-identical, and its file-name rule already admits `printf '%s' "$file"`. Gate 12: every new placeholder is single-quoted and assigned at the top of its block, before any `$(`. CI stays as it is (clarification 2). |
