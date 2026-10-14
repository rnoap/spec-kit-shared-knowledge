# Tasks: Catalog Readiness

**Input**: [catalog-readiness.spec.md](./catalog-readiness.spec.md), [plan.md](./plan.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/)

Format: `- [ ] **T###** [P?] [US#] Description · path`. `[P]` means independent of the other tasks in its wave.

## Phase 1: Setup

Files: none.

- [ ] **T001** Gate: the toolchain upgrade is already committed separately. Before implementation, also confirm that the prerequisite resolver fix and constitution 1.2.0 template-authorship amendment are committed separately from feature 006. The constitution must explicitly permit project-owned template edits. Pass when `git status --short` lists nothing outside `specs/006-catalog-readiness/` and the files the next task owns. Do not sweep pending prerequisite or unrelated changes into a feature commit · (repository state)

## Phase 2: Foundational

Files: `extension.yml`. Every story either restates or reads these values.

- [ ] **T002** Set `requires.speckit_version: ">=0.15.2"`, and add `category: integration` and `effect: read-write` under `extension:` (FR-001, FR-011) · `extension.yml`

## Phase 3: User Story 1 - Install from the catalog listing (P1)

**Goal**: a first-time user installs from the README alone, on a default setup.
**Independent Test**: on a fresh project with default settings, follow the README's install section, then run one command by the name the README says the agent shows.

Files: `README.md`

### Implementation (US1)

**Wave 1 — single task (README.md):**

- [ ] **T003** [US1] Restate the floor and add platforms: spec-kit badge to `spec--kit-%E2%89%A50.15.2` (L9); Prerequisites to spec-kit `>=0.15.2` (L31), plus "macOS and Linux; Windows through WSL or Git Bash" (FR-002, FR-010) · `README.md`

**⟶ Wait for Wave 1 to finish, then:**

**Wave 2 — single task (same file):**

- [ ] **T004** [US1] Rewrite § Installation's catalog subsection as [contracts/commands.md](./contracts/commands.md) § 1 states it (FR-004 to FR-008):
  - Spec-kit's community catalog is searchable, not installable, by default.
  - The primary install is `specify extension add knowledge --from <release zip URL>`, still on the `v1.5.0` tag, and spec-kit shows an `Untrusted Source` prompt the user confirms.
  - Teams that want no prompt list the extension in a catalog they control.
  - Never suggest marking the community catalog install-allowed, and never say plain `specify extension add knowledge` always fails.
  - Keep single-codepoint heading emojis.

  · `README.md`

**⟶ Wait for Wave 2 to finish, then:**

**Wave 3 — single task (same file):**

- [ ] **T005** [US1] Add one note at the top of § Commands: the examples use spec-kit's canonical dot form, skills-based agents show `/speckit-knowledge-sync`, and Codex shows `$speckit-knowledge-sync`. Leave every dot-form example in place, because static validation requires them (FR-009) · `README.md`

**⟶ Wait for Wave 3 to finish, then:**

- [ ] **T006** [US1] Verify in a throwaway project on spec-kit v1.2.0:
  - Serve a temporary catalog containing `knowledge` on `http://127.0.0.1:<port>/catalog.json`. Register it only in the temporary consumer with `specify extension catalog add <fixture URL> --name knowledge-fixture --no-install-allowed`. Plain `specify extension add knowledge` must fail as discovery-only. Do not depend on the public catalog, where the entry may not exist yet.
  - In a separate fresh consumer, the README's v1.5.0 `--from` command shows `Untrusted Source` and installs once confirmed. This checks the historical download route only; the current package is checked after the story join in T018.
  - Have the agent load and execute the installed `/speckit-knowledge-status` skill with no configured sources. It must report the unconfigured state successfully. The presence of a skill file alone is not a pass (FR-009).

  · (temp project)

**Checkpoint**: US1 is independently functional: the README alone gets a default setup to a working install.

## Phase 4: User Story 2 - A minimum spec-kit version that is true (P1)

**Goal**: every statement of the floor reads `>=0.15.2`, and spec-kit enforces it.
**Independent Test**: install on spec-kit v0.15.1, then on v0.15.2.

Files: `.specify/memory/constitution.md`, `.specify/templates/plan-template.md`

### Implementation (US2)

**Wave 1 — independent (different files):**

- [ ] **T007** [P] [US2] Amend the constitution in one `docs(constitution):` commit (FR-002, FR-003):
  - § Requirements & Compatibility: spec-kit `>=0.15.2`.
  - § Quality Gates › Install smoke test: runs twice, against the selected pinned release and against the minimum the manifest declares.
  - `**Version**: 1.3.0`, with `Last Amended` set to the commit date. Preserve the separate 1.2.0 template-authorship amendment.
  - A `> **1.3.0 rationale.**` note, in the existing style, saying why `>= 0.10.0` was false.

  · `.specify/memory/constitution.md`
- [ ] **T008** [P] [US2] Floor to `>=0.15.2` on L17, Primary Dependencies, and L42, the compatibility constraint (FR-002) · `.specify/templates/plan-template.md`
- [ ] **T009** [P] [US2] Verify in throwaway projects (FR-001, SC-002):
  - On spec-kit v0.15.1, `specify extension add <repo> --dev` is refused, with a message naming `>=0.15.2`, and installs nothing.
  - On v0.15.2, run `specify init . --integration copilot --force < /dev/null` (that release has no `--non-interactive`), then the install. It brings 5 commands, 4 hooks and `knowledge-config.yml`.

  · (temp projects)

**Checkpoint**: US2 is independently functional: spec-kit refuses a release below the floor, and the constitution and the template state it.

## Phase 5: User Story 3 - Complete catalog metadata (P2)

**Goal**: spec-kit shows the extension's category and effect.
**Independent Test**: install, then `specify extension info knowledge`.

Files: none. The manifest fields land in T002.

- [ ] **T010** [US3] Verify in a throwaway project on spec-kit v1.2.0: after `specify extension add <repo> --dev`, `specify extension info knowledge` prints `Category: integration` and `Effect: read-write` (FR-011, SC-007) · (temp project)

**Checkpoint**: US3 is independently functional: spec-kit displays both values.

## Phase 6: User Story 4 - The `--` separator everywhere the README promises it (P2)

**Goal**: every git call that takes a configured value separates it from options.
**Independent Test**: audit the git calls in `commands/`, then check reachability against a reachable remote.

Files: `commands/speckit.knowledge.status.md`

### Implementation (US4)

**Wave 1 — single task:**

- [ ] **T011** [US4] In § 3 Check reachability, change the call to `timeout 5 git ls-remote --exit-code -- <url> HEAD`. Keep `timeout 5`, which belongs to the separately tracked fix. The line sits outside the hashed Configuration Validation Rules block, so leave that block untouched (FR-012) · `commands/speckit.knowledge.status.md`

**⟶ Wait for Wave 1 to finish, then:**

- [ ] **T012** [US4] Verify (SC-006):
  - Every row of [contracts/commands.md](./contracts/commands.md) § 5 carries `--`.
  - In a temporary consumer installed from the working tree, have the agent execute the rendered status skill against the reachable remote `https://github.com/rnoap/spec-kit-shared-knowledge`. Verify the command reports reachable, not merely that a standalone Git call exits 0.
  - Run this reachability case on Linux with `timeout` available. On stock macOS it remains blocked by the separately tracked portability fix; report that limitation rather than substituting a different command and claiming a pass.
  - `bash .github/scripts/validate-extension.sh` still reports the three validation blocks byte-identical.

  · (no file)

**Checkpoint**: US4 is independently functional: the trust model's `--` promise holds for every configured operand.

## Phase 7: User Story 5 - CI proves the compatibility claim (P3)

**Goal**: every pull request installs on the floor and on the selected pinned release, and a broken install fails readably.
**Independent Test**: seed broken installs against the install check, and run the smoke steps at both versions.

Files: `.github/workflows/validate.yml`, `.github/scripts/assert-install.sh`

### Tests

Written first, so they fail first.

- [ ] **T013** [US5] Run seeds A and B from [contracts/ci.md](./contracts/ci.md) § 4.2 against today's script:
  - Seed A: a good install with every `• speckit.` line removed from `install.log`.
  - Seed B: `install.log` present, with neither `.specify/extensions/knowledge/` nor `.specify/extensions.yml`.
  - Confirm the defects: `integer expression expected`, `PASS installed file count is sane (0)`, and a `Traceback` (FR-016, FR-017).

  · (temp consumer)

### Implementation (US5)

**Wave 1 — independent (different files):**

- [ ] **T014** [P] [US5] Fix the install check per [contracts/ci.md](./contracts/ci.md) § 4.1 (FR-016, FR-017):
  - The command count is one integer: drop `|| echo 0`, and default an empty result to `0`.
  - 0 files fails with `install copied 0 files — the extension directory is missing or empty`. 30 or more files still fails, and `find` errors stay silent.
  - A missing `.specify/extensions.yml` fails with `manifest declares <n> hooks, 0 registered (.specify/extensions.yml is missing)` instead of a traceback.

  · `.github/scripts/assert-install.sh`
- [ ] **T015** [P] [US5] Update the workflow per [contracts/ci.md](./contracts/ci.md) §§ 1–3 (FR-013, FR-014, FR-015):
  - Set `SPEC_KIT_REF: v1.2.0`, keeping exactly one `SPEC_KIT_REF` declaration in the file.
  - Add job `smoke-minimum`, named `Install smoke test (minimum spec-kit)`.
  - The new job reads the version in the `>=` clause of `requires.speckit_version`, and fails, naming the field, when there is none.
  - It installs `v<floor>`, prints `specify --version`, and runs `specify init . --integration copilot --force < /dev/null`.
  - It then runs `specify extension add "$GITHUB_WORKSPACE" --dev`, tees the output to `install.log`, runs `assert-install.sh`, and uploads `install-log-minimum` on failure.
  - `Static validation` and `Install smoke test` keep their names.

  · `.github/workflows/validate.yml`

**⟶ Wait for Wave 1 to finish, then:**

- [ ] **T016** [US5] Verify (SC-004, SC-005):
  - Re-run seeds A and B. Each prints its readable FAIL line, with no shell or interpreter error, and exits 1.
  - Run the `smoke` and `smoke-minimum` steps locally at v1.2.0 and at the derived v0.15.2. Both pass the fixed script.

  · (temp consumers)

**Checkpoint**: US5 is independently functional. CI installs at both ends of the claim, and the install check catches both seeded failures.

## Phase 8: Polish

Files: `CHANGELOG.md`

- [ ] **T017** Record each concern under `## [Unreleased]`, in the house style `` `type(scope): summary` `` plus the reason (FR-018):
  - Changed: the floor, the README install, platforms and invocation note, the CI pin and minimum job, constitution 1.3.0 and the template floor.
  - Added: manifest `category` and `effect`.
  - Fixed: the status `--`, and the install check.
  - Leave the version at 1.5.0.

  · `CHANGELOG.md`

**⟶ Wait for T017 to finish, then:**

- [ ] **T018** Validate against the Success Criteria (SC-001 to SC-007):
  - After every story phase finishes, build a candidate ZIP from the current distributable working-tree bytes following [contracts/ci.md](./contracts/ci.md) § 5. Do not use v1.5.0 or an older `HEAD` as the source for this check.
  - Serve that ZIP on loopback and install it with `--from` after the source confirmation. Verify its manifest has `>=0.15.2`, `category: integration`, and `effect: read-write`, and its payload hashes match the working tree. The fixed `assert-install.sh` must pass against this installation.
  - Have the agent execute the candidate's rendered status skill with no sources and, on Linux with `timeout`, with the reachable remote from T012. Record actual command outcomes, not just skill-file existence.
  - `bash .github/scripts/validate-extension.sh` passes all 13 checks.
  - Inspect the six current declarations in [data-model.md](./data-model.md) § 2: each states `>=0.15.2`, URL-encoded in the badge. Historical input, rationale notes and released records may still quote `0.10.0`; do not reject those quotations.
  - T006, T009, T010, T012 and T016 have passed.
  - Confirm the CI half of SC-004 on the pull request before merge. Until a PR run exists, record that evidence as pending, not as a local pass.
  - Before publication, require the separately tracked macOS `timeout` fix and a passing real status invocation on macOS. Windows remains an explicitly untested platform assumption.

  · (no file)

## Dependencies & Execution Order

- **Setup → Foundational → stories → Polish.** T001 blocks everything, because no commit is safe until it passes. T002 blocks every story, since each restates or reads the manifest. The five story phases own disjoint files and can run in parallel. Polish waits for all of them.
- **US1**: T003 → T004 → T005, the same file and so one at a time, then T006.
- **US2**: wave T007 ∥ T008 ∥ T009.
- **US3**: T010 alone.
- **US4**: T011 → T012.
- **US5**: T013 first, so the tests fail first, then wave T014 ∥ T015, then T016.
- **Polish**: T017 → T018.
- **After merge, outside this feature**: a maintainer adds `Install smoke test (minimum spec-kit)` to the `main` ruleset's required checks.
