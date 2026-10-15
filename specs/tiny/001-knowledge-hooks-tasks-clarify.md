# TinySpec: `before_tasks` and `before_clarify` hooks

**Branch**: main
**Date**: 2026-09-04
**Status**: done
**Complexity**: small

## What

The `knowledge` extension only syncs on `before_specify` and `before_plan`. Shared contracts and decisions matter just as much when breaking work into tasks and when resolving ambiguities, so today `/speckit.tasks` and `/speckit.clarify` start from a potentially stale cache. Add those two hook points.

## Context

| File | Role |
| --- | --- |
| [extension.yml](../../extension.yml) | Modify — 2 new entries under `hooks:`, plus the version bump |
| [README.md](../../README.md) | Modify — § "Integration with /speckit-specify and /speckit-plan" covers only 2 hooks |
| [CHANGELOG.md](../../CHANGELOG.md) | Modify — `[1.3.0]` section |

`before_tasks` and `before_clarify` are valid hook points: they are among the 19 events spec-kit registers in this project's `.specify/extensions.yml`.

## Requirements

1. `extension.yml#hooks` declares `before_tasks` and `before_clarify`, both with `command: speckit.knowledge.sync` and **no arguments** — FR-016 of spec 003 requires that an automatic trigger cannot pass `--no-context-output`.
2. Both use `optional: true` plus a `prompt`, the same pattern as the two existing hooks.
3. `extension.version` goes from `1.2.0` to `1.3.0` (new feature → minor).
4. After `specify extension add <path> --dev` in a clean project, all **four** hooks appear in the consumer's `.specify/extensions.yml`.
5. The README stops describing the integration as specific to specify and plan.

## Plan

1. `extension.yml`: add the 2 entries under `hooks:`, copying the shape of `before_plan` (`command` / `optional` / `prompt` / `description`).
2. `extension.yml`: `version: "1.2.0"` → `"1.3.0"`.
3. `README.md`: give the integration section a neutral title and list all four hook points.
4. `CHANGELOG.md`: `## [1.3.0] - 2026-09-04` section, plus updated footer links.
5. Verify with a clean install.

## Tasks

- [x] T1 Add `before_tasks` to `extension.yml#hooks`
- [x] T2 Add `before_clarify` to `extension.yml#hooks`
- [x] T3 Bump `extension.version` → `1.3.0`
- [x] T4 Retitle the README integration section and extend it to the 4 hooks
- [x] T5 `[1.3.0]` CHANGELOG entry plus footer links
- [x] T6 `specify extension add <path> --dev` in a clean project → confirm the 4 hooks

## Done When

- [x] All tasks checked off
- [x] The test project's `.specify/extensions.yml` lists the 4 hooks
- [x] `specify extension list` reports `knowledge 1.3.0`

## Note — cost per cycle

Going from 2 to 4 hooks means up to 4 clones or fetches per feature cycle. All four are `optional: true` (the user can decline), but the real fix is the `max_age` TTL that was deferred to the full SDD workflow. If that work lands soon, consider releasing 1.3.0 together with it rather than on its own.
