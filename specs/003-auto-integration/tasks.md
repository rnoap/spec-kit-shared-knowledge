---
status: ready
feature: auto-integration
---

# Tasks: Auto-Integration with /speckit-specify and /speckit-plan

**Input**: [spec.md](spec.md), [plan.md](plan.md), [data-model.md](data-model.md), [research.md](research.md), [quickstart.md](quickstart.md)

**Tests**: Not requested — verification is the manual walkthrough in [quickstart.md](quickstart.md). No test tasks generated.

**Organization**: Tasks grouped by user story (US1, US2, US3, US4) per the priorities in [spec.md](spec.md) (P1, P1, P2, P3).

**Scope reminder (from [plan.md](plan.md) § "Project Structure")**: This feature modifies exactly four files — no new files, no new commands:

1. [commands/speckit.knowledge.sync.md](../../commands/speckit.knowledge.sync.md)
2. [README.md](../../README.md)
3. [extension.yml](../../extension.yml) — version bump `1.0.0` → `1.1.0`
4. [CHANGELOG.md](../../CHANGELOG.md) — new `## [1.1.0]` section

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no in-flight dependency)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4). Setup/Foundational/Polish phases carry no story tag.

---

## Phase 1: Setup (Preflight)

**Purpose**: Re-read the locked contract and invariants so every downstream edit conforms exactly. No project initialization needed — this is an existing extension.

- [ ] T001 Read [plan.md](plan.md) § "Contract: Context Output Block" end-to-end and record the literal 70×`══` rule, the banner line `📚 SHARED KNOWLEDGE CONTEXT (for the AI agent)`, and the U+203A `›` separator in the citation token — these are the wire format that subsequent edits must reproduce verbatim
- [ ] T002 [P] Read [data-model.md](data-model.md) § "Invariants" (I1–I7) and confirm the four directive fields, their addressee (second person), the canonical paths `.specify/extensions/knowledge/knowledge-index.md` and `.specify/extensions/knowledge/cache/<slug>/...`, and the exit-0 contract
- [ ] T003 [P] Read [research.md](research.md) § R3 to confirm the `--no-context-output` parse pattern mirrors the existing `--verbose` `$ARGUMENTS` token scan in [commands/speckit.knowledge.sync.md](../../commands/speckit.knowledge.sync.md)

**Checkpoint**: Contract, invariants, and flag-parse pattern are loaded. User-story edits can begin.

---

## Phase 2: Foundational — Manifest Version Bump

**Purpose**: Bump `extension.yml#extension.version` first. Both the CHANGELOG entry (Phase 7) and the README rewrite (Phase 5, US3) reference v1.1.0, so the bump must land before either of those edits is finalized.

- [ ] T004 Edit [extension.yml](../../extension.yml): change `extension.version` from `"1.0.0"` to `"1.1.0"`. Do not modify any other field — `provides.commands`, `hooks.before_specify`, `hooks.before_plan`, `requires.speckit_version`, and `config-template`'s `schema_version` are all unchanged per [spec.md](spec.md) § "Extension Impact" and [plan.md](plan.md) § Constitution Check

**Checkpoint**: Manifest is at v1.1.0. README and CHANGELOG can now cite the new version accurately.

---

## Phase 3: User Story 1 — Zero-Config Knowledge Injection in /speckit-specify (Priority: P1) 🎯 MVP

**Goal**: After fresh `specify extension add knowledge --dev <path>` + one configured source + `/speckit-knowledge-sync`, running `/speckit-specify "..."` produces a `spec.md` that cites the configured knowledge by `<source-label> › <relative-path>` without any manual edit to `.specify/extensions.yml` or any SKILL.md.

**Independent Test**: Quickstart steps 1–4 (see [quickstart.md](quickstart.md)). With one local-path fixture source containing `specs/events/payment-completed.md`, the resulting `spec.md` contains at least one `fixture-payment-service › specs/events/payment-completed.md` citation.

**Story-level dependency**: Layer 1 (US3 README) + Layer 2 (US2 Context Output Block) MUST both ship for US1 to deliver value (per [spec.md](spec.md) § Assumptions, final bullet). US1 contains no file edits of its own — it is the **integration story** whose outcome is realized by US2 + US3 work and verified end-to-end here.

### Verification tasks for User Story 1

- [ ] T005 [US1] Confirm [extension.yml](../../extension.yml)`#hooks.before_specify` and `#hooks.before_plan` already declare `speckit.knowledge.sync` with no arguments (per [plan.md](plan.md) § "Files NOT modified"; satisfies FR-016 — auto-trigger cannot pass `--no-context-output`)
- [ ] T006 [US1] Follow [quickstart.md](quickstart.md) Step 1 (install via `specify extension add knowledge --dev /path/to/spec-kit-shared-knowledge` into a fresh test project) and Step 2 (configure one local-path fixture source); confirm `specify extension list` reports `knowledge 1.1.0` AND that the assertive auto-registration check in Step 1 passes (i.e., `specify extension list --verbose` or `.specify/extensions.yml` shows `speckit.knowledge.sync` under `before_specify`/`before_plan`) (satisfies FR-003, SC-005, plus C1/C2 verification depth)
- [ ] T007 [US1] Follow [quickstart.md](quickstart.md) Step 3 (run `/speckit-knowledge-sync`) and Step 4 (run `/speckit-specify "<feature>"`); confirm the generated `spec.md` contains at least one citation in `<source-label> › <relative-path>` form (satisfies SC-001, US1 acceptance scenarios 1, 2, and 4)

**Checkpoint**: End-to-end zero-config injection works. The MVP slice (Layer 1 + Layer 2 docs/runtime) is verified.

---

## Phase 4: User Story 2 — Sync Emits a Context Output Block for the AI Agent (Priority: P1)

**Goal**: After every successful or degraded sync, the trailing section of `/speckit-knowledge-sync` stdout is a delimited "Context Output for AI Agents" block instructing the agent to read `knowledge-index.md`, open referenced cache files, cite by `<source-label> › <relative-path>`, and surface both versions on `⚠️ CONFLICT`.

**Independent Test**: [quickstart.md](quickstart.md) Step 3 (manual sync) — the last lines of stdout are the literal block defined in [plan.md](plan.md) § "Literal block format", bounded by 70×`══` rules.

**Files modified by this story**: [commands/speckit.knowledge.sync.md](../../commands/speckit.knowledge.sync.md) only. Tasks T008–T015 are sequential (same file, single-writer constraint per the user's Constraints).

### Implementation tasks for User Story 2

- [ ] T008 [US2] Edit [commands/speckit.knowledge.sync.md](../../commands/speckit.knowledge.sync.md) `**Arguments:**` block: add a new bullet `--no-context-output — suppress the trailing Context Output for AI Agents block (diagnostic use only)`, mirroring the existing `--verbose` bullet style (satisfies FR-014, research § R3)
- [ ] T009 [US2] In the same file, add the `--no-context-output` flag detection to the existing `$ARGUMENTS` token-scan documentation — same pattern as `--verbose`: "when `--no-context-output` is present in `$ARGUMENTS`, set `suppress_context_output = true`" (satisfies FR-014; preserves exit-0 contract FR-017)
- [ ] T010 [US2] In the same file, append a new step **after** step 9 (Print summary) titled "10. Emit Context Output for AI Agents block (conditional)" that documents the emission ordering locked in [plan.md](plan.md) § "Emission ordering (locked)": status lines → summary line → pointer line → one blank line → block (block is the LAST thing on stdout)
- [ ] T011 [US2] In the same file, embed the literal block format from [plan.md](plan.md) § "Literal block format" verbatim — including the 70×U+2550 (`══`) top and bottom rules, the `📚 SHARED KNOWLEDGE CONTEXT (for the AI agent)` banner, and the four numbered directives with the U+203A `›` separator in the citation example `payment-service › specs/events/payment-completed.md` (satisfies FR-006, FR-007, FR-008, FR-009, FR-010, FR-011; invariants I1, I2, I3, I4)
- [ ] T012 [US2] In the same file, document the emission gate inside step 10: "Emit when at least one source returned `fresh`, OR all sources are `cached`/mixed `cached`+`unreachable` with at least one usable cache" — references the degraded-mode table in [plan.md](plan.md) § "Degraded-mode behavior" (satisfies FR-012, FR-013; US2 acceptance scenarios 1 and 3)
- [ ] T013 [US2] In the same file, document the "all sources unreachable AND no prior `knowledge-index.md`" sub-case from the same degraded-mode table: print the soft warning `⚠️  No knowledge-index.md found yet. Run /speckit-knowledge-sync once when sources are reachable.`, do NOT emit the block, exit 0 (satisfies FR-013 boundary, FR-017)
- [ ] T014 [US2] In the same file, document the suppression-by-flag rule in step 10: "When `suppress_context_output` is true, skip step 10 entirely; all earlier output is unchanged; exit 0" — explicitly note that `--verbose` and `--no-context-output` compose orthogonally (satisfies FR-014, US4 acceptance scenario 3 — placed here because it's the same conditional on the same file)
- [ ] T015 [US2] In the same file, update the "Error Cases Summary" / early-exit table so each of the four existing early-exit paths (no `knowledge.yml`, invalid YAML, missing `schema_version`, missing `sources`) explicitly states "Context Output block NOT emitted" — mirrors the table in [plan.md](plan.md) § "Suppression semantics — early-exit paths" (satisfies FR-015, US2 acceptance scenario 4)

**Checkpoint**: `speckit.knowledge.sync` now emits the Context Output block on every successful/degraded path, suppresses it on early-exits, and honors `--no-context-output`. The hook stdout contract that US1 depends on is in place.

---

## Phase 5: User Story 3 — README No Longer Documents Manual Hook Registration (Priority: P2)

**Goal**: [README.md](../../README.md) § "Integration with /speckit-specify and /speckit-plan" is rewritten to a short paragraph + migration note. No instruction to hand-edit `.specify/extensions.yml`. No SKILL.md preamble snippets.

**Independent Test**: [quickstart.md](quickstart.md) post-feature documentation review — a workspace-wide search for `.specify/extensions.yml` returns no hits in a "manual registration" context inside [README.md](../../README.md); a search for the prior "Cross-repo knowledge check" preamble returns zero matches.

**Files modified by this story**: [README.md](../../README.md) only. Tasks T016–T020 are sequential (same file, single-writer constraint per the user's Constraints).

### Implementation tasks for User Story 3

- [ ] T016 [US3] In [README.md](../../README.md), locate the section heading `## Integration with /speckit-specify and /speckit-plan` and delete the entire "Step 1: Register the sync hooks in `.specify/extensions.yml`" subsection — including the surrounding YAML snippet and any per-step prose (satisfies FR-001, US3 acceptance scenarios 1 and 2)
- [ ] T017 [US3] In the same file/section, delete the entire "Step 2: Amend your SKILL.md files" subsection — including the "Cross-repo knowledge check" preamble code block and any prose telling the reader to paste it into a SKILL.md file (satisfies FR-002, US3 acceptance scenario 3)
- [ ] T018 [US3] In the same file/section, insert a single replacement paragraph (≤ 4 sentences) stating that the `before_specify` and `before_plan` hooks declared under the top-level `hooks:` key in [extension.yml](../../extension.yml) are auto-registered by spec-kit when the extension is installed via `specify extension add`, and link to the official spec-kit Extension Development Guide (https://github.com/github/spec-kit/blob/main/extensions/EXTENSION-DEVELOPMENT-GUIDE.md) for the underlying mechanism. Mention that the AI agent's index-reading behavior is driven by the Context Output block emitted by sync (cross-reference [commands/speckit.knowledge.sync.md](../../commands/speckit.knowledge.sync.md)) (satisfies FR-003, US3 acceptance scenario 1)
- [ ] T019 [US3] In the same file/section, append a one-paragraph migration note: "If you previously followed the prior README and added `knowledge` entries to your project's `.specify/extensions.yml`, you may safely remove them — auto-registration handles them now." (satisfies FR-004, US3 acceptance scenario 4)
- [ ] T020 [US3] Re-read the rewritten section and grep the rest of [README.md](../../README.md) for `.specify/extensions.yml`: confirm zero remaining occurrences that instruct the user to hand-edit it for this extension's hook registration. Preserve the existing "No-op when not configured" callout — it describes runtime behavior (commands exit 0 with a not-configured message) and contains no setup-time hand-edit instructions, so it is explicitly authorized to remain after the rewrite (satisfies FR-005, SC-002)

**Checkpoint**: README accurately reflects the auto-registration reality and the Context Output-driven runtime. New adopters cannot be misled into hand-editing `.specify/extensions.yml`.

---

## Phase 6: User Story 4 — Diagnostic Opt-Out for Manual Sync (Priority: P3)

**Goal**: `/speckit-knowledge-sync --no-context-output` prints the status table and summary line only — the Context Output block is suppressed. The auto-triggered hook path never passes the flag.

**Independent Test**: [quickstart.md](quickstart.md) Step 5 (manual `--no-context-output` invocation) — block is absent. Re-run without the flag — block is present.

**Note**: All implementation for this story is already covered by US2 tasks T008, T009, and T014 (same file, same flag, same conditional). US4 adds verification only.

### Verification tasks for User Story 4

- [ ] T021 [US4] Follow [quickstart.md](quickstart.md) Step 5: run `/speckit-knowledge-sync --no-context-output` in the test project; confirm stdout ends at the pointer line `→ .specify/extensions/knowledge/knowledge-index.md` and the Context Output block is absent; confirm `echo $?` returns 0 (satisfies FR-014, FR-017, US4 acceptance scenario 1)
- [ ] T022 [US4] Re-run `/speckit-knowledge-sync` (no flag) and confirm the block reappears, preceded by exactly one blank line after the pointer line — same emission ordering as Step 3 (satisfies FR-012, US4 acceptance scenario 1 inverse)
- [ ] T023 [US4] Re-confirm via T005 that [extension.yml](../../extension.yml)`#hooks.before_specify` and `#hooks.before_plan` declare no arguments to `speckit.knowledge.sync` — the auto-trigger path is structurally incapable of passing `--no-context-output` (satisfies FR-016, US4 acceptance scenario 2)
- [ ] T024 [US4] Run `/speckit-knowledge-sync --verbose --no-context-output` and confirm the per-source `verbose` file listings appear AND the Context Output block is absent — the two flags compose orthogonally (satisfies US4 acceptance scenario 3)

**Checkpoint**: All four user stories independently verified. Sync behavior is fully wired.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: CHANGELOG entry (depends on US2 + US3 being done so the bullets reflect actual shipped behavior) and a final whole-feature acceptance pass following [quickstart.md](quickstart.md) end-to-end.

- [ ] T025 [P] Edit [CHANGELOG.md](../../CHANGELOG.md): insert a new `## [1.1.0] - TBD` section directly above `## [1.0.0]`, with the two bullets specified in [plan.md](plan.md) § "CHANGELOG.md Impact":
  - `feat(sync): emit Context Output for AI Agents block by default; add --no-context-output flag`
  - `docs(readme): remove obsolete manual hook registration and SKILL.md preamble steps; add migration note`

  Replace `TBD` with the release date when tagging. Depends on T004 (version bump must precede the entry that names the version), T008–T015 (so the `feat(sync)` bullet reflects shipped behavior), and T016–T020 (so the `docs(readme)` bullet reflects shipped behavior).
- [ ] T026 [P] Follow [quickstart.md](quickstart.md) Step 6 (degraded mode walkthrough): simulate all sources unreachable with an existing cache, confirm the block still emits and references `knowledge-index.md`; then delete the cache, confirm the soft-warning line prints and the block does NOT emit; both paths exit 0 (satisfies FR-013, FR-017, SC-003, SC-004)
- [ ] T027 Final whole-feature acceptance: execute [quickstart.md](quickstart.md) Steps 1–6 end-to-end in a fresh test project, verifying SC-001 through SC-006 inline. Confirms (a) zero-config injection works (SC-001), (b) README has no manual-edit instructions (SC-002), (c) block emits on every successful/degraded path (SC-003), (d) early-exit paths emit no block and still exit 0 (SC-004), (e) install → cited spec in under 2 minutes (SC-005), (f) an adopter who deletes prior hand-edits sees unchanged behavior (SC-006)

**Checkpoint**: v1.1.0 is shippable. CHANGELOG, README, sync command, and manifest are all internally consistent.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — can start immediately.
- **Phase 2 (Foundational, T004)**: Depends on Phase 1. **Blocks** Phase 5 (US3) and Phase 7 (CHANGELOG) because both reference v1.1.0.
- **Phase 3 (US1)**: Conceptually depends on Phase 4 (US2) and Phase 5 (US3) being implemented — US1 has no edits of its own, it is the end-to-end integration verification. May be executed after US2 + US3 land.
- **Phase 4 (US2)**: Depends on Phase 2. Independent of Phase 5 (different file). MVP-critical.
- **Phase 5 (US3)**: Depends on Phase 2. Independent of Phase 4 (different file). MVP-critical.
- **Phase 6 (US4)**: Depends on Phase 4 (T008, T009, T014 are the underlying implementation). Verification-only.
- **Phase 7 (Polish)**: T025 depends on Phase 2 + Phase 4 + Phase 5. T026 depends on Phase 4. T027 depends on everything prior.

### User Story Dependencies

- **US1 (P1, MVP integration)**: Realized by US2 + US3. No standalone edits; verifies the joint outcome.
- **US2 (P1, runtime)**: Independent of US3 (different file). Required for US1.
- **US3 (P2, docs)**: Independent of US2 (different file). Required for US1.
- **US4 (P3, opt-out)**: Implementation piggy-backs on US2 tasks T008/T009/T014; verification is standalone.

### Within Each User Story

- US2 tasks T008–T015 are strictly sequential (same file: [commands/speckit.knowledge.sync.md](../../commands/speckit.knowledge.sync.md)).
- US3 tasks T016–T020 are strictly sequential (same file: [README.md](../../README.md)).
- US1 and US4 verification tasks within their phase can run in any order — they touch no source files.

### Parallel Opportunities

- T002 and T003 (Setup reads) can run in parallel.
- Phase 4 (US2, edits [commands/speckit.knowledge.sync.md](../../commands/speckit.knowledge.sync.md)) and Phase 5 (US3, edits [README.md](../../README.md)) can run in parallel by different contributors once Phase 2 completes — they touch disjoint files.
- T025 and T026 in Polish can run in parallel (different files, no in-flight dependency).
- T024 and T021/T022 in US4 can run in parallel (same verification environment, independent observations).

---

## Parallel Execution Examples

### Phase 1 (Setup reads)

```bash
# In parallel — three independent reads:
# T002: read data-model.md § Invariants
# T003: read research.md § R3
# (T001 should be done first since the contract is the reference point for both.)
```

### After Phase 2 — US2 and US3 in parallel

```bash
# Contributor A picks up Phase 4 (US2):
#   edits commands/speckit.knowledge.sync.md sequentially T008 → T015

# Contributor B picks up Phase 5 (US3):
#   edits README.md sequentially T016 → T020

# Disjoint file sets → no merge conflict
```

### Phase 7 polish

```bash
# T025 (CHANGELOG.md edit) and T026 (degraded-mode quickstart walk) can proceed in parallel
# T027 must wait for both to complete
```

---

## Requirement Mapping

Every FR-001…FR-017 from [spec.md](spec.md) is fulfilled by at least one task below.

| FR | Description (short) | Fulfilling tasks |
|----|---------------------|------------------|
| FR-001 | Remove Step 1 ("Register the sync hooks…") from README Integration section | T016 |
| FR-002 | Remove Step 2 ("Amend your SKILL.md files") from same section | T017 |
| FR-003 | Replacement paragraph (≤ 4 sentences) on auto-registration + link to spec-kit Extension Development Guide | T018 (doc surface); T005, T006, T007 (behavioral surface — verify auto-registration fires) |
| FR-004 | Migration note for prior adopters who hand-edited `.specify/extensions.yml` | T019 |
| FR-005 | README has no remaining instruction to hand-edit `.specify/extensions.yml` for hook registration | T020 |
| FR-006 | Sync emits Context Output block as final stdout section | T010, T011 |
| FR-007 | Block wrapped by clearly delimited markers (70×`══` rules) | T011 |
| FR-008 | Block instructs agent to read `knowledge-index.md` | T011 |
| FR-009 | Block instructs agent to open every `.md` referenced by the index | T011 |
| FR-010 | Block instructs agent to cite as `<source-label> › <relative-path>` | T011 |
| FR-011 | Block instructs agent to surface every version on `⚠️ CONFLICT` | T011 |
| FR-012 | Block emitted on every successful sync (status `fresh`) by default | T012 |
| FR-013 | Block also emitted in degraded mode (≥ 1 usable cache) | T012, T013 |
| FR-013a | Soft-warning line + no block when all sources unreachable AND no prior index | T013, T026 |
| FR-014 | Block suppressed iff `--no-context-output` is passed | T008, T009, T014 |
| FR-015 | Block NOT emitted on any of the four early-exit paths | T015 |
| FR-016 | Auto-triggered hooks MUST NOT pass `--no-context-output` | T005, T023 |
| FR-017 | All sync paths continue to exit 0 | T004 (manifest), T009, T013, T014, T015 (each preserves exit-0 contract), T021, T026 (verify) |

Manifest / release-hygiene requirements (from [spec.md](spec.md) § "Extension Impact" and [plan.md](plan.md) § Constitution Check):

| Requirement | Fulfilling task |
|-------------|-----------------|
| `extension.version` bump `1.0.0` → `1.1.0` | T004 |
| CHANGELOG `## [1.1.0]` entry with the two specified bullets | T025 |

Success criteria coverage:

| SC | Verifying task(s) |
|----|-------------------|
| SC-001 (≥ 1 citation in spec.md with zero manual edits) | T006 (auto-registration confirmed), T007, T027 |
| SC-002 (zero README instructions to hand-edit `.specify/extensions.yml`) | T020, T027 |
| SC-003 (every successful/degraded sync invocation that did not pass `--no-context-output` ends with the block — verified by direct invocation in T022/T026/T027) | T022, T026, T027 |
| SC-004 (every early-exit path emits no block and still exits 0 — verified by direct invocation in T015/T026/T027) | T015, T026, T027 |
| SC-005 (install → cited spec under 2 minutes) | T006, T007, T027 |
| SC-006 (deleting prior hand-edits leaves behavior unchanged) | T027 |

---

## Implementation Strategy

### MVP scope

**US1 alone is the headline outcome** but cannot ship in isolation — it has no file edits of its own and depends on both US2 (runtime block) and US3 (README cleanup) to deliver value. Per [spec.md](spec.md) § Assumptions, final bullet:

> The cross-cutting outcome (Story 1) requires Layer 1 + Layer 2 to ship together; partial delivery (e.g., README rewrite without the Context Output block) is explicitly NOT a viable MVP because the agent would have no instruction to read the index.

**Therefore the minimum shippable increment is US2 + US3 together** (which together realize US1). This is the **v1.1.0 release**.

US4 (`--no-context-output`) is implementation-covered by US2 and adds verification only — it can ship in the same release at zero additional cost.

### Incremental delivery sequence

1. **Phase 1 (Setup)** — reload contract + invariants.
2. **Phase 2 (Foundational)** — bump manifest to v1.1.0.
3. **Phase 4 (US2)** and **Phase 5 (US3)** in parallel — disjoint files, MVP-critical.
4. **Phase 3 (US1)** verification — confirms the joint outcome.
5. **Phase 6 (US4)** verification — confirms the opt-out flag works.
6. **Phase 7 (Polish)** — CHANGELOG entry + final acceptance walkthrough.

### Constitutional constraints (locked)

- All sync paths preserve `exit 0` (Constitution invariant + FR-017). Verified explicitly in T021, T026.
- Same-file edits are sequential — no parallel writes within US2 (T008–T015) or US3 (T016–T020).
- `extension.yml` bump (T004) precedes CHANGELOG entry (T025) chronologically.
- No new commands, no new files, no `schema_version` change (per [spec.md](spec.md) § "Out of Scope").
