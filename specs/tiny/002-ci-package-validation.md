# TinySpec: CI that validates the package and smoke-tests the install

**Branch**: 005-ci-validation (merged) · **PR**: [#3](https://github.com/rnoap/spec-kit-shared-knowledge/pull/3)
**Date**: 2026-09-04
**Status**: done
**Complexity**: small

## What

The constitution said, in §III: *"No CI/CD pipeline exists yet; quality gates are
manual."* That was the root cause of the v1.2.0 release: eight defects reached
`main`, and **four were found only because someone installed the extension by
hand**. A gate that nothing forces anyone to run is not a gate.

Automate what can be checked mechanically: the manifest, the install result and
the published artifact. Not what the commands do — see § Out of scope.

## Context

| File | Role |
| --- | --- |
| [.github/workflows/validate.yml](../../.github/workflows/validate.yml) | New — 2 jobs, on every PR and on push to `main`. **Blocking** |
| [.github/workflows/upstream-compat.yml](../../.github/workflows/upstream-compat.yml) | New — the same smoke test against spec-kit `main`, weekly. **Advisory** |
| [.github/scripts/validate-extension.sh](../../.github/scripts/validate-extension.sh) | New — 13 static checks, also runnable locally |
| [.github/scripts/assert-install.sh](../../.github/scripts/assert-install.sh) | New — smoke-test assertions, shared by both workflows |
| [.specify/memory/constitution.md](../../.specify/memory/constitution.md) | Modify — §III, § Quality Gates, § Code Boundaries, § Governance |

`.github/` is already in `.gitattributes` (`export-ignore`) and in `.extensionignore`,
so none of this reaches the consumer or the published archive. Verified: 0
entries in `git archive`.

## Requirements

1. Every check names the real blocker it would have caught. A validator whose
   reason cannot be traced gets deleted at its first false positive.
2. The smoke-test assertions derive from the **manifest**, not from fixed numbers:
   adding a sixth command must not require editing CI.
3. The static script runs **locally** without GitHub. The cheapest gate is the one
   that runs before you push.
4. `permissions: contents: read`. The workflow needs nothing more.
5. spec-kit **pinned to a tag**, not to `main`.
6. Two repository invariants go from trusted to mechanical:
   - No hook declares arguments (that *is* FR-022: it keeps `--force`
     unreachable from an automatic trigger). Until now, only a YAML comment
     asking nicely guaranteed it.
   - The *Configuration Validation Rules* block is byte-identical in the three
     commands that duplicate it. §I forbids extracting it to a shared file, so
     duplication is only safe while the copies cannot drift.
7. The constitution stops claiming there is no CI, and states **what it does not cover**.

## Plan

1. `validate-extension.sh` with 13 checks in five sections, each annotated in the
   code with its blocker.
2. `validate.yml` with two jobs: `validate` (fast, no CLI) and `smoke` (installs
   spec-kit and runs a real `extension add` into a clean project).
3. **Negative-test the validator**: reintroduce each defect and confirm it
   fails. A validator that has only ever been seen passing is not verified.
4. Amend the constitution to 1.1.0, with the rationale recorded in the file itself.
5. Open the PR and check that the workflow runs **on itself**.

## Decisions

**spec-kit pinned to `v1.0.4`, not to `main` — and a separate job that does watch `main`.**
Unpinned, an incompatible upstream change lands as a red build on an unrelated
PR, and its author wastes time debugging their own change. This is not
hypothetical: during 1.4.0 development, `specify init --ai` became
`--integration`, and the first smoke test failed because of it.

But pinning has its own failure mode: you stop finding out that upstream broke
you, until the day you bump the pin and inherit all the damage at once. That is
why `upstream-compat.yml` runs the **same** smoke test against `main` weekly. It
can go red without bothering anyone: it does not run on `pull_request` and is
not a required check. A red there means one thing only: upstream changed
something this extension depends on. Decide, and bump `SPEC_KIT_REF` on purpose.

**The smoke assertions live in one file.** Both workflows use `assert-install.sh`.
If they were duplicated, the compatibility job could pass a check the blocking
one no longer runs, which is worse than not having it. Extracting is fine here,
because these are CI scripts: §I's prohibition applies to the installed
package, not to this.

**An action's runtime is not chosen from the workflow.** The action declares it
in its own `action.yml` (`runs.using`), and `actions/setup-node` does not change
it: that sets up Node for *your* code, not the runtime of third-party actions.
The first version of this CI pinned `setup-uv@v6`, which declares `node20`, and
the resulting warning was documented as "it will go away when upstream ships a
node24 build". That was false: `v7.0.0` is titled *"node24 and a lot of
bugfixes"* and already existed. The warning came from our own old version, four
majors behind. Now `v10.0.1`; the v9/v10 changes only touch cache defaults,
irrelevant with `enable-cache: false`.

**Exact version, not a floating major.** `setup-uv` stopped publishing major tags
in `v8.0.0` (*"Immutable releases and secure tags"*): `v7` is the last one that
exists, and `@v10` does not resolve. The first attempt at this bump used `@v10`
and failed in 3 seconds, with CI catching a mistake in CI itself. Pinning
exactly was also the right call: in their scheme those tags are immutable.

**Audit every action, not just the one that warned.** Checking that every
`uses:` actually resolved turned up a second one on `node20` that nobody had
looked at: `actions/upload-artifact@v5`. It moves to `v7`. The lesson: chasing
the annotation on screen leaves behind the ones that have not fired yet.

**The `[P]` markers do not apply.** The two `validate.yml` jobs are independent
and GitHub already runs them in parallel.

**Duplicating the validation rules is still correct.** Check 13 does not suggest
refactoring toward a shared file: spec-kit would not install it and every
command would break at runtime. What it does is make the duplication safe.

## Tasks

- [x] T1 `validate-extension.sh` — 13 checks, each annotated with its blocker
- [x] T2 `validate.yml` — `validate` job and `smoke` job, `contents: read`
- [x] T3 Smoke assertions derived from the manifest, not hardcoded
- [x] T4 Negative test: 6 defects reintroduced, all 6 caught
- [x] T5 Constitution → 1.1.0, with the rationale recorded inline
- [x] T6 PR opened; workflow green on itself (validate 4s, smoke 10s)
- [x] T7 Bump actions to v5/v6 and turn off the uv cache (useless here)
- [x] T8 Branch protection: both checks become **required**
- [x] T9 Extract `assert-install.sh` — a single copy for both workflows
- [x] T10 `upstream-compat.yml` — weekly smoke test against spec-kit `main`, advisory
- [x] T11 Migrate the classic protection to **rulesets**
- [x] T12 Tag ruleset: `refs/tags/v*` immutable

## Done When

- [x] `bash .github/scripts/validate-extension.sh` passes 13/13 locally
- [x] Both jobs green on real runners
- [x] `git archive` still contains no `.github/`
- [x] The constitution no longer says there is no CI
- [x] The checks are **blocking**, not just informational
- [x] `upstream-compat` does not run on `pull_request` — verified, it cannot
      block anyone
- [x] Deleting and moving a `v*` tag both fail — verified with real pushes
      against a throwaway tag, not against a release

## What testing the test itself found

Counting every bullet in the install output gave **6** commands instead of 5:
the scaffolded config also gets a bullet. That would have been a **false red on
every correct PR**. Fixed to `grep -cE '• speckit\.'`.

That is the whole argument for T4. A validator that has only ever been seen
passing is not verified: it is untested.

## Out of scope

**None of this checks what a command *does*.** Agent prompts are interpreted by
a model at runtime, so no compiler or linter catches a contradictory
instruction: it just produces wrong behavior, silently. Each feature's
`quickstart.md` remains the only behavioral check.

**CI protects the package, not the prose.** § Quality Gates says so explicitly,
so that nobody mistakes a green build for a working feature.

## Pending

- `strict: true` still requires the branch to be up to date before merging. With
  a single maintainer that is minor friction, and it guards against a green PR
  that breaks on merge.
- `upstream-compat` has not run on its schedule yet: it fires the first Monday
  at 06:00 UTC. It can be forced sooner with `gh workflow run upstream-compat.yml`.
- The automatic migration split `main`'s protection into **two** rulesets:
  `main-1` (deletion and force-push, no bypass) and `main-2` (required checks,
  admin bypass). That is faithful to what existed, since the bypass was the old
  `enforce_admins: false`, but it is asymmetric: an admin can skip the checks
  and cannot delete the branch. Merging the two is pending if it gets in the way.

## Protection: from classic branch protection to rulesets

The original protection was applied with `PUT /branches/main/protection`, the
classic API. It lives under *Settings → Branches*, **not** under *Settings →
Rules → Rulesets*, which is a separate system that coexists with it. An empty
rulesets screen does not mean there is no protection.

**Why migrate.** For one concrete reason, not an aesthetic one: rulesets protect
**tags**, and classic protection cannot. This extension is distributed through a
`download_url` that points at a tag; if `v1.4.0` moves or is deleted, what
people download changes without anyone noticing. Only a ruleset closes that
hole.

`Release tags are immutable` covers `refs/tags/v*` with `deletion`,
`non_fast_forward` and `update`. All three are needed: `non_fast_forward` only
stops non-fast-forward moves, so without `update` a tag could be re-pointed at a
descendant commit with no resistance.

**No bypass, on purpose.** Deleting a published tag should take a deliberate
act: disable the ruleset, delete, re-enable it. That is the only way.
