# Tasks: Point the agent at shared knowledge from AGENTS.md

**Feature**: [agents-knowledge-pointer.spec.md](./agents-knowledge-pointer.spec.md) · **Plan**: [plan.md](./plan.md) · **Contracts**: [contracts/](./contracts/)

The change is prose in agent prompts, so each story is checked with the matching [quickstart.md](./quickstart.md) steps. Run them in a scratch consumer project with the extension installed from this branch (`specify extension add <repo> --dev`). No automated harness covers agent-written files (research R11).

## Phase 2: Foundational (blocks every story)

All four stories use the one procedure in `sync.md`, so the shared file is built here, before any story.

Files: `commands/speckit.knowledge.sync.md`, `commands/speckit.knowledge.configure.md`, `commands/speckit.knowledge.status.md`

**Wave 1 — independent (different files):**

- [x] **T001** [P] Add the `agents_md` row from [contracts/knowledge-config.schema.md § 2](./contracts/knowledge-config.schema.md) to § Configuration Validation Rules, byte-identical. In step 4, add that every top-level key other than `schema_version` and `sources` is preserved on edits (R10) · `commands/speckit.knowledge.configure.md`
- [x] **T002** [P] Add the same `agents_md` row to § Configuration Validation Rules, byte-identical · `commands/speckit.knowledge.status.md`
- [x] **T003** [P] Add the same `agents_md` row to § Configuration Validation Rules, byte-identical · `commands/speckit.knowledge.sync.md`

**⟶ Wait for Wave 1 to finish, then:**

- [x] **T004** Add `§ Agent Context Section` to § Algorithm Reference. It covers:
  - marker states: absent, present, damaged (R3)
  - the enabled, accepted label list in configuration order, with escaping and code-span rules (R7)
  - the exact section text from [contracts/agents-md-section.md](./contracts/agents-md-section.md), naming `speckit.knowledge.sync` by its canonical id (R8)
  - write and remove modes with placement, compare-before-write and empty-file deletion (R5)
  - the `agents_md` gate: `false` means remove mode, invalid means untouched (R1)
  - the four checks in order, with the report lines from [contracts/commands.md § 3](./contracts/commands.md)
  - writes through the agent's file-writing tool only, never a shell

  FR-001–FR-008, FR-010–FR-013 · `commands/speckit.knowledge.sync.md`

**⟶ Then, in order (same file):**

- [x] **T005** Step 1 reads `agents_md`. Step 1a applies § Agent Context Section in remove mode after deleting the index, and prints its line after the step 1a report. FR-009, FR-014 · `commands/speckit.knowledge.sync.md`
- [x] **T006** Add step 8b after 8a: write mode when `knowledge-index.md` exists, and nothing when no index exists and none was deleted (R6). In step 9, print the line after the index pointer line and add the example from contracts/commands.md § 3. FR-001, FR-014 · `commands/speckit.knowledge.sync.md`
- [x] **T007** Add the five rows from contracts/commands.md § 4 to the error cases table. Add the `AGENTS.md` bullet to Side effects. State that `--no-context-output` does not affect `AGENTS.md` (R9). FR-012 · `commands/speckit.knowledge.sync.md`

**⟶ Then:**

- [x] **T008** Run `bash .github/scripts/validate-extension.sh` with PyYAML on PATH. Check 11 (identical validation blocks), check 5 (command tokens) and check 12 (quoted placeholders) must pass · `.github/scripts/validate-extension.sh`

**Checkpoint**: sync writes, updates and removes the section. Configure, status and sync agree on `agents_md`.

## Phase 3: User Story 1 - Ask about another repository in plain language (Priority: P1) 🎯 MVP

Files: none edited. This phase verifies Phase 2 in a scratch project.

- [x] **T009** [US1] Quickstart steps 1, 4 and 14. Sync creates `AGENTS.md` holding only the section. At least 4 of 5 fresh-chat answers cite `<label> › <path>` (SC-001). Offline with no index, the section stays and the agent suggests `speckit.knowledge.sync` · scratch consumer project

**Checkpoint**: plain-language questions reach the synced knowledge with no command.

## Phase 4: User Story 2 - Keep the section accurate without touching anything else (Priority: P1)

Files: none edited.

- [x] **T010** [US2] Quickstart steps 2, 3, 11, 12 and 13.
  - A re-run leaves the file byte-identical (SC-002).
  - The `SPECKIT` block and surrounding text are intact (SC-003).
  - Damaged markers leave the file untouched and print a warning.
  - A hostile label stays inside the section.
  - A read-only file prints a warning and exits 0 (SC-004).

  · scratch consumer project

**Checkpoint**: the section is idempotent and confined to its markers.

## Phase 5: User Story 3 - Removing or disabling a source takes effect for the agent at once (Priority: P2)

Files: `commands/speckit.knowledge.remove.md`

- [x] **T011** [US3] Add step 3a after step 3. When `knowledge-index.md` exists, it applies `§ Agent Context Section` from `speckit.knowledge.sync.md` by reference, using the enabled, accepted labels after the change. It uses remove mode when none remains, and follows the `agents_md` gate. It does not run after an early exit or a no-op identifier.
  - Print the line after the step 4 report, and add the `--enable` example.
  - Add the error table rows.
  - Rewrite Side effects: remove may now edit `AGENTS.md`, and it still never touches `knowledge-index.md`.

  FR-003, FR-014, FR-015, FR-016 · `commands/speckit.knowledge.remove.md`
- [x] **T012** [US3] Quickstart steps 5 to 8.
  - `--disable` drops only that label, and the index is byte-identical (FR-016).
  - 0 of 5 answers come from the disabled source (SC-006).
  - `--enable` restores the label.
  - Removing the last source removes the section.

  · scratch consumer project

**Checkpoint**: remove, `--disable` and `--enable` reach the agent without a sync.

## Phase 6: User Story 4 - Turn it off (Priority: P2)

Files: `config-template.yml`

- [x] **T013** [US4] Add a commented `agents_md` block among the optional project-wide keys. Follow the `max_cache_age` block style: what it does, `true`/`false` only, default `true`, that an invalid value leaves `AGENTS.md` untouched, and the example `# agents_md: false`. FR-010 · `config-template.yml`
- [x] **T014** [US4] Quickstart steps 9 and 10. `agents_md: false` removes the section, and later syncs leave the file untouched. `agents_md: "no"` warns, leaves the file untouched, and the index is still written · scratch consumer project

**Checkpoint**: a team can switch the behavior off from its configuration.

## Phase 7: Polish

Files: `README.md`, `CHANGELOG.md`

**Wave 1 — independent (different files):**

- [x] **T015** [P] Add an "Ask in plain language" section explaining the `AGENTS.md` pointer, what sync and remove do to it, and how to opt out. Add an `agents_md` bullet to the configuration key reference · `README.md`
- [x] **T016** [P] Under `[Unreleased]`:
  - **Added:** the `AGENTS.md` knowledge section and the `agents_md` key.
  - **Changed:** remove now updates the section.
  - **Changed:** configure preserves every top-level key.

  · `CHANGELOG.md`

**⟶ Wait for Wave 1 to finish, then:**

- [x] **T017** Validate against the Success Criteria:
  - Run `bash .github/scripts/validate-extension.sh` with PyYAML available.
  - Run `bash .github/scripts/test-sync-git.sh`, which must still report 229 checks passing.
  - Confirm that T009, T010, T012 and T014 together met SC-001 to SC-006.

  · `.github/scripts/validate-extension.sh`

## Dependencies & Execution Order

- **Phases**: Foundational (2) → US1 (3) and US2 (4) → US3 (5) and US4 (6) → Polish (7).
  - US3 and US4 depend only on Phase 2 and can run in parallel with each other and with Phases 3–4.
  - T012 step 8 and T014 reuse the project from T009–T010.
- **Phase 2**: Wave 1 (T001–T003) → T004 → T005 → T006 → T007 → T008. T004–T007 edit the same file, so they run in order.
- **Phase 5**: T011 → T012.
- **Phase 6**: T013 → T014.
- **Phase 7**: Wave 1 (T015, T016) → T017.
- **Parallel opportunities**: T001–T003; Phase 5 alongside Phase 6; T015 alongside T016.
