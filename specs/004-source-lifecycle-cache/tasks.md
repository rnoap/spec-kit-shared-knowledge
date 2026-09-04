---
description: "Task list for Source Lifecycle & Cache Policy"
---

# Tasks: Source Lifecycle & Cache Policy

**Input**: Design documents from `/specs/004-source-lifecycle-cache/`
**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

**Tests**: No automated test tasks. Constitution §III waives a test framework for agent
prompts; the quality gate is the manual walkthrough in [quickstart.md](quickstart.md), which is
executed by the Phase 6 tasks.

## Story axis — read this first

[spec.md](spec.md) has **no User Stories section** — it was written with the Companion turbo
profile, which omits that section. The three capabilities named in its Overview are the
independently testable increments, so they serve as the story axis:

| Label | Capability | Requirements | Independent test |
|-------|-----------|--------------|------------------|
| **US1** | Source lifecycle | FR-001 … FR-008, FR-028, FR-031 | [quickstart.md](quickstart.md) steps 1, 2, 7, 9 |
| **US2** | Per-source revision pinning | FR-009 … FR-015, FR-026 | [quickstart.md](quickstart.md) steps 3, 5, 11 |
| **US3** | Cache freshness policy | FR-016 … FR-022, FR-027 | [quickstart.md](quickstart.md) steps 4, 8, 12 |

They are ordered by dependency, not by business priority. The spec's final Assumption states
that **all three ship together**, so "MVP = US1" describes an implementation checkpoint, not a
release. See § Implementation Strategy.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel — different files, no dependency on an incomplete task
- **[Story]**: US1 / US2 / US3 per the table above. Setup, Foundational, and Polish carry none.

## Path conventions

This repository has no `src/` or `tests/` tree and will not grow one. The deliverable is
agent-prompt Markdown plus a YAML manifest and schema:

- `commands/*.md` — the source tree
- `config-template.yml` — the user-facing schema
- `extension.yml` — the package manifest

Task ordering across phases follows **Constitution §II** (source-of-truth hierarchy):
`extension.yml` → `config-template.yml` → `commands/*.md` → `README.md`.

---

## Phase 1: Setup (manifest and schema)

**Purpose**: Declare the contract before anything implements it. Constitution §II puts these
first; every later phase reads them.

- [ ] T001 Register the fifth command in `extension.yml` under `provides.commands`: `name: speckit.knowledge.remove`, `file: commands/speckit.knowledge.remove.md`, `description: "Remove, disable, or re-enable a configured knowledge source"` — per [contracts/commands.md](contracts/commands.md) § extension.yml deltas
- [ ] T002 Bump `extension.extension.version` in `extension.yml` from `1.3.0` to `1.4.0` (minor — additive and backward-compatible)
- [ ] T003 Verify the `hooks:` block in `extension.yml` still declares **no arguments** on all four entries, and add a comment stating that adding one would make `--force` reachable from an automatic trigger and break FR-022
- [ ] T004 Document the two new optional keys in `config-template.yml`: top-level `max_cache_age`, and per-source `revision` and `max_cache_age`, each as a commented example following the existing Example 1–5 style. Keep `schema_version: "1.0"` unchanged (FR-025)

**Checkpoint**: `specify extension add <path> --dev` scaffolds a config that still parses, and
`specify extension list` reports `Commands: 5`. The command file does not exist yet, so expect a
missing-file warning — T012 resolves it.

---

## Phase 2: Foundational (blocking prerequisites)

**Purpose**: Read-time configuration validation (FR-029, FR-030). Every capability reads
`knowledge-config.yml`, and the two new fields cannot be consumed safely until their rules
exist. **No US work may begin until this phase is complete.**

**⚠️ Security-critical**: the "must not begin with `-`" rule prevents argument injection into
`git`. A `revision` of `--upload-pack=<command>` arriving via a hand-edited or pull-requested
config is remote code execution. See [contracts/knowledge-config.schema.md](contracts/knowledge-config.schema.md) § Security notes.

- [ ] T005 [P] Add a `## Configuration Validation Rules` section to `commands/speckit.knowledge.configure.md`, transcribing the six-row field table from [contracts/knowledge-config.schema.md](contracts/knowledge-config.schema.md) verbatim, with a header noting the block is duplicated across commands by design
- [ ] T006 [P] Add the identical `## Configuration Validation Rules` section to `commands/speckit.knowledge.sync.md`, immediately after the existing `## Algorithm Reference` section
- [ ] T007 [P] Add the identical `## Configuration Validation Rules` section to `commands/speckit.knowledge.status.md`, immediately after its existing `## Algorithm Reference` section
- [ ] T008 Verify the three blocks added by T005–T007 are byte-identical (`diff` the extracted sections). Constitution §I forbids extracting them to a shared file — spec-kit would not install it and every command would break at runtime in a consumer project ([research.md](research.md) § R5)
- [ ] T009 Rewrite step 1 of `commands/speckit.knowledge.sync.md` ("Read and validate configuration") to apply the full rule set per source, and to skip **only the offending source** with a message naming the field and its value while every other source proceeds and the command still exits 0 (FR-030)
- [ ] T010 Update `## Error cases` in `commands/speckit.knowledge.configure.md` to replace the two legacy `path_filter` rows with the full six-field rule set, keeping every row's exit code at 0
- [ ] T011 Add a `--` separator to every `git` invocation in `commands/speckit.knowledge.sync.md` that interpolates a config value — `git clone … -- "$url" "$dir"`, `git sparse-checkout set -- "$p1" "$p2"` — as defense in depth behind T005–T007 validation

**Checkpoint**: [quickstart.md](quickstart.md) step 10 passes — a hand-edited `revision` of
`--upload-pack=touch /tmp/pwned` skips its own source, leaves `/tmp/pwned` uncreated, lets the
other source sync, and exits 0.

---

## Phase 3: US1 — Source lifecycle

**Goal**: A user can remove, disable, or re-enable a knowledge source without hand-editing YAML.

**Independent test**: [quickstart.md](quickstart.md) steps 1, 2, 7, and 9 — remove purges config
and cache in one command; disable hides a source while retaining its cache; re-enable requires
no re-download; emptying the configuration deletes the index; label collisions and ambiguous
URLs are both refused.

- [ ] T012 [US1] Create `commands/speckit.knowledge.remove.md` with the standard house structure (frontmatter `description`, `## speckit.knowledge.remove`, `**Purpose**`, `**Arguments**`, `## Behavior`, `## Error cases`, `## Side effects`, `## Exit codes`), matching the layout of `commands/speckit.knowledge.configure.md`
- [ ] T013 [US1] In `commands/speckit.knowledge.remove.md`, specify identifier resolution: match `label` exactly first, fall back to `url` only when it resolves to exactly one source, and on a multi-match list the candidates and change nothing (FR-001)
- [ ] T014 [US1] In `commands/speckit.knowledge.remove.md`, specify the three modes — default purge (delete entry **and** `cache/<slug>/`), `--disable` (set `enabled: false`, retain both), `--enable` (set `enabled: true`) — with the exact output blocks from [contracts/commands.md](contracts/commands.md) § 5 (FR-002 … FR-005)
- [ ] T015 [US1] In `commands/speckit.knowledge.remove.md`, specify the no-argument path: list every configured source with its current state and prompt for a selection (FR-006); and the no-match path: report clearly, list the configured labels, change nothing, exit 0 (FR-007)
- [ ] T016 [US1] Add a `## --verbose flag` section to `commands/speckit.knowledge.remove.md` printing the resulting YAML after write, matching the existing convention in the other four command files
- [ ] T017 [US1] Add label-uniqueness enforcement to `commands/speckit.knowledge.configure.md`: before writing, detect a derived-or-supplied label that already exists and resolve the collision, so no two sources can ever share a label (FR-028). Cover both reachable causes — two local paths sharing a final component, and one repository added twice at different revisions
- [ ] T018 [US1] Add the empty-configuration path to `commands/speckit.knowledge.sync.md`: when no **enabled** sources remain, report the project as having no configured knowledge, delete any existing `knowledge-index.md`, suppress the Context Output Block, and exit 0 (FR-031, [data-model.md](data-model.md) § 5)
- [ ] T019 [US1] Confirm `commands/speckit.knowledge.sync.md` already skips `enabled: false` sources and contributes no items from them to the index (FR-008). Existing behavior — verify and add a cross-reference to FR-008 rather than reimplementing

**Checkpoint**: US1 is independently deliverable. Removal, disable, and re-enable all work; the
index disappears when the last source does.

---

## Phase 4: US2 — Per-source revision pinning

**Goal**: A source can pin a branch, tag, or commit, and two revisions of one repository never
contaminate each other.

**Independent test**: [quickstart.md](quickstart.md) steps 3, 5, and 11 — two revisions hold two
caches with distinct content and no false conflict; an unchanged project upgrades with identical
slugs and zero re-download; a revision change prunes the orphaned directory while a disabled
source's cache survives.

**⚠️ Regression-critical**: T020 is the single most dangerous task in this feature. Getting the
conditional wrong invalidates every existing consumer's cache and breaks FR-024 and SC-005.

- [ ] T020 [US2] Update `### Source Slug Generation` in `commands/speckit.knowledge.sync.md` to make the revision a **conditional** hash component: hash `normalized` alone when no revision is set (byte-identical to 1.3.0), and `printf '%s\n%s' "$normalized" "$revision"` when one is. Document why the separator is a newline and not `@` ([research.md](research.md) § R2)
- [ ] T021 [US2] Mirror the T020 slug change into `commands/speckit.knowledge.status.md`, whose `## Algorithm Reference` section duplicates the algorithm by design
- [ ] T022 [US2] Add the three-tier revision fetch ladder to the cold path of `commands/speckit.knowledge.sync.md`: `--branch` for a branch or tag, empty clone plus `git fetch --depth=1 origin -- <sha>` for a full SHA, one `--unshallow` retry when the server refuses an unadvertised object, then the FR-015 cache fallback ([research.md](research.md) § R6)
- [ ] T023 [US2] Apply the same revision targeting to the warm path of `commands/speckit.knowledge.sync.md`, replacing the unconditional `git checkout origin/HEAD -- .` with a checkout of the declared revision when one is set (FR-012)
- [ ] T024 [US2] Document abbreviated-SHA rejection in `commands/speckit.knowledge.sync.md`: a 7-character prefix is not fetchable by any tier and is not stable, so it is reported as an unresolvable revision rather than silently degrading (FR-015)
- [ ] T025 [US2] Add the `revision` field to the `.manifest.json` schema in `commands/speckit.knowledge.sync.md` (`null` when unpinned), and state that readers treat an absent field as `null` so 1.3.0 manifests need no migration ([data-model.md](data-model.md) § 1.2)
- [ ] T026 [US2] Accept a revision in `commands/speckit.knowledge.configure.md` via `--revision <rev>` and via `<url>@<rev>` parsed on the **last** `@`; require the flag form for SSH URLs, which already contain `@`, and say so rather than guessing (FR-013)
- [ ] T027 [US2] Change the same-URL merge rule in `commands/speckit.knowledge.configure.md`: merge into an existing entry only when the URL **and** the revision both match. Today's URL-only merge would make it impossible to configure two revisions of one repository (FR-009, FR-011)
- [ ] T028 [US2] Add the effective revision to the status table in `commands/speckit.knowledge.status.md`, rendering `default` when none is pinned (FR-014)
- [ ] T029 [US2] Add a `### Repository Identity` subsection to the `## Algorithm Reference` in `commands/speckit.knowledge.sync.md` with the six-step normalization from [research.md](research.md) § R3, and state explicitly that identity is intentionally broader than the slug
- [ ] T030 [US2] Rewrite step 7 (`Detect conflicts`) of `commands/speckit.knowledge.sync.md` to group by repository identity: report a shared path as a conflict only when the identities differ, so two revisions of one repository produce no conflict noise (FR-026)
- [ ] T031 [US2] Add an orphaned-cache prune pass to `commands/speckit.knowledge.sync.md`, running after the per-source loop: delete every `cache/<slug>/` directory whose slug matches **no** configured source, computing the keep-set over enabled **and disabled** sources, and report each removal on its own line (gap G1 — [data-model.md](data-model.md) § 4)

**Checkpoint**: US1 + US2 deliverable together. Revisions are isolated, upgrades are free, and
no cache directory is stranded.

---

## Phase 5: US3 — Cache freshness policy

**Goal**: A sync can skip the network when the cached content is still current, which is what
makes the four automatic hooks added in 1.3.0 affordable.

**Independent test**: [quickstart.md](quickstart.md) steps 4, 8, and 12 — four consecutive syncs
perform one fetch; every source unreachable still surfaces cached knowledge; `status` labels
agree with the configured policy.

- [ ] T032 [US3] Add a `### Cache Freshness Gate` subsection to the `## Algorithm Reference` in `commands/speckit.knowledge.sync.md`: resolve the effective `max_cache_age` (source-level, else top-level, else absent), convert `<N><m|h|d>` to minutes by integer arithmetic, and gate on `find "$manifest" -maxdepth 0 -mmin +<N>`. State why `date` is not used — `date -d` is GNU-only and `date -j -f` is BSD-only ([research.md](research.md) § R4)
- [ ] T033 [US3] State in `commands/speckit.knowledge.sync.md` that the manifest **mtime** is authoritative for the gate while `synced_at` remains the value displayed, and that the manifest is already written last precisely so its mtime marks the instant the cache became valid
- [ ] T034 [US3] Wire the gate into step 4 of `commands/speckit.knowledge.sync.md`, before any network access: a source under policy skips the fetch entirely and reuses its cache (FR-018). With no policy configured, every source fetches exactly as in 1.3.0 (FR-017)
- [ ] T035 [US3] Add the `current` status value and its summary line to step 9 of `commands/speckit.knowledge.sync.md`, reported distinctly from `fresh` so the user can see no network access occurred (FR-019) — format per [contracts/commands.md](contracts/commands.md) § 2
- [ ] T036 [US3] Add `--force` to the `**Arguments**` list and a `## --force flag` section in `commands/speckit.knowledge.sync.md`, composing orthogonally with `--verbose` and `--no-context-output` (FR-021)
- [ ] T037 [US3] Record in the `## --force flag` section that the four `hooks.*` entries declare no arguments, so `--force` is structurally unreachable from an automatic trigger — the same mechanism 003 used for `--no-context-output` (FR-022). Cross-check against T003
- [ ] T038 [US3] Update the emission gate in step 10 of `commands/speckit.knowledge.sync.md` so a freshness-skipped source counts as usable knowledge and the Context Output Block is still emitted (FR-020, [data-model.md](data-model.md) § 5)
- [ ] T039 [US3] State in `commands/speckit.knowledge.sync.md` that an over-age cache remains usable when its source is unreachable — the policy governs whether a refresh is *attempted*, never whether cached content may be *served* (FR-027). Confirm the existing `cached` fallback path already delivers this and cross-reference it
- [ ] T040 [US3] Reconcile the legacy freshness labels in `commands/speckit.knowledge.status.md`: when a source has an effective `max_cache_age` the policy determines `fresh` vs `cached`; the hard-coded 24-hour heuristic survives **only** as the no-policy default, which FR-024 requires. Render the threshold actually used so a label is never unexplained (gap G2)
- [ ] T041 [US3] Add the effective `max_cache_age` to the status output in `commands/speckit.knowledge.status.md`, so a user can see which policy produced each label

**Checkpoint**: all three capabilities complete. The feature is now releasable as a unit.

---

## Phase 6: Polish and release readiness

**Purpose**: Documentation, the constitution amendment the new command forces, and the manual
quality gate. Constitution §II places `README.md` after the command files.

- [ ] T042 [P] Add a fifth row for `speckit.knowledge.remove` to the command table in `README.md`, so it matches `extension.yml#provides.commands` (Quality Gate §5)
- [ ] T043 [P] Add a "Source lifecycle" section to `README.md` documenting remove, `--disable`, and `--enable`, and explaining why re-enabling is free (the cache is retained)
- [ ] T044 [P] Add a "Pinning a revision" section to `README.md` covering the `revision` key, the `@rev` and `--revision` argument forms, the SSH-URL caveat, and the abbreviated-SHA limitation
- [ ] T045 [P] Add a "Cache freshness" section to `README.md` covering `max_cache_age`, its per-source override, the `<N><m|h|d>` format, `--force`, and the fact that a policy never blocks serving a stale cache
- [ ] T046 [P] Document the local-path identity limitation in `README.md`: a local clone is not identified with the remote it was cloned from for conflict-reporting purposes ([research.md](research.md) § R3, deferred item)
- [ ] T047 Add a `## [1.4.0]` section to `CHANGELOG.md` in Keep a Changelog format, with `Added` (fifth command, `revision`, `max_cache_age`, `--force`, cache pruning) and `Changed` (conflict scoping, read-time validation, `status` freshness labels, configure's same-URL merge rule) subsections, and update the footer link definitions
- [ ] T048 Amend Quality Gate §2 in `.specify/memory/constitution.md` from "All four commands are registered" to five. Per § Governance this requires a `docs:` commit carrying the rationale
- [ ] T049 Run [quickstart.md](quickstart.md) Gate 0 in a scratch consumer project: `specify extension add <path> --dev` completes with no error and no "Config templates not scaffolded" warning, and `specify extension list` reports `Commands: 5 | Hooks: 4`
- [ ] T050 Run [quickstart.md](quickstart.md) steps 1–12 end to end and record the result of each Success Criterion. Step 5 (upgrade with identical slugs) and step 10 (argument injection) are the two that must not be skipped
- [ ] T051 Confirm `commands/speckit.knowledge.search.md` needs no change — it reads `knowledge-index.md` rather than `knowledge-config.yml`, so it inherits validation transitively. If that turns out to be false, it must adopt the Phase 2 rule block like the other three
- [ ] T052 Complete the pre-release checklist at the foot of [quickstart.md](quickstart.md): all five Constitution Quality Gates, plus verification that `git archive` of the tag still contains only the publishable file set (the `.gitattributes` `export-ignore` rules added in 1.2.0)

---

## Dependencies

```text
Phase 1 (Setup: T001–T004)
        │  manifest and schema declare what everything else implements
        ▼
Phase 2 (Foundational: T005–T011)      ⚠️ BLOCKS ALL STORIES
        │  every capability reads config; the new fields need rules before use
        ▼
   ┌────┴────────────────────┬─────────────────────────┐
   ▼                         ▼                         ▼
Phase 3 (US1)  ─────────▶ Phase 4 (US2)  ─────────▶ Phase 5 (US3)
lifecycle                 revision pinning          freshness
   │                         │                         │
   └─────────────────────────┴─────────────────────────┘
                             ▼
                  Phase 6 (Polish: T042–T052)
```

**Why the stories are sequential rather than parallel.** They are not independent in the usual
sense — all three edit `commands/speckit.knowledge.sync.md`:

- **US2 → US1**: T031 (prune) must not delete a disabled source's cache, which is the invariant
  T014 establishes.
- **US3 → US2**: T032's gate reads `.manifest.json` at a path derived from the slug, which T020
  changes.
- **US3 → US1**: T038 (emission on freshness skip) and T018 (no emission when empty) are two
  rows of one decision table; writing them out of order produces a contradictory gate.

Running two stories concurrently would mean two agents editing `sync.md` simultaneously.

**Task-level dependencies within phases**

| Task | Blocked by | Reason |
|------|-----------|--------|
| T008 | T005, T006, T007 | Cannot diff blocks that do not exist |
| T009 | T006 | Rewrites the step that consumes the rule block |
| T011 | T009 | Both edit sync's fetch invocations |
| T013–T016 | T012 | Same file must exist first |
| T021 | T020 | Mirrors it |
| T023 | T022 | Warm path mirrors cold-path targeting |
| T030 | T029 | Consumes the identity algorithm |
| T031 | T020, T014 | Needs the new slug and the disable invariant |
| T034 | T032 | Wires in the gate the earlier task defines |
| T037 | T003 | Cross-checks the manifest assertion |
| T040 | T032 | Needs the effective-policy resolution |
| T049–T052 | everything | Manual verification is last |

---

## Parallel execution examples

**Phase 2 — three files, no shared edit region:**

```text
T005  commands/speckit.knowledge.configure.md
T006  commands/speckit.knowledge.sync.md          ← run together
T007  commands/speckit.knowledge.status.md
```

Then T008 alone, to verify the three are byte-identical.

**Phase 6 — five independent README sections plus the CHANGELOG:**

```text
T042  README.md  command table
T043  README.md  source lifecycle
T044  README.md  revision pinning      ← same file; run together only if the
T045  README.md  cache freshness          agent appends distinct sections
T046  README.md  local-path limitation
```

> `[P]` on T042–T046 means "no logical dependency". They share `README.md`, so run them in one
> pass or sequence them — do not dispatch five concurrent writers at one file.

**No parallelism inside US1, US2, or US3.** Each phase is dominated by
`commands/speckit.knowledge.sync.md`, which every task in it edits.

---

## Implementation strategy

### The MVP checkpoint is not a release

The natural MVP is **Phase 1 + Phase 2 + Phase 3 (US1)** — 19 tasks that eliminate hand-editing
YAML to stop consuming a source. It is a genuine, independently testable increment.

It is **not** a shippable release. The spec's final Assumption is explicit:

> The freshness policy is what makes the four synchronization points introduced in 1.3.0
> affordable, and revision pinning is what makes a long-lived cache safe to trust. Shipping them
> separately leaves the extension in a worse state than shipping none of them.

Shipping US1 alone would tag a 1.4.0 that still refetches every source four times per feature
cycle. Treat the US1 checkpoint as a review point, not a version.

### Incremental delivery

1. **Phases 1–2** → foundation. Stop here and run [quickstart.md](quickstart.md) step 10; the
   security control is worth verifying before anything is built on top of it.
2. **+ Phase 3** → US1 checkpoint. Steps 1, 2, 7, 9 pass.
3. **+ Phase 4** → US2 checkpoint. Steps 3, 5, 11 pass. **Step 5 is the regression gate** — if
   slugs changed for unpinned sources, stop and fix T020 before continuing.
4. **+ Phase 5** → feature complete. Steps 4, 8, 12 pass.
5. **+ Phase 6** → releasable. Tag `v1.4.0` only after T052.

### Release sequencing

Version `1.3.0` is implemented but was never tagged or published. Publishing it alone would ship
four automatic sync hooks **without** the freshness policy that makes them affordable — doubling
network cost per feature cycle with no mitigation. Release `1.4.0` directly, and describe the
1.3.0 hooks in its CHANGELOG entry (T047).

### Commit convention

Constitution §IV is non-negotiable. Suggested scopes:

| Phase | Type and scope |
|-------|----------------|
| 1 | `chore(release):` for the version bump, `feat(config):` for the schema keys |
| 2 | `fix(validation):` — this closes a real gap, it is not a new feature |
| 3 | `feat(remove):`, `feat(configure):` |
| 4 | `feat(revision):` |
| 5 | `feat(freshness):` |
| 6 | `docs(readme):`, `chore(changelog):`, `docs(constitution):` |

No `!` on any commit — nothing in this feature is breaking.

---

## Summary

| Phase | Tasks | Count |
|-------|-------|------:|
| 1 — Setup | T001–T004 | 4 |
| 2 — Foundational | T005–T011 | 7 |
| 3 — US1 source lifecycle | T012–T019 | 8 |
| 4 — US2 revision pinning | T020–T031 | 12 |
| 5 — US3 cache freshness | T032–T041 | 10 |
| 6 — Polish and release | T042–T052 | 11 |
| **Total** | | **52** |

**Files touched**: 1 created (`commands/speckit.knowledge.remove.md`), 7 modified
(`extension.yml`, `config-template.yml`, three existing command files, `README.md`,
`CHANGELOG.md`), 1 amended (`.specify/memory/constitution.md`). None deleted.

**Requirement coverage**: all 31 FR and all 10 SC are reachable from at least one task. The two
gaps found during planning are covered by T031 (G1) and T040 (G2); neither has a governing FR,
so `/speckit.analyze` should decide whether the spec is amended to add them.
