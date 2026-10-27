# TinySpec: Strip internal spec references from shipped files

**Branch**: main
**Date**: 2026-10-27
**Status**: done
**Complexity**: small

## What

The command files cite this repo's own requirement IDs: `(007 FR-006)`, `(FR-024)`, `(spec 003, FR-016)`. The files are the prompts the agent runs in a consumer project, and `specs/` is not shipped, so those IDs point nowhere. Worse, a consumer project has its own `specs/NNN-*/spec.md` with its own `FR-011`, which an agent can mistake for the one cited. Today: 193 IDs (sync 116, configure 28, status 28, search 12, remove 7, `extension.yml` 2).

## Context

| File | Role |
| --- | --- |
| [commands/*.md](../../commands/) | Modify: remove the IDs, keep every instruction's meaning |
| [extension.yml](../../extension.yml) | Modify: 2 IDs in the hook comment |
| [.github/scripts/validate-extension.sh](../../.github/scripts/validate-extension.sh) | Modify: new static check 13 |
| [.specify/memory/constitution.md](../../.specify/memory/constitution.md) | Modify: list check 13 under § Quality Gates (1.6.0) |
| [AGENTS.md](../../AGENTS.md) | Modify: point agents at check 13 instead of this spec |
| [CHANGELOG.md](../../CHANGELOG.md) | Modify: `Changed` entry under `[Unreleased]` |

## Requirements

1. No shipped file (`commands/*.md`, `extension.yml`, `config-template.yml`, `README.md`) contains an `FR-`/`SC-` requirement ID or a `spec NNN` reference.
2. Every instruction keeps its meaning. Where the ID is part of the sentence, the sentence names the rule instead.
3. The Configuration Validation Rules block stays byte-identical across its three copies (static check 11).
4. Static check 13 fails on a shipped file that carries an ID, and passes on the cleaned package.

## Plan

1. Inventory: `grep -nE '\b(FR|SC)-[0-9]+|\bspec [0-9]{3}\b'` over the shipped files.
2. Drop parentheticals that only cite an ID.
3. Rewrite the sentences that use an ID as content, all in `sync.md`: lines 128 (`either FR-011 or FR-026`), 236 (`neither FR-006 nor FR-007a`), 988 (`required by FR-034`), 1043 (`this is FR-015`), 1154 (`per FR-034`).
4. Edit the three copies of the Configuration Validation Rules block identically.
5. Add check 13 and show it fails on the current `main` before the cleanup.

## Decisions

**Delete the IDs; do not move them into HTML comments.** The whole command file is the prompt, comments included.

**Check 13 matches IDs, not `specs/NNN-…` paths.** `README.md` and `config-template.yml` use `specs/012-order-tracking/` as a user example, which must stay.

**Traceability stays in `specs/`.** Each feature's `tasks.md` names the files it changed, and `git log -S` finds where a rule came from.

**Shipped on its own, in 1.10.2.** The plan was to wait for the next functional release, because each release needs a catalog update issue on github/spec-kit. Submission #5137 had not been processed yet, so it moved to 1.10.2 at no extra cost. Retagging 1.10.1 was ruled out: release tags are immutable by repository ruleset.

## Tasks

- [x] T1 Remove the parenthetical IDs from `commands/*.md` and `extension.yml` (176 of the 193, by script; the other 17 in T2)
- [x] T2 Rewrite the sentences that use an ID as content: 14, not five (12 in `sync.md`, 1 in `status.md`, 1 in `extension.yml`)
- [x] T3 Keep the Configuration Validation Rules block identical across its copies
- [x] T4 Static check 13 in `validate-extension.sh`: failed on 173 lines before T1, passes after
- [x] T5 Constitution § Quality Gates item 13 and `CHANGELOG.md` entry

## Done When

- [x] The inventory grep finds 0 matches in the shipped files, and 0 in an installed copy
- [x] `validate-extension.sh` passes 19/19
- [x] `test-sync-git.sh` passes 303/303 (git 2.54, macOS), and the install smoke test passes against spec-kit 1.2.3
