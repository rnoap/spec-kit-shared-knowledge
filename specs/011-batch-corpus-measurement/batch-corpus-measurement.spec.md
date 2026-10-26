# Feature Specification: Shell-recorded manifests, so a full knowledge sync fits in one turn

**Feature Branch**: `011-batch-corpus-measurement`
**Created**: 2026-10-26
**Status**: Draft
**Input**: "a partir del assess batch-corpus.." The assessment's verdict is go for Option C, behind a feasibility spike (`.specify/assessments/batch-corpus-measurement/decision.md`).

## Clarifications

### Session 2026-10-26

- Q: When sync skips a file because its name is not valid UTF-8, how should its report tell the developer? → A: One line under the source naming each skipped file, with every byte that is not valid UTF-8 shown as `\xHH`, like the skipped-links line.
- Q: Should a CI workflow run the sync checks on every pull request across all supported platforms, or should someone run that platform matrix by hand? → A: No CI change. The full matrix is run by hand for the spike and before this release, with the results recorded in the pull request.
- Q: Which models must complete the cold sync for the one-turn goal to count as met? → A: The two baseline models, GPT-6 Luna and Claude Opus 5.5, in the host the baselines used (Copilot in VS Code).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A full sync after an upgrade finishes in one turn (Priority: P1)

A developer upgrades the extension. The upgrade wipes the knowledge cache and the index, so the next sync rebuilds every source: in `lookapp`, 224 items across three sources. Today the agent copies every item's path and SHA-256 hash into each source's manifest by hand, about 14 KB of hex for this corpus. One model stopped before writing any manifest. Another finished only by scripting the manifests against the written rule. After this feature, the agent runs one procedure per source. That procedure collects, measures and hashes the items, writes the source's manifest, and reports each item's path and size. The agent writes the knowledge index from that report. The sync finishes in one turn, and the agent never handles a hash.

**Why this priority**: it is the failure observed in `lookapp`, and it recurs on every upgrade. Until a sync completes there is no index, and the knowledge section in `AGENTS.md` points at nothing.

**Independent Test**: empty the cache of the reference corpus and run sync once on each baseline model, GPT-6 Luna and Claude Opus 5.5. Each run ends with a manifest per source and the index in place, every source passes the integrity check, and the agent reports no departure from the procedure.

**Acceptance Scenarios**:

1. **Given** an empty cache and three enabled sources holding 224 items, **When** the developer runs sync, **Then** it completes in one turn with a manifest for each source and a knowledge index.
2. **Given** a source of any size, **When** sync records it, **Then** the agent runs one procedure for that source and types nothing into its manifest.
3. **Given** a source capped by the context budget, **When** sync records it, **Then** its manifest lists every indexable item while the index lists only the items within budget, as today.
4. **Given** a completed sync, **When** the integrity check runs on each source, **Then** every source passes.

### User Story 2 - File names stay data when the shell writes the manifest (Priority: P1)

File names come from whoever controls a source. Spec 007 kept them inert by having the agent's file tool, not a shell, write the manifest. This feature moves the manifest into a shell procedure, so the guarantee must now hold there. Every name, however hostile, reaches the manifest literally, as valid JSON, and never runs as a command.

**Why this priority**: it is the condition attached to the go verdict. A feasibility spike must prove it before any other work, and Story 1 cannot ship without it.

**Independent Test**: run the recording procedure over the hostile-name set of the automated sync checks, under every supported shell and platform. Read each manifest with a standard JSON reader, compare every name with the file on disk byte for byte, and look for marker files.

**Acceptance Scenarios**:

1. **Given** items named `$(touch pwned).md` and `-option.md`, **When** the procedure records the source, **Then** both names appear in the manifest exactly as on disk and no marker file exists.
2. **Given** names containing a double quote, a backslash, a tab, a carriage return or any other control character except a line feed, **When** the procedure records the source, **Then** the manifest is valid JSON and every name reads back unchanged.
3. **Given** a name that is not valid UTF-8, **When** the procedure records the source, **Then** the item is left out of the manifest and the index, the sync report names it under its source with each invalid byte shown as `\xHH`, and the source still passes the integrity check.
4. **Given** the same source recorded under each supported shell and platform, **When** the manifests are compared, **Then** they hold the same records.

### User Story 3 - Status and search verify a cache in one pass (Priority: P2)

Status, search and sync's fallback trust a cache only after the shared Cache Integrity Check. Today that check has the agent re-hash and compare every item. After this feature, one procedure run per source re-derives the records the manifest should hold and reports pass or fail. Verifying a 224-item cache costs a few steps, and the check agrees by construction with what sync recorded.

**Why this priority**: it removes the same per-item cost from every read of a large cache. Status and search already work without it, at a cost that grows with the item count.

**Independent Test**: run status on an intact cache of the reference corpus: each source passes from one run. Change one byte of one item and run status again: that source fails and is treated as corrupted, as today.

**Acceptance Scenarios**:

1. **Given** an intact cache, **When** status or search runs the check, **Then** each source passes from one procedure run.
2. **Given** an item changed, added or removed after sync, **When** the check runs, **Then** that source fails and is handled as corrupted, as today.
3. **Given** a manifest the procedure has just written, **When** the check runs, **Then** it passes.
4. **Given** a manifest written by an earlier version, **When** the check runs, **Then** the source either passes because its records match its files, or fails once and is rebuilt. It never passes with records that do not match.

### User Story 4 - The developer knows how a sync after an upgrade behaves (Priority: P3)

After an upgrade, the README and sync's own text tell the developer two things. The first sync after an upgrade rebuilds every source. A sync that stops part-way is completed by running sync again.

**Why this priority**: it costs almost nothing and turns a half-built cache into a known recovery step, but it changes no behavior.

**Independent Test**: read the README's troubleshooting section and the sync command: both state the two facts. Stop a sync after its first source, run sync again, and confirm that it completes.

**Acceptance Scenarios**:

1. **Given** a developer looking up an incomplete sync in the README's troubleshooting section, **When** they read it, **Then** it says the first sync after an upgrade is a full rebuild and that running sync again completes one that stopped.
2. **Given** a sync stopped after recording one of three sources, **When** the developer runs sync again, **Then** it completes and all three sources pass the integrity check.
3. **Given** a clone that failed and left an empty cache directory, **When** the developer runs sync again, **Then** sync clones that source afresh and no git command touches the project's own repository.

### Edge Cases

- A source with no indexable items gets a manifest recording zero items, and it passes the check.
- A path containing a line feed is left out of the manifest and the index, as today. It never yields a path outside the source, a phantom item or a duplicate.
- A clone that fails or stops part-way leaves nothing that a later sync mistakes for a cache, and no git command ever reaches the project's own repository.
- With a freshness policy configured, a source whose manifest is missing is refreshed, not skipped as fresh.
- A valid UTF-8 name with non-ASCII letters, such as `guía.md`, is recorded as is, not skipped.
- A symbolic link is skipped and reported, as today.
- An unpinned source records its revision as `null`, as today. A source value containing a character JSON must escape reads back unchanged.
- A source of thousands of items: the report of paths and sizes grows, the agent's steps do not.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Sync MUST record each source through one procedure run that collects, measures and hashes its items and writes its manifest, so the agent types nothing into the manifest.
- **FR-002**: The run that records a source MUST report each item's path and size to the agent, so budgeting and the index need no second measurement.
- **FR-003**: The manifest MUST list every indexable item of the source, whatever the context budget, as today.
- **FR-004**: Every file name and source value in the manifest MUST be escaped as JSON requires and MUST read back exactly as it is on disk or in the configuration.
- **FR-005**: A file name MUST NOT run as a command, act as an option or create a file, as spec 007 requires.
- **FR-006**: An item whose name is not valid UTF-8 MUST be left out of the manifest and the index, and the sync report MUST name every such item on one line under its source, as it names skipped symbolic links, with each byte that is not valid UTF-8 shown as `\xHH`.
- **FR-007**: Recording and checking MUST apply the same item rules, every skip rule included, so a manifest the procedure has just written always passes the check.
- **FR-008**: A manifest MUST appear whole or not at all: an interrupted sync MUST NOT leave a manifest that passes the check.
- **FR-009**: The manifest MUST still be written last, after every item of the source is in place, so its write time keeps marking when the cache became valid.
- **FR-010**: The manifest format MUST stay unchanged, its schema version included (see Verbatim Constraints), so search, status and every other reader keep reading it as today.
- **FR-011**: The shared Cache Integrity Check MUST re-derive a source's records in one procedure run and report pass or fail, with no hash compared by the agent.
- **FR-012**: Status, search, and sync's fallback and policy-fresh paths MUST use the one shared check by reference, and a source that fails it MUST be handled as corrupted, as today.
- **FR-013**: A manifest written by an earlier version MUST either pass because its records match its files, or fail once and be rebuilt; it MUST NOT pass with records that do not match.
- **FR-014**: The agent MUST still write the knowledge index, with budget allocation, conflict handling and messages unchanged.
- **FR-015**: Recording and checking MUST need no tool beyond what the extension already declares and a standard macOS or Linux install provides.
- **FR-016**: Recording and checking MUST behave the same under sh, bash and zsh, on macOS and on Linux back to Ubuntu 20.04 with git 2.25.
- **FR-017**: The automated sync checks MUST cover recording with a hostile-name set that holds today's hostile names, every character JSON must escape (double quote, backslash, and every control character except line feed) and a name that is not valid UTF-8. Each check MUST confirm valid JSON, names that read back unchanged and no marker file, and that the name that is not valid UTF-8 is left out and shown with `\xHH` escapes.
- **FR-018**: The README's troubleshooting section and the sync command MUST state that the first sync after an extension upgrade rebuilds every source, and that running sync again completes a sync that stopped part-way.
- **FR-019**: The revision of spec 007's rule that the agent's file tool writes the manifest MUST be recorded with that decision, limited to the manifest; the index stays agent-written.
- **FR-020**: Sync MUST treat a cache directory without a manifest or without its own git repository as an interrupted sync: remove it and clone again, so no git command ever acts on the project's own repository.
- **FR-021**: With a freshness policy configured, a source whose manifest is missing MUST be refreshed, not skipped as fresh.

### Key Entities

- **Source**: a configured knowledge repository, cached as a git checkout under its slug, with a URL and an optional pinned revision.
- **Item**: an indexable Markdown file of a source, with a path relative to the cache root, a size and a SHA-256 hash.
- **Manifest**: the per-source record of a cache: format version, source values, sync time, item count, and each item's path and hash. Its presence and validity mark a usable cache.
- **Knowledge index**: the agent-written summary of the items within the context budget, with conflict notes.
- **Skipped item**: an item left out of recording, either a symbolic link or a name that is not valid UTF-8, and named in the sync report under its source.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A cold full sync of the reference corpus completes in one agent turn on each of the two baseline models, GPT-6 Luna and Claude Opus 5.5, in the host the baselines used (Copilot in VS Code). Baseline: 0 of 1.
- **SC-002**: On each of those runs, the sync takes fewer than 23 agent steps as the host counts them, below every run measured so far (23 stopped, 28 and 38 completed).
- **SC-003**: On each of those runs, the sync takes less than 3 minutes 59 seconds of wall time, the fastest completed run so far (range: 3m59s to 14m25s).
- **SC-004**: In every run counted for SC-001, the agent reports no departure from the written procedure. Baseline: 0 of 1.
- **SC-005**: Recording causes zero integrity-check failures: every manifest the procedure writes, for the reference corpus and for the hostile-name set, passes the check.
- **SC-006**: All automated sync checks pass on each setup in the spike's matrix (see Assumptions): 229 of 229 today, plus the new ones. The maintainer runs that matrix by hand for the spike and again before release, and records the results in the pull request.
- **SC-007**: A cache recorded by an earlier version is rebuilt at most once after the upgrade, and is never served with records that do not match its files.

## Assumptions

- **The reference corpus is `lookapp` as of 2026-10-26**: three sources of 30, 50 and 144 items, 224 in total, 508,199 bytes.
- **The baselines are single runs.** GPT-6 Luna stopped a cold sync at 23 steps (4m11s). Claude Opus 5.5 completed a warm one in 28 steps (3m59s) by scripting the manifests. GPT-6 Luna completed a 115-item sync in 38 steps (14m25s). Before this ships, a cold run of 1.9.1 on each of the two baseline models, in the same host, is recorded with its full transcript. It shows where the failed run's 23 steps went and whether the stop repeats. If the stop came from cloning rather than recording, the correctness and adherence outcomes (SC-004, SC-005) still hold, and SC-001 needs its own look.
- **A feasibility spike comes first.** It is the plan's first task and runs over BSD awk, gawk and mawk; sh, bash and zsh; git 2.25 on Ubuntu 20.04 and current git. It passes when the hostile names produce valid JSON that Perl's core JSON::PP reads, names read back unchanged, no marker file appears, and names that are not valid UTF-8 are skipped and named with their invalid bytes shown as `\xHH`. macOS refuses such names, so that check runs on the Linux setups only. If it fails, work stops and returns to shape, where the fallback is Option B plus the documentation of Story 4, with Option D reopened.
- **The procedures live in the command text**, as § Indexable Items does, not in a separate script file (constitution §I and §III).
- **Adherence is judged from the agent's own report** at the end of the run, as in the baselines.
- **The index is not the next bottleneck.** About 13 KB of paths and budget reasoning fit in one turn: both completed runs wrote it, and the failed run stopped before it.
- **One rebuild of an older cache is acceptable.** Every upgrade already wipes the cache, so an older manifest that fails the new check costs no more than an upgrade does today.
- **Names that are not valid UTF-8 are rare in knowledge sources**, so skipping and reporting them is acceptable.
- **Out of scope**: generating the index from the shell; budget and conflict logic; any change to the manifest format; the network cost of clone and fetch; configure and remove; reworking warm syncs that leave the corpus unchanged; running the sync checks in CI, so the constitution's Quality Gates stay as they are. Asking spec-kit to keep extension caches across `specify extension add` is a separate upstream request: this feature neither needs nor blocks it.

## Verbatim Constraints

- `.specify/extensions/knowledge/cache/<slug>/.manifest.json`: the manifest path, unchanged
- `schema_version` stays `"1.0"`
- Top-level manifest keys, unchanged: `schema_version`, `source_url`, `source_slug`, `revision`, `synced_at`, `item_count`, `items`
- Per-item manifest keys, unchanged: `path`, `sha256`
- `knowledge-index.md`: stays agent-written
- `.github/scripts/test-sync-git.sh`: the automated sync checks that carry the hostile-name coverage
