---
description: "Task list for Context Budget & Trust Model"
---

# Tasks: Context Budget & Trust Model

**Input**: Design documents from `/specs/005-context-budget-trust/`
**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

**Tests**: No automated test tasks. Constitution §III waives a test framework for agent prompts —
a model interprets them at runtime, so nothing mechanical can assert what a command *does*. The
quality gate is the manual walkthrough in [quickstart.md](quickstart.md), executed by Phase 6.

## Story axis

[spec.md](spec.md) carries a User Scenarios section, so its three stories are the axis directly.

| Label | Story | Priority | Requirements | Independent test |
|-------|-------|:--------:|--------------|------------------|
| **US1** | Bound what the agent is asked to read | P1 | FR-001 … FR-012a, FR-016, FR-019 … FR-023, FR-033 | [quickstart.md](quickstart.md) steps 2, 3, 4, 6, 7, 8, 9 |
| **US2** | See what was withheld, and why | P1 | FR-013 … FR-015, FR-017, FR-018, FR-032, FR-032a, FR-034, FR-035 | [quickstart.md](quickstart.md) steps 1, 5, 10, 11 |
| **US3** | Understand what merging a config change grants | P2 | FR-024 … FR-031 | [quickstart.md](quickstart.md) step 12 |

US1 and US2 are **both P1 and inseparable in release terms** — the spec's own reasoning is that a
budget which trims the corpus without saying so converts a visible context overflow into an
invisible knowledge gap. "MVP = US1" below is an implementation checkpoint, not a shippable state.

US3 is genuinely independent: it changes no behaviour and could ship alone.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel — different files, no dependency on an incomplete task
- **[Story]**: US1 / US2 / US3. Setup, Foundational, and Polish carry none.

## Path conventions

No `src/` or `tests/` tree exists and none will be created. The deliverable is agent-prompt
Markdown plus a YAML manifest and schema:

- `commands/*.md` — the source tree
- `config-template.yml` — the user-facing schema
- `extension.yml` — the package manifest

**`commands/speckit.knowledge.sync.md` is the bottleneck.** Thirteen tasks modify it — T003, T005,
T006–T011 and T014–T018 — and T025 reads it again to audit the trust model, so most of this feature
is inherently serial. That is a property of the design, not of the task list — the budget lives in
one pipeline, in one file. Parallelism is available only where a task touches `search.md`,
`status.md`, `configure.md`, or the documentation files.

## Two deviations from [plan.md](plan.md), stated rather than silent

1. **The version bump moves from Phase 1 to Phase 6.** The plan said "`extension.yml` and
   `config-template.yml` first". For this feature `extension.yml`'s *contract* — commands and
   hooks — does not change at all; only `version` does, and that is release metadata coupled by
   Quality Gates §3, §4, and §6 to the README badge and the CHANGELOG entry. Moving all three
   into one Phase 6 task keeps the gate-coupled artifacts consistent at every point in the branch
   rather than inconsistent from Phase 1 until the end. `config-template.yml`, which *is* the
   schema contract, still comes first.
2. **The three copies of the validation block are one task (T003), not three.** Feature 004 split
   the equivalent work into three `[P]` tasks plus a diff check. That predates Constitution
   Quality Gate §11, which now mechanically asserts byte-identity on every pull request. One task
   makes a partial update impossible rather than merely detectable.

---

## Phase 1: Setup

**Purpose**: Establish a clean baseline and declare the schema contract before anything consumes it.

- [X] T001 Run `.github/scripts/validate-extension.sh` against the unmodified tree and record that it passes, so any later gate failure is attributable to this feature rather than pre-existing
- [X] T002 Document both new optional keys in `config-template.yml`: top-level `max_items` / `max_bytes`, and the same two per source, each as a commented example in the existing Example 1–6 style (FR-001, FR-002). State in the comments that a per-source value is a **sub-ceiling that can only lower**, never raise, the project value — and that this differs deliberately from `max_cache_age`, whose per-source value replaces the project value (FR-003). State that an absent key means **no limit**, that the budget is opt-in, and that **no default value is applied** — an upgrading project must observe byte-identical behaviour (FR-004, FR-023). Keep `schema_version: "1.0"` unchanged (FR-005). Source: [contracts/knowledge-config.schema.md](contracts/knowledge-config.schema.md) §§ 1, 3, 5

**Checkpoint**: `specify extension add <path> --dev` scaffolds a config that still parses.

---

## Phase 2: Foundational (blocking prerequisites)

**Purpose**: Read-time validation for the two new fields. Every story reads
`knowledge-config.yml`, and neither field can be consumed safely until its rule exists.
**No story work may begin until this phase is complete.**

- [X] T003 Add the two new rows to the `## Configuration Validation Rules` field table in **all three** copies — `commands/speckit.knowledge.configure.md`, `commands/speckit.knowledge.sync.md`, `commands/speckit.knowledge.status.md` — in a single change (FR-019): `max_items` (optional, `^[0-9]+$`, `>= 1`) and `max_bytes` (optional, `^[0-9]+(kb|mb)$`). Include the note that `0` is rejected rather than honoured, because a zero ceiling would silently strip the entire corpus. Source: [data-model.md](data-model.md) § 4
- [X] T004 Verify the three blocks modified by T003 are byte-identical by extracting and diffing them. Constitution Quality Gate §11 asserts this on every pull request, and §I forbids extracting the block to a shared file — spec-kit would not install it and every command would break at runtime in a consumer project
- [X] T005 Extend step 1 of `commands/speckit.knowledge.sync.md` ("Read and validate configuration") with the project-wide vs per-source failure asymmetry: a malformed **per-source** ceiling skips only that source naming field and value (FR-020); a malformed **project-wide** ceiling is reported and treated as unconfigured (FR-021). Both exit 0. State why the two differ — a per-source failure has a natural blast radius, a project-wide one does not, and failing closed would empty the corpus on one typo

**Checkpoint**: a config carrying either new key parses, validates, and is rejected correctly when malformed — with no budget behaviour implemented yet.

---

## Phase 3: User Story 1 — Bound what the agent is asked to read (P1)

**Goal**: The index references no more than the configured ceilings allow, chosen by a rule the
user can reproduce on paper.

**Independent test**: [quickstart.md](quickstart.md) steps 2, 3, 4, 6, 7, 8, 9 — a corpus that
substantially exceeds the budget yields an index within both ceilings, identically on every run
and on a second machine.

⚠️ **T006–T011 all modify `commands/speckit.knowledge.sync.md` and are strictly sequential.**

- [X] T006 [US1] Add a `### Corpus Measurement` subsection to `## Algorithm Reference` in `commands/speckit.knowledge.sync.md`: per-item byte size via `wc -c < <file>`, summed per source and project-wide. Size is measured over **the content the agent is instructed to read**, never over the index document that references it (FR-010). State explicitly that `du` (reports blocks; default unit differs GNU vs BSD) and `stat` (`-c%s` vs `-f%z`) are **forbidden** because they would make the same corpus measure differently on two machines and break FR-007. Source: [research.md](research.md) § R1
- [X] T007 [US1] Add a `### Context Budget Allocation` subsection to `## Algorithm Reference` in `commands/speckit.knowledge.sync.md` giving the effective-limit resolution (`min` of the source's own value and its share) and the four-step progressive-fill algorithm, run independently per dimension, with the remainder distributed in ascending **label** order. The rule is fixed and owned by the extension — **no configuration value may influence which items are chosen** (FR-007a) — and must not let declaration order starve a source (FR-008). Note that labels are unique by construction (feature 004, FR-028), so the tiebreak can never be ambiguous. Source: [data-model.md](data-model.md) §§ 2.1, 2.2
- [X] T008 [US1] Insert **step 7a "Apply the context budget"** into `commands/speckit.knowledge.sync.md`, between conflict detection (step 7) and index writing (step 8), implementing selection as the longest path-ordered prefix fitting **both** the item ceiling and the size ceiling (FR-006). State that step 7a operates on the assembled corpus regardless of how each source's content was obtained — freshly fetched, served from a policy-fresh cache, or served from a stale cache after an unreachable source (FR-011) — because the agent reads one index in all three cases. Record why path order rather than smallest-first: smallest-first packs more, but adding one large file would silently change which unrelated small files survive, defeating FR-007b. Source: [data-model.md](data-model.md) §§ 2.3, 3.1, 3.2
- [X] T009 [US1] Add conflict reconciliation to step 7a of `commands/speckit.knowledge.sync.md` (FR-033): if not every version of a conflicting path was selected, withdraw **all** versions; do **not** reallocate the freed capacity; name any source left empty by the withdrawal. State that reuse is refused because it would make the result depend on the selection's own pass count, breaking FR-007b
- [X] T010 [US1] Update step 8 of `commands/speckit.knowledge.sync.md` to write only the selected subset, and add an explicit note at step 6 that `.manifest.json` is written **before** the budget and therefore keeps the **complete** item list — this is what makes FR-012a, FR-017, and FR-034 satisfiable at once and must not be "optimised" into a budgeted manifest. Source: [data-model.md](data-model.md) § 1.2
- [X] T011 [US1] Add rows to `## Error cases summary` in `commands/speckit.knowledge.sync.md` for every new path: malformed ceiling (per source / project-wide), ceiling of `0`, per-source ceiling above the project ceiling, single item exceeding the size ceiling, item ceiling below the source count, conflict pair that cannot fit, budget configured but corpus fits. Exit code `0` in every row (FR-022). Source: [contracts/commands.md](contracts/commands.md) § 4
- [X] T012 [P] [US1] Update `commands/speckit.knowledge.configure.md` to accept and validate `max_items` / `max_bytes`, and to report a clamp — not an error — when a per-source value exceeds the project ceiling (FR-003a). Include the message form `ℹ️  <label>: max_items <N> exceeds the project ceiling of <M>; using <M>.` and state that clamping rather than skipping is deliberate: the value is well-formed and has exactly one safe reading
- [X] T013 [P] [US1] Add a `## Context budget` section to `README.md` documenting both keys, both scopes, the sub-ceiling semantics, and — required by FR-007b — the progressive-fill selection rule in enough detail that a user can predict their own index by hand. Include a worked three-source example

**Checkpoint**: US1 is independently testable. A budget binds, the ceilings hold, the result is
reproducible, and nothing yet reports what was left out.

---

## Phase 4: User Story 2 — See what was withheld, and why (P1)

**Goal**: Every withholding is visible on the surface appropriate to its reader, and a withheld
item remains reachable.

**Independent test**: [quickstart.md](quickstart.md) steps 1, 5, 10, 11 — counts and sizes in the
output, the partial marker in the index and the agent block, identities on demand, and a search
that still finds a withheld item.

⚠️ **T014–T018 all modify `commands/speckit.knowledge.sync.md` and are strictly sequential.**
T019 and T020 touch different files and are parallel with each other and with T014–T018.

- [X] T014 [US2] Extend step 9 of `commands/speckit.knowledge.sync.md` with the withholding report: per-source injected-of-total counts and sizes plus the limit applied (FR-013, FR-018), individually named oversized items with their size (FR-009), starved sources with the reason (FR-008a), and conflict withdrawals as one event rather than two exclusions (FR-033). Source: [contracts/commands.md](contracts/commands.md) § 3.2
- [X] T015 [US2] Extend step 8 of `commands/speckit.knowledge.sync.md` to add `withheld_items`, `withheld_bytes`, `limit_items`, and `limit_bytes` to the `knowledge-index-meta` comment and a `⚠️ Partial` line to the header (FR-014). All five MUST be **omitted entirely** when nothing was withheld, so a non-binding budget yields a byte-identical index (FR-016). State that no withheld path is ever named here, because the index is the one document the agent reads in full. Source: [data-model.md](data-model.md) § 1.3
- [X] T016 [US2] Add the partial-corpus line to the Context Output block in step 10 of `commands/speckit.knowledge.sync.md`, emitted only when something was withheld (FR-015). The block is otherwise literal and unchanged; the rules stay exactly 70 × `═`. Source: [contracts/commands.md](contracts/commands.md) § 3.6
- [X] T017 [US2] Extend the `## --verbose flag` section of `commands/speckit.knowledge.sync.md` to list every withheld path per source (FR-034), beside the existing loaded-files listing. State why the list is absent from the default output — sync runs at four automatic points per feature cycle — and absent from the index, which is a different reason. In the same section, state that **no flag raises or bypasses the budget** (FR-012), that `--force` bypasses only the cache freshness policy, and that adding a bypass flag later would not be caught by Quality Gate §10, which protects `--force` by asserting hooks declare no arguments but would not protect a manually invoked budget flag
- [X] T018 [US2] Add the advisory warning to `commands/speckit.knowledge.sync.md` for an unbudgeted corpus above **200 items or 2 mb** (FR-032, FR-032a). It must name both the measured value and the threshold, alter nothing, and exit 0 — the same standing as the existing "more than ten sources" warning. Record that the figures are calibration, not contract. Source: [research.md](research.md) § R6
- [X] T019 [P] [US2] Change `commands/speckit.knowledge.search.md` step 1 to build its inventory from the per-source `.manifest.json` files instead of `knowledge-index.md`, and step 4 to iterate that inventory (FR-035). **Without this, FR-017 and SC-006 are false and a withheld item becomes unreachable rather than un-injected** — the distinction the whole feature rests on. Preserve the existing three-way missing-inventory messaging, evaluated against manifests. Source: [research.md](research.md) § R5
- [X] T020 [P] [US2] Add a Budget column to the status table in `commands/speckit.knowledge.status.md` showing contributed-of-total per source, and a footer naming the limit applied to each — share, per-source value, or none (FR-018). Mirrors the existing rule that a reported freshness state always names its threshold. Source: [contracts/commands.md](contracts/commands.md) § 3.7

**Checkpoint**: US1 + US2 together are a shippable increment. Nothing is withheld silently, and
nothing withheld is lost.

---

## Phase 5: User Story 3 — Understand what merging a config change grants (P2)

**Goal**: A reviewer can answer what a merged config line causes, what is and is not executed, and
what the extension does not defend against — from the README alone.

**Independent test**: [quickstart.md](quickstart.md) step 12.

- [X] T021 [US3] Add a `## Trust model` section to `README.md` covering: that merging a config change causes the referenced location to be fetched on every machine and automated environment that later syncs, including via hooks the reviewer may never run (FR-025); the four exposures — network request from every machine, credential presentation to a configured host, prompt injection through uninspected markdown, and **symlink following**, where a fetched `.md` may link to a file outside the repository that the agent is then instructed to read (FR-026); and what does **not** happen — content is read as data, never executed, with no build step, script, or repository hook run from a source (FR-027)
- [X] T022 [US3] Add the defense inventory to the `## Trust model` section of `README.md` (FR-028): the seven verified-present defenses from [research.md](research.md) § R8, each stated **with what it does not cover**. A defense listed without its limits reads as a guarantee the extension does not make
- [X] T023 [US3] Add reviewer guidance to the `## Trust model` section of `README.md` (FR-029): a change to `knowledge-config.yml` is security-relevant, and here is what to check before approving one — the location, the revision, the path filter, and whether the source is one the team controls
- [X] T024 [P] [US3] Add a pointer to the trust model in `config-template.yml`'s header comment block (FR-030), so someone editing the file directly meets it without needing to know it exists
- [X] T025 [US3] Audit the finished `## Trust model` section against `commands/speckit.knowledge.sync.md` (FR-031, SC-014): every named defense must correspond to behaviour the extension applies **today**, and every exposure named as undefended must have no defense claimed against it. Symlink following in particular must be described as **absent**, not mitigated — it is a real data-exfiltration path the project has chosen not to close in this feature, and naming it is the requirement

**Checkpoint**: US3 is complete and independently verifiable. No behaviour changed.

---

## Phase 6: Polish & release

- [X] T026 Bump the version in three coupled places as one change: `extension.extension.version` in `extension.yml` from `1.4.0` to `1.5.0`, the status badge in `README.md`, and a new `## [1.5.0]` section in `CHANGELOG.md` under Added / Fixed / Changed / Compatibility. Quality Gates §3, §4, and §6 assert these three agree; moving them together keeps them consistent at every point. Record in the CHANGELOG that the search change is a `fix:` — it repairs a guarantee the budget would otherwise have broken
- [X] T027 Run `.github/scripts/validate-extension.sh`. Quality Gate §11 (three validation blocks byte-identical) and §6 (badge matches manifest) are the two most likely to fail after this feature
- [X] T028 Install into a clean consumer project with `specify extension add <path> --dev` and assert: five commands registered, config scaffolded with no "Config templates not scaffolded" warning, version reported as `1.5.0`, four hooks auto-registered, none declaring arguments
- [X] T029 Execute [quickstart.md](quickstart.md) steps 0 through 13 end to end against three deliberately asymmetric source repositories, confirming all twenty Success Criteria. **Step 10 is the one that matters most** — it is the only check that FR-035 actually landed, and if search still reads the index it will fail there and nowhere else
- [X] T030 Confirm exit code `0` at every step of T029, including the deliberately adverse ones — oversized item, budget below the source count, malformed ceilings (FR-022)

---

## Dependencies

```text
Phase 1 (T001–T002)
      ↓
Phase 2 (T003 → T004 → T005)          ← blocks everything
      ↓
Phase 3 US1 (T006 → T007 → T008 → T009 → T010 → T011)   [sync.md, serial]
        T012 [P] configure.md · T013 [P] README.md
      ↓
Phase 4 US2 (T014 → T015 → T016 → T017 → T018)          [sync.md, serial]
        T019 [P] search.md · T020 [P] status.md
      ↓
Phase 5 US3 (T021 → T022 → T023 → T025)  [README.md, serial]
        T024 [P] config-template.yml
      ↓
Phase 6 (T026 → T027 → T028 → T029 → T030)
```

**Story independence**: US3 depends on nothing in US1 or US2 and could be built first. US2 depends
on US1 only because there is nothing to report until something is withheld.

## Parallel opportunities

| Phase | Parallel set | Why safe |
|-------|-------------|----------|
| 3 | T012, T013 | `configure.md` and `README.md`; neither is touched by T006–T011 |
| 4 | T019, T020 | `search.md` and `status.md`; different files from each other and from T014–T018 |
| 5 | T024 with T021–T023 | `config-template.yml` vs `README.md` |
| — | Whole of US3 with US1/US2 | Documentation only; touches no command file |

Everything else is serial because it lands in `commands/speckit.knowledge.sync.md`.

## Implementation strategy

**Checkpoint 1 — US1 (T001–T013).** The budget enforces. Verifiable, but **not shippable**: a
corpus is being trimmed with no statement of what was removed, which is the failure mode the
specification names as worse than the overflow it prevents.

**Checkpoint 2 — US1 + US2 (T001–T020).** The first genuinely shippable state. Nothing is withheld
silently and nothing withheld is lost.

**Checkpoint 3 — all three (T001–T030).** Release.

**Suggested MVP**: US1 + US2 together. Treating US1 alone as the MVP would ship the exact silent
truncation the spec was written to prevent.

## Notes

- `[P]` = different files, no dependency on an incomplete task
- `[Story]` maps a task to a user story for traceability
- Commit after each task or logical group, using Conventional Commits (Constitution §IV):
  `feat(config):`, `feat(sync):`, `fix(search):`, `docs(readme):`, `chore(release):`
- No task adds a script. Constitution §III: if it can be expressed as Markdown, it must be
- **T019 is the highest-risk task to skip.** It looks like a refactor and is not — it is what
  keeps a withheld item findable, and its absence fails only at quickstart step 10
