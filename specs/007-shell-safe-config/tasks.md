# Tasks: Shell-Safe Configuration

**Input**: [shell-safe-config.spec.md](./shell-safe-config.spec.md), [plan.md](./plan.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

Format: `- [ ] **T###** [P?] [US#] Description · path`. `[P]` means independent of the other tasks in its wave. Command prose cites this feature's requirements as `007 FR-0xx` ([research § 15](./research.md#15-requirement-citations)). Commit by concern, as the plan's Constitution Check lists.

## Phase 1: Setup

Files: none.

- [ ] **T001** Gate: `git status --short` lists only `specs/007-shell-safe-config/`, `.specify/feature.json` and `.github/copilot-instructions.md`. Commit those in their own commits before any task below edits a file, so each feature commit carries only its own change. Then `bash .github/scripts/test-sync-git.sh` passes on the unchanged commands, so a later failure belongs to this feature · (repository state)

## Phase 2: Foundational

Files: `commands/speckit.knowledge.sync.md`, `commands/speckit.knowledge.configure.md`, `commands/speckit.knowledge.status.md`, `commands/speckit.knowledge.remove.md`, `commands/speckit.knowledge.search.md`, `.github/scripts/validate-extension.sh`, `.github/scripts/test-sync-git.sh`.

Every story changes the same command files, and three of them carry the validation block that check 11 keeps byte-identical, so every runtime edit lands here. The tests are written alongside, against the placeholder spellings of [contracts/commands.md § 3.2](./contracts/commands.md#32-placeholders), and fail until the snippets they exercise are quoted. The story phases document and verify.

**Wave 1 — independent (different files):**

- [ ] **T002** [P] [US2] Add static check 12 under `Repository invariants`, after check 11, as [contracts/ci.md § 1](./contracts/ci.md#1-static-check-12) specifies. Run it on the unchanged commands: it fails naming exactly the 18 lines of § 1.3 (FR-007) · `.github/scripts/validate-extension.sh`
- [ ] **T003** [P] [US1] Rewrite § Configuration Validation Rules (FR-001, FR-002, FR-005, FR-006):
  - Replace the `url` and `path_filter` rows with the two rows of [knowledge-config.schema.md § 3](./contracts/knowledge-config.schema.md#3-validation-block-rows), copied exactly.
  - Turn "Why no value may begin with `-`" into the account of both layers: refuse with the leading-`-` rule and the character rule, neutralize with `--` and the quoting rule of [commands.md § 3.1](./contracts/commands.md#31-the-quoting-rule).
  - State that the agent applies every rule in its own reasoning, checks a value before any other use, and hands no value of a source that is not accepted to a shell.
  - Add the character-rule example to `On failure`, and the message rule of [commands.md § 2.3](./contracts/commands.md#23-values-in-messages-fr-005): agent output, control characters escaped.
  - Keep the headings `## Configuration Validation Rules` and `## Behavior` exactly as they are.

  · `commands/speckit.knowledge.sync.md`
- [ ] **T004** [P] [US2] Replace the sed in `render()` with a literal substitution that applies the quoting rule ([ci.md § 3.1](./contracts/ci.md#31-filling-placeholders)), for the spellings of [commands.md § 3.2](./contracts/commands.md#32-placeholders). It still runs on bash 3.2 · `.github/scripts/test-sync-git.sh`

**⟶ Wait for Wave 1 to finish, then:**

**Wave 2 — independent (different files):**

- [ ] **T005** [P] [US1] configure (FR-001 to FR-003, FR-005):
  - Copy sync's validation block byte for byte, then `diff` the two ranges.
  - Behavior step 2: keep a quoted argument whole ([commands.md § 5.5](./contracts/commands.md#55-configure-arguments)); a local path starts with `/`, `./`, `../` or `~/`; the character rule runs before the existence check.
  - Add the error rows of [commands.md § 2.2](./contracts/commands.md#22-configure), and change the row for a `url` matching no accepted form.
  - Escape control characters in values the source list and `--verbose` output quote.

  · `commands/speckit.knowledge.configure.md`
- [ ] **T006** [P] [US1] status (FR-002, FR-004 to FR-006):
  - Copy sync's validation block byte for byte, then `diff` the two ranges.
  - Check every source before step 2. A source that is not accepted gets no slug, no manifest read and no reachability check.
  - Print its refusal line before the header. Add the `⚠️ invalid` row, ahead of `— disabled`, and the `invalid` count in the `Total` line ([commands.md § 5.1](./contracts/commands.md#51-status)).
  - Quote both reachability checks as § 5.1 shows. Keep the opening words of the remote lead-in, which the test script uses as an anchor.
  - Check a slug's form before reading a manifest through it ([§ 4.5](./contracts/commands.md#45-using-a-slug)). Escape control characters in `--verbose` paths.

  · `commands/speckit.knowledge.status.md`
- [ ] **T007** [P] [US3] Rewrite § Source Slug Generation as [commands.md § 4.1](./contracts/commands.md#41-interface) states: the two assignments first, no comment after a line continuation, `printf '%s\n' "$url"`, the slug printed last, the worked example `18dbb51ec4eb`. The algorithm does not change (FR-006, FR-008, FR-009) · `commands/speckit.knowledge.sync.md`
- [ ] **T008** [P] [US2] Add the hostile-values section of [ci.md § 3.3](./contracts/ci.md#33-sections-added): the 8 seeds of § 3.2 in every configuration placeholder, with a recording `git` stand-in first on `PATH`. It fails until T009 (FR-006, SC-004) · `.github/scripts/test-sync-git.sh`

**⟶ Wait for Wave 2 to finish, then:**

**Wave 3 — independent (different files):**

- [ ] **T009** [P] [US2] Quote every configuration placeholder in the cold path (Tiers 1 to 3, the local clone, sparse-checkout) and the warm path (sparse-checkout, remote, local), spelled as [commands.md § 3.2](./contracts/commands.md#32-placeholders) spells them, including `[--branch '<revision>']`, `[ -n '<path_filter>' ]` and `[ -z '<revision>' ]`. Switch the example comments to single quotes, and say that `<expanded-path>` is the home directory written out, since `$HOME` does not expand inside single quotes (FR-006) · `commands/speckit.knowledge.sync.md`
- [ ] **T010** [P] [US1] remove ([commands.md § 5.3](./contracts/commands.md#53-remove)): a target that is not accepted has its entry deleted or `enabled` toggled, its slug is not computed, and its cache is left for the next prune, with the message § 5.3 shows. An accepted target is purged only after the slug-form check of § 4.5. Escape control characters in the source list (FR-002, FR-005) · `commands/speckit.knowledge.remove.md`
- [ ] **T011** [P] [US1] search ([commands.md § 5.4](./contracts/commands.md#54-search)): a source that is not accepted gets its refusal line and contributes nothing; a slug's form is checked before a manifest is read through it; item content is read with the file-reading tool, never a shell command; names in results are escaped (FR-002, FR-005, FR-006) · `commands/speckit.knowledge.search.md`
- [ ] **T012** [P] [US2] Add the section for a local path containing a space ([ci.md § 3.3](./contracts/ci.md#33-sections-added)): `~/My Repos/kb` under the test's `HOME`, a cold sync, a warm sync, then status's local check (SC-005) · `.github/scripts/test-sync-git.sh`

**⟶ Wait for Wave 3 to finish, then:**

**Wave 4 — independent (different files):**

- [ ] **T013** [P] [US2] Fetched file names ([commands.md § 3.3](./contracts/commands.md#33-fetched-file-names)) (FR-005, FR-006):
  - Indexable Items: starting points `'./<dir1>' ['./<dir2>' ...]`, or `'./.'` without a filter; every leading `./` stripped; any line with a `..` segment or a leading `/` dropped.
  - Corpus Measurement, the Cache Integrity Check and the manifest hashing name an item only as `"$file"` and read it through redirection.
  - `.manifest.json` and `knowledge-index.md` are written with the file-writing tool, manifest strings escaped as JSON requires.
  - Names in the symbolic-link and conflict lines are escaped.

  · `commands/speckit.knowledge.sync.md`
- [ ] **T014** [P] [US3] Add the slug section of [ci.md § 3.3](./contracts/ci.md#33-sections-added): the block filled for each row of [commands.md § 4.3](./contracts/commands.md#43-reference-values) and run by sh, bash and zsh; stdout is the slug and a line feed, stderr is empty, exit is 0 (FR-008, FR-009, SC-007) · `.github/scripts/test-sync-git.sh`

**⟶ Wait for Wave 4 to finish, then:**

**Wave 5 — independent (different files):**

- [ ] **T015** [P] [US1] sync, per source and when pruning (FR-002, FR-004):
  - Print each refusal line before `🔄 Syncing cross-repo knowledge sources...`.
  - Check a slug's form before any use, and skip the source when it fails ([commands.md § 4.5](./contracts/commands.md#45-using-a-slug)).
  - Step 8a deletes a directory only under the three conditions of [§ 5.2](./contracts/commands.md#52-sync-pruning).

  · `commands/speckit.knowledge.sync.md`
- [ ] **T016** [P] [US2] Add the hostile file-name section of [ci.md § 3.3](./contracts/ci.md#33-sections-added): `$(touch pwned).md`, a name beginning with `-`, and two directories whose names hold a line break, one followed by `..` and one ending in it ([data-model.md § 6](./data-model.md#6-fetched-item-names)) (FR-006, SC-004) · `.github/scripts/test-sync-git.sh`

## Phase 3: User Story 1 - A configuration change cannot run commands (Priority: P1) 🎯 MVP

**Goal**: a value carrying shell syntax is refused before anything uses it, and every other source still syncs.
**Independent Test**: the refusal steps of [quickstart.md § 2](./quickstart.md#2-agent-walkthrough).

Files: `config-template.yml`, `README.md`.

### Implementation (US1)

**Wave 1 — independent (different files):**

- [ ] **T017** [P] [US1] In the `url` and `path_filter` comments, state the accepted characters; that a local path starts with `/`, `./`, `../` or `~/` and may also contain spaces, but no space followed by `-`; and that a `path_filter` is a folder name that does not begin with `~` (FR-011) · `config-template.yml`
- [ ] **T018** [P] [US1] § Configuration Reference: the same, for `sources[*].url` and `sources[*].path_filter`. § Trust model: the two defense rows of [knowledge-config.schema.md § 6](./contracts/knowledge-config.schema.md#6-where-the-rule-is-stated-fr-010-fr-011) after the validation-on-read row, and one bullet under "What does NOT happen": no configuration value and no fetched file name is ever run as a command (FR-010, FR-011) · `README.md`

**⟶ Wait for Wave 1 to finish, then:**

- [ ] **T019** [US1] Agent walkthrough of [quickstart.md § 2](./quickstart.md#2-agent-walkthrough) in a scratch consumer: sync by hand and from a hook, status, configure with a backtick, removing a refused source, no pruning while a source is refused, and every documented value accepted. `/tmp/sk007-pwned` never exists (SC-001, SC-002, SC-003) · (scratch consumer)

**Checkpoint**: US1 works on its own. A merged value with shell syntax is refused everywhere it is read, and nothing it carries runs.

## Phase 4: User Story 2 - Values reach the shell as data (Priority: P2)

**Goal**: every value reaches the shell as one literal argument, even past validation, and a regression fails the build.
**Independent Test**: the test script's sections for hostile values, a spaced path and hostile file names, plus a seeded unquoted placeholder.

Files: `.specify/memory/constitution.md`.

### Implementation (US2)

**Wave 1 — single task:**

- [ ] **T020** [US2] Add item 12 to § Quality Gates in the wording of [ci.md § 4](./contracts/ci.md#4-constitution), raise the version to 1.4.0 with the commit's date as Last Amended, and add a 1.4.0 rationale note. Its own `docs(constitution):` commit (FR-007, FR-012) · `.specify/memory/constitution.md`

**⟶ Wait for Wave 1 to finish, then:**

- [ ] **T021** [US2] Verify the second layer (SC-004, SC-005, SC-006):
  - The sections for hostile values, the spaced path and hostile file names pass on macOS and in the Podman run of [ci.md § 3.4](./contracts/ci.md#34-linux-run).
  - In a scratch copy of the repository, removing the quotes around one `<url>` fails check 12, naming that file and line.
  - In the scratch consumer, configure with `'~/My Repos/kb' specs/` keeps the path whole, and the source syncs and reports `✅ reachable (local)`.

  · (scratch copy, Podman, scratch consumer)

**Checkpoint**: US2 holds on its own. With validation bypassed nothing runs, and an unquoted placeholder fails the build.

## Phase 5: User Story 3 - The slug procedure runs as written (Priority: P2)

**Goal**: the procedure runs as written in sh, bash and zsh and yields the documented slug.
**Independent Test**: the slug section of the test script, and a cache the broken procedure named.

Files: none. The procedure is rewritten by T007 and tested by T014.

- [ ] **T022** [US3] Verify: the slug section passes on macOS and in the Podman run, where sh is dash. In a scratch consumer whose two unpinned sources share `cache/e3b0c44298fc/`, the next sync clones each source into its documented slug and prunes `e3b0c44298fc` (User Story 3 scenario 4, SC-007) · (Podman, scratch consumer)

**Checkpoint**: US3 works on its own. Every source gets its documented slug, and a cache the broken procedure shared is replaced.

## Phase 6: User Story 4 - Agent guidance points at the current feature (Priority: P3)

**Goal**: both agent guidance files name this feature.
**Independent Test**: compare the spec-kit section of both files with `.spec-context.json`.

Files: `AGENTS.md`.

- [ ] **T023** [US4] Confirm the Copilot instructions file names 007, then point the spec-kit section at it: `Active feature: 007-shell-safe-config`, links to the 007 spec, plan, research, data model, contracts, quickstart and tasks, and a status line saying the feature is in progress on its branch and not yet released. Change nothing outside that section. Its own `chore(agents):` commit (FR-013, SC-008) · `AGENTS.md`

**Checkpoint**: US4 is done. Agents are pointed at this feature.

## Phase 7: Polish

Files: `CHANGELOG.md`.

- [ ] **T024** Record under `[Unreleased]` (FR-012):
  - Security: the character rule, quoting, and fetched file names.
  - Fixed: the slug procedure, with a **Consequence** sentence: caches the broken procedure named are replaced once.
  - Changed: `~user/` local paths, `path_filter` wildcards and a leading `~` are refused; configure keeps a quoted argument whole; status shows `invalid`.
  - Development: static check 12 (`chore(ci)`), constitution 1.4.0 (`docs(constitution)`).
  - Documentation: the README changes (`docs(readme)`).

  No line for the `AGENTS.md` pointer · `CHANGELOG.md`

**⟶ Wait for T024 to finish, then:**

- [ ] **T025** Validate against the Success Criteria: run `validate-extension.sh` and `test-sync-git.sh` on macOS and in the Podman run, then map SC-001 to SC-008 to their evidence from T019, T021, T022 and T023 · (verification)

## Dependencies & Execution Order

- **Phases**: Setup (T001) → Foundational (T002 to T016) → the four story phases → Polish (T024, T025).
- **Foundational waves**: Wave 1 (T002, T003, T004) → Wave 2 (T005 to T008) → Wave 3 (T009 to T012) → Wave 4 (T013, T014) → Wave 5 (T015, T016). Two chains run through them: `sync.md` (T003, T007, T009, T013, T015) and the test script (T004, T008, T012, T014, T016). T005 and T006 copy the block T003 wrote.
- **Tests first**: once T004 changes `render()`, the script's checks that touch sparse-checkout fail until T009 quotes those snippets. T008 passes after T009, T012 after T009, T014 after T007, and T016 after T013.
- **Stories**: they own disjoint files, so they can run in parallel once Foundational is done. US1: Wave 1 (T017, T018) → T019. US2: T020 → T021. US3: T022. US4: T023.
- **Polish**: T024 → T025, last.
