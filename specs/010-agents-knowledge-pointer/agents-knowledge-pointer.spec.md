# Feature Specification: Point the agent at shared knowledge from AGENTS.md

**Feature Branch**: `010-agents-knowledge-pointer`
**Created**: 2026-10-22
**Status**: Draft
**Input**: "que `sync` agregue a `AGENTS.md` una sección breve indicando que, ante preguntas sobre otros repos o fuentes configuradas, el agente consulte primero `knowledge-index.md`."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ask about another repository in plain language (Priority: P1)

A developer has configured and synced knowledge sources. In an ordinary chat, with no spec-kit command running, they ask "how does ending-inventory handle stock adjustments?". Today the agent does not know the synced knowledge exists, and its file search skips the cache because it is git-ignored. After this feature, the project's agent instructions tell it to read the knowledge index first. The agent answers from the synced documents and cites them as `<label> › <path>`.

**Why this priority**: it is the whole point of the feature. Without it, synced knowledge only reaches the agent inside the spec-kit workflow.

**Independent Test**: sync one source, open a new chat, ask a question about that source without naming any file or command. The answer cites a file from the index.

**Acceptance Scenarios**:

1. **Given** a project with one enabled source and no knowledge section in AGENTS.md, **When** sync completes and writes the index, **Then** AGENTS.md contains the knowledge section, and that section tells the agent to read the index first for questions about other repositories or configured sources.
2. **Given** the section is present, **When** a developer asks about a configured source by its label or repository name, **Then** the agent can recognize the source from the label list in the section.
3. **Given** the project has no AGENTS.md, **When** sync completes and writes the index, **Then** sync creates AGENTS.md containing only the knowledge section.

### User Story 2 - Keep the section accurate without touching anything else (Priority: P1)

The developer syncs again and again, adds and removes sources, and commits AGENTS.md with the rest of the project. The knowledge section always matches the enabled sources. Everything else in AGENTS.md, including sections other tools manage, stays exactly as it was.

**Why this priority**: AGENTS.md is a shared, committed file. A tool that duplicates its section, rewrites other content, or creates noise in every diff would be removed by the team.

**Independent Test**: run sync twice with no configuration change and confirm AGENTS.md is byte-identical after the second run. Then remove a source, sync, and confirm only the label list changed.

**Acceptance Scenarios**:

1. **Given** the section is present and up to date, **When** sync runs again with the same sources, **Then** AGENTS.md is not modified.
2. **Given** AGENTS.md has other content before and after the section, **When** sync updates the section, **Then** every byte outside the section is unchanged.
3. **Given** a source was added or removed since the last sync, **When** sync writes the index, **Then** the section's label list matches the enabled sources and nothing else in the section changes.
4. **Given** sync deletes the index because no enabled source remains, **When** it finishes, **Then** the knowledge section is removed from AGENTS.md, and the rest of the file is left intact.

### User Story 3 - Removing or disabling a source takes effect for the agent at once (Priority: P2)

The developer runs remove, or remove with `--disable`, on a source. The index still lists that source until the next sync, and after a removal its cached files are gone. From that moment on, the agent stops using the source in ordinary chats. The developer does not have to remember to sync first. Re-enabling a source puts its label back.

**Why this priority**: without it, the section from Stories 1 and 2 would steer the agent toward knowledge the developer just turned off, or toward deleted files.

**Independent Test**: sync two sources, disable one, and ask about it in a fresh chat without syncing. The agent does not answer from it and suggests running sync.

**Acceptance Scenarios**:

1. **Given** the section lists sources A and B, **When** the developer removes or disables B, **Then** the section lists only A, and the knowledge index is not modified.
2. **Given** the section lists only A, **When** the developer removes or disables A, **Then** the section is removed from AGENTS.md.
3. **Given** B is disabled and the index exists, **When** the developer re-enables B, **Then** the section lists A and B again. If B has no entries in the index yet, the agent suggests running sync when asked about B.
4. **Given** the project has never been synced, so no index exists, **When** the developer removes, disables or enables a source, **Then** AGENTS.md is not created or modified.

### User Story 4 - Turn it off (Priority: P2)

A team that writes its own agent instructions does not want a tool editing AGENTS.md. They switch the behavior off in the knowledge configuration, and sync stops writing the section.

**Why this priority**: AGENTS.md belongs to the team. A tool that edits it must be easy to stop, or teams will avoid the extension.

**Independent Test**: turn the option off, sync, and confirm AGENTS.md is untouched.

**Acceptance Scenarios**:

1. **Given** the behavior is turned off and AGENTS.md has a knowledge section from an earlier sync, **When** sync runs, **Then** the section is removed and nothing else changes.
2. **Given** the behavior is turned off and AGENTS.md has no knowledge section, **When** sync runs, **Then** AGENTS.md is not created or modified.

### Edge Cases

- **Unchanged section:** the section is generated with no timestamps and no per-machine paths, so two developers syncing the same configuration produce the same section and no diff.
- **Damaged markers:** a start marker without an end marker, or more than one section, is not guessed at. Sync leaves AGENTS.md untouched, warns once with the fix, and still completes.
- **Hostile label:** a source label containing marker text such as `-->` or markdown cannot close the section early or inject instructions. Labels are shown as escaped literal values.
- **Unreadable or read-only AGENTS.md:** sync reports a warning and still completes with the index written. A failure here never fails the sync.
- **Partial or failed sync:** if every source is unreachable and an index from an earlier sync is still in use, the section stays. The section exists exactly when the index exists, the behavior is on, and at least one source is enabled.
- **Stale index between remove and sync:** the index can still list a source that was removed or disabled, with files that no longer exist. The agent uses only the sources the section lists, so it never reads those entries.
- **A source's own AGENTS.md:** a source repository's AGENTS.md, including any knowledge section in it, is never cached or indexed. The default exclusions released in 1.8.1 already drop it, so one project's pointer never reaches another.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: After a sync that writes the knowledge index, the project's root AGENTS.md MUST contain one knowledge section, delimited by start and end markers unique to this extension.
- **FR-002**: The section MUST tell the agent that, for any question about another repository or a configured knowledge source, it reads the knowledge index first, then opens the files the index lists, and cites them as `<label> › <relative-path>`. When the index is missing, as on a teammate's fresh clone, or when a listed source has no entries in it or one of its files is missing, the section MUST tell the agent to suggest running sync instead of guessing.
- **FR-003**: The section MUST list the labels of the enabled sources, and MUST tell the agent to use only the index entries of those sources.
- **FR-004**: The section MUST stay brief: at most 12 lines between its markers, plus one line per source label.
- **FR-005**: Sync MUST create AGENTS.md when it is absent, containing only the knowledge section.
- **FR-006**: Sync MUST leave every byte of AGENTS.md outside the knowledge section unchanged, including sections managed by other tools.
- **FR-007**: Sync MUST NOT modify AGENTS.md when the section it would write is identical to the one present.
- **FR-008**: The section MUST NOT contain timestamps, item counts, absolute paths or any content read from a source.
- **FR-009**: When sync deletes the knowledge index, it MUST remove the knowledge section in the same run.
- **FR-010**: The knowledge configuration MUST offer an option that turns this behavior off. While it is off, sync removes an existing section and otherwise leaves AGENTS.md alone. The behavior is on by default.
- **FR-011**: When AGENTS.md has damaged or duplicated knowledge markers, sync MUST leave the file unchanged and report a warning naming the problem and the fix.
- **FR-012**: A failure to read or write AGENTS.md MUST be reported as a warning and MUST NOT change the sync's result or exit code.
- **FR-013**: Source labels MUST appear in the section as escaped literal values that cannot end the section or add instructions to it.
- **FR-014**: The completion reports of sync and remove MUST say whether AGENTS.md was created, updated, left unchanged, or had the section removed.
- **FR-015**: After remove changes the configuration, whether it removes, disables or enables a source, it MUST update the section to list the enabled sources, or remove the section when none remains. It applies the same rules as sync: FR-006, FR-007, FR-010, FR-011, FR-012 and FR-013. It writes the section only when the knowledge index exists.
- **FR-016**: Remove MUST NOT modify the knowledge index. Sync remains its only writer.

### Key Entities

- **Knowledge section**: the part of AGENTS.md this extension owns. It holds the instruction to consult the index, the index location, the citation format, and the list of enabled source labels. It exists exactly when the knowledge index exists, the behavior is on, and at least one source is enabled. Sync and remove both write it from the same rules.
- **Agent context option**: a setting in the knowledge configuration that turns the section on or off for the project.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In a fresh chat, with no command and no file named, a question about a synced source is answered with at least one citation from the knowledge index in 4 of 5 trials.
- **SC-002**: Two consecutive syncs with an unchanged configuration leave AGENTS.md byte-identical: 0 changed bytes.
- **SC-003**: Across create, update, removal and opt-out runs, 0 bytes outside the knowledge section change.
- **SC-004**: No sync fails because of AGENTS.md: every damaged-marker, read-only and missing-file case completes with the index written and a warning shown.
- **SC-005**: The section is at most 12 lines plus one per source.
- **SC-006**: After a source is removed or disabled, and before any sync, 0 of 5 fresh-chat questions about it are answered from its index entries.

## Assumptions

- **AGENTS.md is the target.** The request names it, and agents such as Copilot in VS Code, Codex and others read it. Other instruction files, such as `CLAUDE.md` and `.github/copilot-instructions.md`, are out of scope for this version.
- **Sync and remove write the section; configure does not.** Configure runs before any index exists. Remove updates only the section, never the index. Rebuilding the index stays sync's job, so remove gains no network access and no index logic. The section's source list hides the stale index entries until the next sync.
- **On by default.** The developer asked for the behavior, and an opt-in option would leave most projects without it. Teams that object turn it off (FR-010).
- **The section points; it does not summarize.** It carries no knowledge content, so it stays brief and stable, and the index remains the single source of truth.
- **The section is committed with AGENTS.md.** It holds no per-machine data (FR-008), so committing it is safe and it reaches teammates. They still need their own sync to have the index it points to.

## Verbatim Constraints

- `AGENTS.md`
- `knowledge-index.md` (at `.specify/extensions/knowledge/knowledge-index.md`)
- `sync`: the command that writes the section (`speckit.knowledge.sync`)
- `speckit.knowledge.remove`: also updates the section, including with `--disable` and `--enable`
