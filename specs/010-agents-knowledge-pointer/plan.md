# Implementation Plan: Point the agent at shared knowledge from AGENTS.md

**Branch**: `010-agents-knowledge-pointer` | **Date**: 2026-10-22 | **Spec**: [agents-knowledge-pointer.spec.md](./agents-knowledge-pointer.spec.md)

## Summary

Sync keeps a short, marker-delimited section in the consumer project's root `AGENTS.md`. The section sends the agent to `knowledge-index.md` for any question about another repository or a configured source, lists the enabled source labels, and limits the agent to those sources. Remove, `--disable` and `--enable` re-derive the same section from the configuration and never touch the index. A new optional top-level key, `agents_md`, turns the behavior off.

Everything lives in the command prompts: the procedure is defined once as `§ Agent Context Section` in `speckit.knowledge.sync.md`, and `remove` points to it, the way it already points to § Source Slug Generation. No script and no new dependency.

## Project Structure

```text
commands/
├── speckit.knowledge.sync.md       # new § Agent Context Section; step 1a removes the section; new step 8b; step 9 report line; Side effects; error table; validation-rules row
├── speckit.knowledge.remove.md     # new step 3a applies § Agent Context Section after the config write; report line; Side effects
├── speckit.knowledge.configure.md  # validation-rules row (byte-identical); step 4 keeps every other top-level key
└── speckit.knowledge.status.md     # validation-rules row only (byte-identical, check 11)
config-template.yml                 # commented `agents_md` block in the optional project-wide keys
README.md                           # "Ask in plain language" section + key reference bullet
CHANGELOG.md                        # [Unreleased] Added
specs/010-agents-knowledge-pointer/ # plan, research, data-model, contracts, quickstart
```

**Structure Decision**: one procedure in `sync.md`, referenced from `remove.md`. Duplicating it would add a second copy that rule 11 does not guard.

## Call paths

- `speckit.knowledge.sync`: step 1 validates the config, including `agents_md`.
  - Step 1a, when no source is enabled: delete the index, then apply § Agent Context Section in **remove** mode.
  - Step 8 writes the index. Step 8a prunes caches. Step 8b applies § Agent Context Section in **write** mode with the enabled, accepted labels. Step 9 reports the outcome on one line.
  - When no index was written and none existed (every source unreachable on a first sync), step 8b does nothing.
- `speckit.knowledge.remove`: steps 1–2 resolve and apply the mode, and step 3 writes the config.
  - Step 3a: if `knowledge-index.md` exists, apply § Agent Context Section with the enabled, accepted labels after the change. That is **write** mode, or **remove** mode when no label remains. Step 4 reports the outcome on one line.
- `speckit.knowledge.configure` never calls the section: no index exists before the first sync.

## States

The knowledge section in `AGENTS.md`:

| From | Event | To |
| --- | --- | --- |
| absent (no file, or file without markers) | sync writes the index, `agents_md` on, ≥1 enabled source | present, matching the labels |
| present | sync or remove, labels unchanged | present, file not written |
| present | sync or remove, labels changed | present, section replaced in place |
| present | sync step 1a deletes the index, or remove leaves no enabled source, or `agents_md: false` | absent; file deleted only if nothing else remains |
| damaged (unpaired or duplicated markers) | any write or remove | damaged, file untouched, warning |
| any | `agents_md` invalid | unchanged, file untouched, warning |

## Constitution Check

| Principle | Assessment |
| --- | --- |
| I. Extension-Package Discipline | PASS. Prompts only. Nothing new in `extension.yml` except the version at release. Writing a project-root file has a precedent: configure already appends to `.gitignore`. |
| II. Source-of-Truth Hierarchy | PASS. `config-template.yml` documents `agents_md`; the three commands carry the same rule; README follows. |
| III. Simplicity (YAGNI) | PASS. A Markdown procedure applied with the agent's file-writing tool. No Bash script, per "a Markdown addition MUST NOT become a Bash script". |
| IV. Conventional Commits | PASS. `feat(sync):`. The new config key and behavior make this a minor release (1.9.0). |
| Quality gate 11 (identical validation blocks) | PASS by construction. The `agents_md` row is added byte-identically to configure, status and sync. |
| Quality gate 12 (single-quoted placeholders) | PASS. The feature adds no bash block. |
| Quality gate 5 (command tokens) | PASS. Printed messages use `__SPECKIT_COMMAND_*__` tokens. The persisted section names `speckit.knowledge.sync` by its canonical id with no `/` or `$` prefix, so its bytes match on every host (research R8). |

Re-checked after Phase 1 design: unchanged.
