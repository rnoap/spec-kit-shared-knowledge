# TinySpec: Drop `sparse-checkout reapply` from the warm path (git 2.25)

**Branch**: main · **Commit**: e727748
**Date**: 2026-10-15
**Status**: done
**Complexity**: small

## What

With a `path_filter`, the `sync` warm path ran `git sparse-checkout reapply` after `set`. That subcommand does not exist in git 2.25, the minimum the extension declares. There it exits 129, and an agent can read the warm sync as failed and keep the old cache.

The first run of `test-sync-git.sh` on git 2.25.1, in `ubuntu:20.04` under Podman, found it after PR #9.

## Context

| File | Role |
| --- | --- |
| [commands/speckit.knowledge.sync.md](../../commands/speckit.knowledge.sync.md) | Modify: drop `reapply` from the warm path and add a note so it does not come back |
| [.github/scripts/test-sync-git.sh](../../.github/scripts/test-sync-git.sh) | Modify: 2 new checks (35 to 38) |
| [CHANGELOG.md](../../CHANGELOG.md) | Modify: `Fixed` entry under `[Unreleased]` |
| [.specify/bugs/knowledge-sync-defects/fix.md](../../.specify/bugs/knowledge-sync-defects/fix.md) | Modify: git 2.25 verification and the follow-up closed |

## Requirements

1. The warm path's sparse step exits 0 on git 2.25.
2. A cache cloned in cone mode, which holds root files, loses them on its next warm sync, as it did with `reapply`.
3. Nothing else changes: the 35 existing checks still pass on git 2.25 and on current git.

## Plan

1. Drop `git sparse-checkout reapply` and its comment. `sparse-checkout set`, which runs just before it, already updates the working tree.
2. Leave a note in the command so nobody adds it back.
3. Add a cone-mode cache scenario to the script.
4. Run the script on macOS (git 2.54) and in `ubuntu:20.04` (git 2.25.1). Also run it against the previous `sync.md` on 2.25, to confirm the new check catches the failure.

## Decisions

**Drop the line instead of tolerating the error** (`reapply 2>/dev/null || true`). The line was redundant, because `set` already does that work. Keeping it would only hide an error on the versions where the subcommand does not exist.

**The check asserts the step's exit code, not just the result.** On 2.25 the result was already correct with the line in place: `set` had done the work before the error. What failed was the 129 exit, so a check on the result alone would have passed with the bug.

## Tasks

- [x] T1 Drop `reapply` from the warm path and add the note
- [x] T2 New checks: the sparse step exits 0, and a cone-mode cache loses its root files
- [x] T3 `CHANGELOG.md` entry and `fix.md` update
- [x] T4 Commit `e727748` on `main`

## Done When

- [x] `test-sync-git.sh` passes 38/38 on git 2.54 (macOS) and on git 2.25.1 with GNU `timeout` (`ubuntu:20.04`)
- [x] With the previous `sync.md` on git 2.25, the sparse-step check fails
- [x] `validate-extension.sh` passes 13/13 (with a `python3` that has PyYAML)
