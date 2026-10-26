# Tasks: Shell-recorded manifests, so a full knowledge sync fits in one turn

**Input**: [plan.md](./plan.md), [batch-corpus-measurement.spec.md](./batch-corpus-measurement.spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

`commands/speckit.knowledge.sync.md` and `.github/scripts/test-sync-git.sh` each serve every story, so both belong to the Foundational phase and are edited there one task at a time. User Story 1 owns no other file: the record run is built in Phase 1 and validated in Polish. Tasks marked **(maintainer)** need Copilot in VS Code or a machine this run cannot reach, and stay open for a person.

## Phase 1: Foundational

Files: `commands/speckit.knowledge.sync.md`, `.github/scripts/test-sync-git.sh`, `specs/011-batch-corpus-measurement/spike.md`

The recovery fix comes first because it does not depend on the spike. If the spike fails, it still ships, as 1.9.2 with the Story 4 documentation.

**Wave 1: independent (different files):**

- [x] **T001** [P] [US4] Add a `--recovery` group, with its flag and a place in the full run. It checks three things. A cold clone that fails leaves no directory that the next run takes the warm path into. The consuming repository's HEAD and `git status` are unchanged afterwards. With `max_cache_age` set, a missing manifest yields `verdict=stale` (FR-020, FR-021) · `.github/scripts/test-sync-git.sh`
- [x] **T002** [P] [US4] Make the Cache Freshness Gate read `stale` when `.manifest.json` is missing, and fix the comment. Add the path-choice block to step 4's **Determine sync path**: the warm path only when `cache/<slug>/.git` and `cache/<slug>/.manifest.json` both exist. Otherwise `rm -rf` that directory, after the `^[0-9a-f]{12}$` guard, and take the cold path ([contracts/commands.md § 5](./contracts/commands.md#5-recovery); FR-020, FR-021) · `commands/speckit.knowledge.sync.md`

**⟶ Wait for Wave 1 to finish, then:**

**Wave 2: independent (different files):**

- [x] **T003** [P] [US2] Add a `--records` group that composes § Indexable Items, § Item Records and the step 6 block through `block` and `render`, and runs them under sh, dash, bash and zsh. Fixtures: today's hostile names plus `"`, `\`, tab, CR, ESC, 0x01, DEL, U+0085, `guía.md`, a 4-byte emoji, a line-feed directory, links named with `"` and `\`, and a name that is not valid UTF-8 (Linux only, skipped with a note on APFS) · `.github/scripts/test-sync-git.sh`
  - Asserts: the manifest parses with JSON::PP; every path reads back byte for byte; `item_count` and every `sha256` match; no marker file exists; the `skipped-utf8:` line shows `\xHH`; the four shells write the same records.
  - Contract: [contracts/sync-checks.md](./contracts/sync-checks.md). Covers FR-004 to FR-007, FR-016, FR-017.
- [x] **T004** [P] [US2] Revise § Indexable Items: `LC_ALL=C` on each text tool, links from `ls-files -s -z` through `tr '\0' '\n'`, `! -path "*$nl*"` on `find`, and `$items` in byte order. Keep `$items` and `$links` as outputs ([contracts/commands.md § 2.1](./contracts/commands.md#21-indexable-items-revised); FR-005, FR-007) · `commands/speckit.knowledge.sync.md`

**⟶ Wait for Wave 2 to finish, then:**

- [x] **T005** [US1] Add § Item Records after § Indexable Items. It assigns `url='<url>'` and `revision='<revision>'` at the top and measures each item, stripping BSD padding. It hashes with `sha256sum` or `shasum -a 256`, turns each name into hex with `od`, and runs one awk encoder that validates UTF-8 strictly and writes the JSON and display forms. It sets the item lines, report and skipped names, and defines the renderer of [manifest.schema.md § 2](./contracts/manifest.schema.md#2-canonical-text) (FR-001, FR-002, FR-004, FR-006, FR-010) · `commands/speckit.knowledge.sync.md`

**⟶ Wait, then:**

- [x] **T006** [US1] Add the step 6 record block: `date -u`, `.manifest.json.tmp`, `mv -f`, then the report. Rewrite steps 5 and 6 as one record run per source. Replace "with the agent's file-writing tool, never a shell" for the manifest only, and keep the index agent-written. Cite 007 FR-014 for the schema version ([contracts/commands.md § 2.3](./contracts/commands.md#23-the-record-tail-step-6); FR-001, FR-003, FR-008, FR-009, FR-014, FR-019) · `commands/speckit.knowledge.sync.md`

**⟶ Wait, then: the spike gate**

- [x] **T007** [US2] Run `bash .github/scripts/test-sync-git.sh --records` on this Mac (BSD awk 20200816; sh, dash, bash, zsh; git 2.54) and record the result in `spike.md`. **Gate**: any failure stops the feature and returns it to shape (FR-016) · `specs/011-batch-corpus-measurement/spike.md`

**⟶ Wait, then:**

- [x] **T008** [US2] In podman, run `--records` inside the container's own file system on Ubuntu 20.04 (git 2.25, mawk, dash, zsh, perl, procps) and on a current Ubuntu with gawk, following 007 `contracts/ci.md` §3, and record each row in `spike.md`. A row that cannot run here, for want of an image or a registry, is recorded as pending for the maintainer (SC-006) · `specs/011-batch-corpus-measurement/spike.md`

**Checkpoint**: the spike passed. Story 1's record run and Story 2's file-name safety are testable.

**⟶ Wait for the gate, then:**

**Wave 3: independent (different files):**

- [x] **T009** [P] [US3] Add check-run cases to `--records` (FR-007, FR-011, FR-013) · `.github/scripts/test-sync-git.sh`
  - A manifest just written passes. One changed byte in an item fails. A 1.9.1-style manifest written by an agent in another layout fails. A missing manifest, or a malformed `synced_at` line, fails. The check deletes nothing.
- [x] **T010** [P] [US3] Replace the five numbered steps of § Cache Integrity Check with the check block: read the `synced_at` line, render, `cmp`, print the verdict and the report. State that callers act on the verdict, and that an older manifest fails once and is recorded again. Rewrite sync.md 349–351 and 1028–1032 ([contracts/commands.md § 2.4](./contracts/commands.md#24-the-check-tail-cache-integrity-check); FR-011, FR-013) · `commands/speckit.knowledge.sync.md`

**⟶ Wait for Wave 3 to finish, then:**

**Wave 4: independent (different files):**

- [x] **T011** [P] [US3] Wire the check into sync's callers ([contracts/commands.md § 4](./contracts/commands.md#4-callers-and-verdicts); FR-012, FR-014) · `commands/speckit.knowledge.sync.md`
  - **Policy-fresh path in step 4**: pass gives `current`, with the report's items and sizes feeding steps 7 and 7a; fail goes on as `stale`.
  - **§ On timeout or failure**: pass gives `cached`; fail or no `.git` gives `unreachable`.
  - **The all-tiers-failed fallback**: the same verdicts.
- [x] **T012** [P] [US2] Add the Item Records, step 6 and check blocks to `hostile_block`. Port the bash-only measurement loop (lines 366–380, `<<<`) to the composed record run. Keep every existing group green (FR-005, FR-017) · `.github/scripts/test-sync-git.sh`

**⟶ Wait for Wave 4 to finish, then:**

- [x] **T013** [US4] Add the step 9 line `⚠️ <N> file(s) skipped, name not valid UTF-8: …` under the links line, built from `skipped-utf8:` report lines. Correct § Corpus Measurement on BSD padding. Add sync's own statement that the first sync after an upgrade rebuilds every source and that running sync again completes a stopped one (FR-006, FR-018) · `commands/speckit.knowledge.sync.md`

## Phase 2: User Story 2, file names stay data (P1)

Files: `specs/007-shell-safe-config/research.md`

- [x] **T014** [US2] Under §7, third decision bullet, record that 011 revises it for the manifest only. The record run writes `.manifest.json`, and the index is still written with the agent's file tool (FR-019) · `specs/007-shell-safe-config/research.md`

**Checkpoint**: Story 2 is delivered. The `--records` group proves it, and the revision of the 007 decision is on record.

## Phase 3: User Story 3, status and search verify in one pass (P2)

Files: `commands/speckit.knowledge.status.md`, `commands/speckit.knowledge.search.md`

**Wave 1: independent (different files):**

- [x] **T015** [P] [US3] Make status step 2 run the check run for each source with a valid slug and a manifest. Pass takes `synced_at` and the item count from the `records:` line. Fail, or a manifest without `.git`, shows `corrupted`. Status stays read-only. Leave the duplicated validation block untouched (FR-012) · `commands/speckit.knowledge.status.md`
- [x] **T016** [P] [US3] Point search's step 1 at the check run. A failing source is set aside for this search, and nothing is deleted (FR-012) · `commands/speckit.knowledge.search.md`

**Checkpoint**: Story 3 is testable. Status on an intact cache passes per source, and one changed byte shows `corrupted`.

## Phase 4: User Story 4, the developer knows how an upgrade sync behaves (P3)

Files: `README.md`

- [x] **T017** [US4] Add three README Troubleshooting entries, in its emoji and bold-label style, and move the badge and install URL to 1.10.0 (FR-018) · `README.md`
  - The first sync after an upgrade rebuilds every source.
  - Running sync again completes one that stopped part-way.
  - A `corrupted` row after upgrading from 1.9.1 or earlier clears at the next sync.

**Checkpoint**: Story 4 is delivered.

## Phase 5: Polish

Files: `extension.yml`, `CHANGELOG.md`, `specs/011-batch-corpus-measurement/verification.md`

**Wave 1: independent (different files):**

- [x] **T018** [P] Set `version: 1.10.0` · `extension.yml`
- [x] **T019** [P] Add `## [1.10.0] - <release date>` with Added, Changed and Fixed sections, plus the compare links · `CHANGELOG.md`
  - **Added**: the record run and the check block.
  - **Changed**: status runs the check, and older manifests are recorded again once.
  - **Fixed**: a failed clone's directory reaching the project's repository; a missing manifest under a freshness policy; locale-dependent item loss; links named with quotes; line-feed fragments.

**⟶ Wait for Wave 1 to finish, then:**

- [x] **T020** Validate against Success Criteria. Run `bash .github/scripts/validate-extension.sh` and the full `bash .github/scripts/test-sync-git.sh`, and record the pass counts (SC-005, SC-006) · `specs/011-batch-corpus-measurement/verification.md`

**⟶ Wait, then:**

- [ ] **T021** (maintainer) Run quickstart §2 and §3. Baseline 1.9.1 first, then 1.10.0, both as cold syncs of `lookapp` on GPT-6 Luna and Claude Opus 5.5 in Copilot in VS Code. Record steps, wall time, one turn or not, and any reported departure (SC-001 to SC-004) · `specs/011-batch-corpus-measurement/verification.md`

**⟶ Wait, then:**

- [ ] **T022** (maintainer) Run quickstart §4 and §5 in `lookapp`, plus any matrix row T008 left pending, and record the results (SC-006, SC-007) · `specs/011-batch-corpus-measurement/verification.md`

## Dependencies & Execution Order

- **Phases**: Foundational, then Stories 2, 3 and 4 in any order or in parallel (they own disjoint files), then Polish.
- **Foundational**:
  - Wave 1 (T001, T002) blocks Wave 2 (T003, T004).
  - Wave 2 blocks T005, then T006, then the gate T007 and T008.
  - The gate blocks Wave 3 (T009, T010), which blocks Wave 4 (T011, T012), which blocks T013.
- **Story 2**: T014 alone. **Story 3**: one wave (T015, T016). **Story 4**: T017 alone.
- **Polish**: Wave 1 (T018, T019) blocks T020, then T021, then T022.
- **If the spike fails at T007**: stop. T001, T002 and T017 can still ship as 1.9.2.
