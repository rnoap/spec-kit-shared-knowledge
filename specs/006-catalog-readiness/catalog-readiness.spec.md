# Feature Specification: Catalog Readiness

**Feature Branch**: `006-catalog-readiness`

**Created**: 2026-10-14

**Status**: Draft

**Input**: User description: "1. `speckit_version: ">=0.10.0"` es falso. Con 0.10.0 la config no se crea al instalar (comprobado), y los tokens dentro de skills solo se resuelven desde 0.12.17. Hay que subirlo a `>=0.15.2`, que sí pasa el smoke test, en el manifest, el badge y Prerequisites. 2. La instalación desde el catálogo fallará con el README actual. Por defecto spec-kit no permite instalar desde el catálogo community, solo buscar (`install_allowed=False`). Hay que documentar `--from <zip>` (pide confirmar "Untrusted Source") o `catalog add … --install-allowed`. 3. El nombre del comando depende del agente. Con 1.1.2, Copilot se instala como skills y se invoca `/speckit-knowledge-sync`, no `/speckit.knowledge.sync`. Basta una nota en el README. 4. Faltan dos campos en `extension.yml`. Añadir `category: integration` y `effect: read-write`; 180 de las 181 entradas del catálogo los tienen. 5. Falta un `--` en `speckit.knowledge.status.md:128`. Es la única llamada a git sin `--` antes de `<url>`, aunque el README promete que todas lo llevan. Comprobé que `git ls-remote --exit-code -- <url> HEAD` funciona. Menores: CI: subir `SPEC_KIT_REF` de v1.0.4 a v1.2.0 y añadir un job con la versión mínima (0.15.2 no tiene `--non-interactive`). `assert-install.sh L53-L54`: `|| echo 0` produce "0\n0" y rompe el `[`. Además, la comprobación del número de archivos pasa con 0 archivos. README: indicar las plataformas soportadas (macOS/Linux; Windows con WSL o Git Bash)."

Before Shared Knowledge goes to the spec-kit community catalog, the package has to tell a first-time user the truth: which spec-kit versions it works with, how to install it from the catalog, what their agent calls the commands, and what it does to their project. This feature fixes the places where it does not, and makes CI prove the compatibility claim on every pull request. The four sync defects found in the same review are tracked separately.

## Clarifications

### Session 2026-10-14

- Q: Should the README offer marking the community catalog install-allowed as an alternative to `--from`? → A: No. spec-kit's own messages call that flag the vetting boundary ("Don't flip a discovery-only catalog to install_allowed"), and `catalog add` writes a project catalogs file that replaces spec-kit's built-in list, silently dropping its `default` catalog. The README documents `--from`, and points teams to a catalog they control, which is the route spec-kit recommends. Found during planning and verified in spec-kit 1.1.2's source; the request offered the two routes as alternatives, so `--from` alone still satisfies it.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Install from the catalog listing (Priority: P1)

A developer finds Shared Knowledge with `specify extension search`, opens the README and installs it. Today the README tells them to run `specify extension add knowledge`, which fails on a default setup: spec-kit lets users search the community catalog but not install from it. After this change, the README's install steps work on a default setup, say which platforms are supported, and tell the reader what name their agent gives the commands.

**Why this priority**: Installing is the first thing every catalog user does. If it fails, nothing else in the extension matters.

**Independent Test**: In a fresh project with default spec-kit settings, follow only the README's install section, then run one knowledge command by the name the README says the agent shows.

**Acceptance Scenarios**:

1. **Given** a fresh project with default catalog settings, **When** the user runs the README's primary install command, **Then** spec-kit asks them to confirm the source and, once confirmed, installs the extension.
2. **Given** a team that lists the extension in a catalog it controls and has marked install-allowed, **When** a member runs `specify extension add knowledge`, **Then** it installs without the confirmation, as the README says.
3. **Given** an agent that registers commands as skills, **When** the user looks for the sync command, **Then** the README has told them it appears as `/speckit-knowledge-sync`.
4. **Given** a Windows user, **When** they read the prerequisites, **Then** they learn they need WSL or Git Bash.

---

### User Story 2 - A minimum spec-kit version that is true (Priority: P1)

A developer on an older spec-kit installs the extension. Today the manifest says 0.10.0 is enough, but on 0.10.0 the install skips the configuration file, and before 0.12.17 skills-based agents get command cross-references left unrendered. After this change the declared minimum is 0.15.2, the oldest version verified to install correctly. An older spec-kit refuses the install and names the version it needs.

**Why this priority**: A false minimum produces half-working installs that look like extension bugs, and get reported as such.

**Independent Test**: Install on a spec-kit just below 0.15.2, then on 0.15.2.

**Acceptance Scenarios**:

1. **Given** spec-kit older than 0.15.2, **When** the user installs, **Then** spec-kit refuses and names 0.15.2 as the requirement.
2. **Given** spec-kit 0.15.2, **When** the user installs, **Then** the 5 commands, the 4 hooks and the configuration file are all installed.
3. **Given** the repository, **When** a reader checks every place that states the minimum, **Then** each says 0.15.2.

---

### User Story 3 - Complete catalog metadata (Priority: P2)

A developer browsing the catalog, or reading the extension's details in spec-kit, sees its category and whether it changes files in their project. Today the manifest declares neither, while 180 of the 181 catalog entries do.

**Why this priority**: The listing works without it, but looks incomplete and leaves the category to the catalog maintainers.

**Independent Test**: Install the extension and run `specify extension info knowledge`.

**Acceptance Scenarios**:

1. **Given** the installed extension, **When** the user runs `specify extension info knowledge`, **Then** it shows category `integration` and effect `read-write`.

---

### User Story 4 - The `--` separator everywhere the README promises it (Priority: P2)

A reviewer relies on the README's trust model, which says `--` comes before every configuration-derived git operand. Today the status command's reachability check passes the source URL without it. After this change every git call keeps that promise.

**Why this priority**: Validation already rejects option-shaped values, so this is the second line of defense. It only matters once the first one is bypassed, which is exactly when it has to hold.

**Independent Test**: List every git call in the command files that takes a configured value, then run status against a configured remote source.

**Acceptance Scenarios**:

1. **Given** the command files, **When** a reviewer lists the git calls that take a configured value, **Then** each has `--` before that value.
2. **Given** a reachable remote source, **When** the user runs status, **Then** it reports the source as reachable, as before.

---

### User Story 5 - CI proves the compatibility claim (Priority: P3)

A maintainer opens a pull request. Today CI installs only against spec-kit 1.0.4: older than what new users run and newer than the claimed minimum, so neither end of the claim is tested. After this change every pull request installs against the declared minimum and the selected supported release, and the install check reports a broken install clearly.

**Why this priority**: Without it, the minimum drifts back into fiction the next time spec-kit changes.

**Independent Test**: Open a pull request that breaks installation on one of the two versions and watch that version's check fail with a readable message.

**Acceptance Scenarios**:

1. **Given** a pull request, **When** CI runs, **Then** the install smoke test runs against spec-kit v1.2.0 and against v0.15.2, and the two checks the main branch requires still report under their current names.
2. **Given** an install that registered no commands, **When** the install check runs, **Then** it fails with its normal message, reports the count as 0, and prints no shell error.
3. **Given** an install that copied no files, **When** the install check runs, **Then** the file-count check fails.

### Edge Cases

- A project that already trusts the community catalog can install with plain `specify extension add knowledge`, so the README must not say that command always fails.
- The confirmation prompt needs a terminal, so a scripted `--from` install aborts. The README does not document a way around a security prompt.
- The `--from` example names one release. At release time it must name the tag that matches the manifest version, or catalog users install an older release.
- Before catalog submission the public id may be absent. Pre-publication checks must reproduce discovery-only behavior with a controlled catalog instead of requiring the public entry to exist.
- A successful install of the previous release does not prove the new package. Distribution checks must also exercise the current candidate after all edits are complete.
- spec-kit 0.15.2 has no non-interactive flag for project setup, and the minimum-version job must still run unattended.
- The main branch requires the checks named "Static validation" and "Install smoke test". Renaming either blocks every merge. The new check gates merges only once a maintainer adds it to the branch rules.
- Local paths written `/`, `~/` or `./` never reach the reachability call in status. A `../` path, which configure accepts, is treated as remote by status and does reach it; with `--` its result is unchanged.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The manifest MUST declare the minimum spec-kit version as `>=0.15.2`.
- **FR-002**: Every other current declaration of the minimum MUST state the same value: the README badge, the README prerequisites, the constitution's Requirements & Compatibility, and the project's plan template.
- **FR-003**: The constitution change MUST follow its Governance rule: a `docs:` commit with a rationale note, and the constitution's version and amendment date updated.
- **FR-004**: The README MUST say that spec-kit's community catalog is searchable but not installable by default.
- **FR-005**: The README's primary install instruction MUST work on a default setup, using `specify extension add knowledge --from <release archive URL>`.
- **FR-006**: The README MUST say that spec-kit asks the user to confirm the source during that install.
- **FR-007**: The README MUST point teams that want to skip the prompt to the route spec-kit recommends: listing the extension in a catalog they control.
- **FR-008**: The README MUST NOT suggest marking the community catalog install-allowed.
- **FR-009**: The README MUST tell the reader that their agent may show the commands under another name than the dot form used in the examples, naming at least the skills form `/speckit-knowledge-sync`.
- **FR-010**: The README MUST state the supported platforms: macOS and Linux; Windows through WSL or Git Bash.
- **FR-011**: The manifest MUST declare `category: integration` and `effect: read-write`.
- **FR-012**: The status command's reachability check MUST put `--` between its options and the source URL.
- **FR-013**: The gating install smoke test MUST install against spec-kit `v1.2.0`.
- **FR-014**: CI MUST run the same install smoke test against the declared minimum, spec-kit `v0.15.2`, on every pull request.
- **FR-015**: The checks the main branch requires, "Static validation" and "Install smoke test", MUST keep reporting under those names.
- **FR-016**: When an install registers no commands, the install check MUST fail with its normal message and a count of 0, without a shell error.
- **FR-017**: The install check MUST fail when the install copied no files.
- **FR-018**: Each change MUST be recorded under `[Unreleased]` in the CHANGELOG.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On a fresh project with default settings, the README's primary install command installs the extension on the first try once the user confirms the source.
- **SC-002**: A user on a spec-kit older than the minimum gets a refusal naming the required version, never an install that lacks its configuration file.
- **SC-003**: 100% of the repository's current minimum-version declarations read `>=0.15.2`; historical quotations retain their original values.
- **SC-004**: Every pull request proves installation on 2 spec-kit versions, the declared minimum and the selected supported release. A change that breaks either shows a failing check.
- **SC-005**: Both seeded broken installs, no commands registered and no files copied, fail the install check with a readable message and no shell error: 2 of 2.
- **SC-006**: 100% of the commands' git calls that take a configured value separate it from options, up from all but one.
- **SC-007**: The extension's details, as spec-kit displays them, show a category and an effect.

## Assumptions

- 0.15.2 is the floor because it is the first version that creates the configuration file on install. Skills have rendered command references correctly since 0.12.17. On 2026-10-14, installs passed on 0.15.2, 1.1.2 and 1.2.0, and the configuration file was missing on 0.10.0. Versions in between are claimed as a range, not tested one by one.
- spec-kit refuses an install below the declared minimum with a message naming it, as its 1.1.2 source shows.
- spec-kit's own guidance, not this extension, sets the trust boundary: it calls `--install-allowed` on a discovery-only catalog the vetting boundary, so the README offers no way across it.
- `integration` fits because the extension brings in content from other repositories, like the catalog's Confluence and Work IQ entries. `read-write` fits because it writes its configuration, its cache, its index and the project's `.gitignore`.
- Constitution 1.2.0 explicitly permits authored project templates. The feature's later compatibility and CI amendment advances it to 1.3.0; neither change is justified by overriding the constitution in a feature plan.
- This feature bumps no version and tags nothing. Its changes wait under `[Unreleased]` for the release that also carries the separately tracked sync fixes.
- The platform statement includes macOS. It becomes accurate once the separately tracked `timeout` fix lands, and both ship in the same release.
- Windows support is stated, not exercised by CI.
- Adding the minimum-version check to the main branch rules is a repository setting outside this change.

## Out of Scope

- The four sync defects from the same review: pinning to a full commit, files deleted upstream surviving a sync, `timeout` missing on macOS, symbolic links being indexed.
- Version bump, tag, release, and the catalog submission itself.
- GitHub repository topics and homepage.
- Rewriting the README examples into another invocation form.

## Verbatim Constraints

- Minimum spec-kit version: `>=0.15.2`
- Manifest fields: `category: integration`, `effect: read-write`
- Reachability call: `git ls-remote --exit-code -- <url> HEAD`
- Gating CI pin: `SPEC_KIT_REF` set to `v1.2.0`
- Minimum-version CI job: spec-kit `0.15.2`, which has no `--non-interactive`
- Install flag the README names: `--from`
- Prompt title spec-kit shows on a `--from` install: `Untrusted Source`
- Invocation forms: `/speckit.knowledge.sync` (dot), `/speckit-knowledge-sync` (skills)
