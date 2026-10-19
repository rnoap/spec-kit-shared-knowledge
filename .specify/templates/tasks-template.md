---

description: "Task list template for feature implementation"
---

# Tasks: [FEATURE NAME]

**Input**: Design documents from `/specs/[###-feature-name]/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: No automated test tasks for command behavior — a model interprets agent prompts at runtime, and constitution § III waives a test framework for them. Behavior is verified by the feature's `quickstart.md` walkthrough in a clean consumer project (final phase); the packaging contract by `validate-extension.sh` and the install smoke test. Exception: a change to `.github/scripts/` proves each new check by reintroducing the defect it guards and watching it fail. The git steps of `sync` and `status` also have a local regression script, `bash .github/scripts/test-sync-git.sh`, which runs those commands' bash blocks against offline `file://` fixtures; it is not wired into CI.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

No `src/` or `tests/` tree exists and none is created. The deliverable is agent-prompt Markdown plus a YAML manifest and schema:

- `commands/speckit.knowledge.<verb>.md` — one agent prompt per command
- `extension.yml` — the package manifest
- `config-template.yml` — the user-facing config schema
- `README.md`, `CHANGELOG.md` — kept in step with the three above
- `.github/scripts/`, `.github/workflows/` — dev-only CI, never shipped

Tasks that edit the same command file are serial; parallelism exists only across different files.

<!--
  ============================================================================
  IMPORTANT: The tasks below are SAMPLE TASKS for illustration purposes only.

  The /speckit-tasks command MUST replace these with actual tasks based on:
  - User stories from spec.md (with their priorities P1, P2, P3...)
  - Feature requirements from plan.md
  - Entities from data-model.md
  - Endpoints from contracts/

  Tasks MUST be organized by user story so each story can be:
  - Implemented independently
  - Tested independently
  - Delivered as an MVP increment

  DO NOT keep these sample tasks in the generated tasks.md file.
  ============================================================================
-->

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Baseline and scaffolding; no consumer-facing changes yet

- [ ] T001 Run `bash .github/scripts/validate-extension.sh` on the unmodified tree and record that it passes, so a later failure is attributable to this feature
- [ ] T002 Create `commands/speckit.knowledge.<verb>.md` and register it under `provides.commands` in `extension.yml` (new command only; the namespace is the extension id `knowledge`, not `shared-knowledge`)
- [ ] T003 [P] Add an entry under `## [Unreleased]` in `CHANGELOG.md` describing the change

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

Examples of foundational tasks for this extension package (adjust per feature):

- [ ] T004 Update the `extension.yml` contract — commands, hooks, `requires` — but not `version`, which moves with the release in the final phase. No hook may declare arguments
- [ ] T005 [P] Document each new config key in `config-template.yml` as a commented, opt-in example; keep `schema_version: "1.0"` unless the change is breaking
- [ ] T006 Change the Configuration Validation Rules block in all three copies — `configure`, `sync`, `status` — as one task; static validation fails the pull request if they differ
- [ ] T007 Re-run `bash .github/scripts/validate-extension.sh` — the same static validation CI enforces on every pull request

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - [Title] (Priority: P1) 🎯 MVP

**Goal**: [Brief description of what this story delivers]

**Independent Test**: [Which `quickstart.md` steps prove this story on its own]

### Implementation for User Story 1

- [ ] T008 [US1] Add step [N] "[step title]" to `commands/speckit.knowledge.[verb].md`
- [ ] T009 [US1] Add a row to `## Error cases` in `commands/speckit.knowledge.[verb].md` for every new failure path — each still exits 0
- [ ] T010 [P] [US1] Update `commands/speckit.knowledge.[other-verb].md` where the story crosses commands
- [ ] T011 [P] [US1] Document the behavior in `README.md` § [section]

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently

---

## Phase 4: User Story 2 - [Title] (Priority: P2)

**Goal**: [Brief description of what this story delivers]

**Independent Test**: [Which `quickstart.md` steps prove this story on its own]

### Implementation for User Story 2

- [ ] T012 [US2] Extend step [N] of `commands/speckit.knowledge.[verb].md` with [behavior]
- [ ] T013 [US2] Add a `## --[name] flag` section to `commands/speckit.knowledge.[verb].md`
- [ ] T014 [P] [US2] Document the behavior in `README.md` § [section]

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently

---

## Phase 5: User Story 3 - [Title] (Priority: P3)

**Goal**: [Brief description of what this story delivers]

**Independent Test**: [Which `quickstart.md` steps prove this story on its own]

### Implementation for User Story 3

- [ ] T015 [US3] Implement [behavior] in `commands/speckit.knowledge.[verb].md`
- [ ] T016 [P] [US3] Document the behavior in `README.md` § [section]

**Checkpoint**: All user stories should now be independently functional

---

[Add more user story phases as needed, following the same pattern]

---

## Phase N: Polish & Release

**Purpose**: Documentation sync and verification; the release tasks apply only if this feature cuts a version

- [ ] TXXX [P] Sync `README.md` with `extension.yml` — every command in `provides.commands` documented, counts and Configuration Reference current
- [ ] TXXX Run `bash .github/scripts/validate-extension.sh`
- [ ] TXXX Install into a clean consumer project with `specify extension add <repo> --dev 2>&1 | tee install.log`, then run `bash .github/scripts/assert-install.sh <consumer-dir> <repo>` — the same assertions as the CI smoke test
- [ ] TXXX Run the feature's `quickstart.md` walkthrough in that consumer project — the only check on command behavior — and confirm exit code `0` at every step, adverse ones included
- [ ] TXXX *(release only)* Bump the version as one change in three coupled places: `version` in `extension.yml`, the status badge in `README.md`, and `CHANGELOG.md` `[Unreleased]` → `## [x.y.z] - YYYY-MM-DD`. Otherwise leave the entries under `[Unreleased]`
- [ ] TXXX *(release only)* Merge the pull request once "Static validation" and "Install smoke test" pass, then put an annotated tag `vx.y.z` on the merge commit and publish it with `gh release create vx.y.z --verify-tag --latest`. `v*` tags are immutable — check the target commit before pushing the tag

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
  - User stories can then proceed in parallel (if staffed)
  - Or sequentially in priority order (P1 → P2 → P3)
- **Polish (Final Phase)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational (Phase 2) - May integrate with US1 but should be independently testable
- **User Story 3 (P3)**: Can start after Foundational (Phase 2) - May integrate with US1/US2 but should be independently testable

### Within Each User Story

- Config schema and validation rules before the command steps that read them
- Command behavior before the README text that documents it
- Story complete before moving to next priority

### Parallel Opportunities

- All Setup tasks marked [P] can run in parallel
- All Foundational tasks marked [P] can run in parallel (within Phase 2)
- Once Foundational phase completes, all user stories can start in parallel (if team capacity allows)
- Within a story, tasks on different files (a second command, `README.md`, `config-template.yml`) can run in parallel; tasks on the same command file cannot
- Different user stories can be worked on in parallel by different team members

---

## Parallel Example: User Story 1

```bash
# Different files, no shared dependency — safe to run together:
Task: "Update commands/speckit.knowledge.[other-verb].md where the story crosses commands"
Task: "Document the behavior in README.md § [section]"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Test User Story 1 independently
5. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Deploy/Demo (MVP!)
3. Add User Story 2 → Test independently → Deploy/Demo
4. Add User Story 3 → Test independently → Deploy/Demo
5. Each story adds value without breaking previous stories

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: User Story 1
   - Developer B: User Story 2
   - Developer C: User Story 3
3. Stories complete and integrate independently

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each task or logical group, using Conventional Commits (constitution § IV): `feat(sync):`, `fix(status):`, `docs(readme):`, `chore(release):`
- No task adds a script: what can be expressed as Markdown in a command file must be (constitution § III)
- Stop at any checkpoint to validate story independently
- Avoid: vague tasks, same file conflicts, cross-story dependencies that break independence
