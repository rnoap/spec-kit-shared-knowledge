# Data Model: Point the agent at shared knowledge from AGENTS.md

This feature adds one configuration key and one owned block in a committed file.
It does not change the knowledge index, the cache or any existing key.

## Entity 1: `agents_md` configuration key

The project-wide switch for the knowledge section (FR-010, R1).

| Field | Value |
| --- | --- |
| Location | Top level of `.specify/extensions/knowledge/knowledge-config.yml`, beside `schema_version` and `sources`. |
| Type | Boolean. |
| Allowed values | Exactly `true` or `false`. `"yes"`, `no`, `1` and `0` are invalid, as for `enabled`. |
| Default | `true` when the key is absent. |
| Scope | Project-wide. No per-source form exists. |
| Readers | `speckit.knowledge.sync` step 1 and `speckit.knowledge.remove` step 3a. |
| Writers | The developer. `speckit.knowledge.configure` preserves it on edits (R10). |

### Validation rules

- A missing key means `true` (FR-010).
- `false` means sync and remove delete an existing section and otherwise leave `AGENTS.md` alone (FR-010).
- An invalid value produces one warning per run, and `AGENTS.md` is not created, updated or removed (R1).
- An invalid value never changes the sync result or exit code (FR-012).
- The validation-rules row for the key is byte-identical in configure, status and sync (quality gate 11).
- `--no-context-output` has no effect on this key or on `AGENTS.md` (R9).

### Schema version

The key is optional and every valid 1.1 file stays valid.
`schema_version` remains `"1.1"` (R2).

## Entity 2: Enabled label list

The derived input that decides the section's content and whether it exists.

| Field | Value |
| --- | --- |
| Source | The `label` of each source with `enabled` not `false` that passes validation. |
| Order | Configuration order (R7). |
| Computed by | Sync after step 8, and remove after its step 3 config write. |
| Empty list | Means the section is removed (FR-009, FR-015). |

Remove computes the list from the configuration after its change.
A removed or disabled source leaves the list at once, even though the index still describes it (FR-015, FR-016).

## Entity 3: Knowledge section

The block of root `AGENTS.md` this extension owns (FR-001).

### Markers (R3)

| Field | Value |
| --- | --- |
| Start marker | `<!-- KNOWLEDGE START -->`, matched as a whole line. |
| End marker | `<!-- KNOWLEDGE END -->`, matched as a whole line. |
| Well-formed | Exactly one start and one end, start before end. |
| Absent | No marker lines, or no `AGENTS.md`. |
| Damaged | Any other combination: an unpaired marker, duplicates, or end before start. |

Markers from other tools, such as `<!-- SPECKIT START -->`, are never matched (FR-006).

### Content (R7, R8)

The lines between the markers hold, in order:

1. An instruction to read the index first for any question about another repository or a configured source (FR-002).
2. The project-relative index path, `.specify/extensions/knowledge/knowledge-index.md` (FR-008).
3. An instruction to open the files the index lists and cite them as `<label> › <relative-path>` (FR-002).
4. An instruction to use only the index entries of the listed sources (FR-003).
5. An instruction to suggest running sync when the index, a listed source's entries, or one of its files is missing (FR-002).
6. The sync command by its canonical id, `speckit.knowledge.sync`, identical on every host (research R8).
7. One line per entry of the enabled label list, as `- ` followed by a code span (FR-003).

The exact text is in [contracts/agents-md-section.md](./contracts/agents-md-section.md).

### Validation rules

- At most 12 lines between the markers, plus one line per label (FR-004).
- No timestamps, item counts, absolute paths or content read from a source (FR-008).
- Each label is escaped under "Values in messages (007 FR-005)" (FR-013).
- A label containing a backtick is wrapped in a code span whose backtick run is longer than any run inside it (R7).
- Every label line starts with `- `, so a label can never match a whole-line marker (R3, FR-013).
- The same configuration produces the same bytes on every machine (FR-007, SC-002).

### Placement (R5)

| Operation | Rule |
| --- | --- |
| Write, file missing | Create `AGENTS.md` with the section and a final newline only (FR-005). |
| Write, section absent | Ensure the file ends with a newline, append one empty line, then the section. |
| Write, section present | Replace the start-to-end lines in place. Skip the write when the bytes are equal (FR-007). |
| Remove | Delete the start-to-end lines and one empty line directly above them, if present. |
| Remove, file left blank | Delete `AGENTS.md` when only whitespace remains. |

Every byte outside the section is preserved in every operation (FR-006, SC-003).
Write followed by remove leaves a pre-existing file byte-identical (R5).

### Relationships

- The section points to the knowledge index and never copies from it.
- The section lists the enabled label list, which comes from the configuration.
- `agents_md` gates whether the section may exist.
- Sync and remove apply one shared procedure, § Agent Context Section in `speckit.knowledge.sync.md` (R4).
- Remove never writes the index (FR-016).

## Entity 4: AGENTS.md outcome

The one-line result in the sync and remove reports (FR-014).

| Value | Meaning |
| --- | --- |
| created | `AGENTS.md` did not exist and now holds only the section. |
| updated | The section was added or replaced. |
| unchanged | The computed section equals the present one, so no write happened. |
| removed | The section was deleted, and the file too if nothing else remained. |
| warning | Damaged markers, an invalid `agents_md`, or a read or write failure. The file is untouched. |

A warning never changes the command's result or exit code (FR-011, FR-012, SC-004).
When remove runs with no index present, it reports no outcome and does not touch `AGENTS.md` (FR-015).

## State transitions

States of the knowledge section, from plan.md "States".

| From | Event | To | Outcome |
| --- | --- | --- | --- |
| absent | Sync writes the index, `agents_md` on, at least one enabled source | present, matching the labels | created or updated |
| present | Sync or remove, labels unchanged | present, file not written | unchanged |
| present | Sync or remove, labels changed | present, replaced in place | updated |
| present | Sync step 1a deletes the index | absent | removed |
| present | Remove leaves no enabled source | absent | removed |
| present | Sync or remove with `agents_md: false` | absent | removed |
| absent | Sync or remove with `agents_md: false` | absent, file not touched | unchanged |
| damaged | Any write or remove | damaged, file untouched | warning |
| any | `agents_md` invalid | unchanged, file untouched | warning |
| any | Remove, disable or enable with no index | unchanged, file untouched | none |

### Guards

- Sync removes the section only when it deletes the index in step 1a or when `agents_md` is `false` (R6, FR-009).
- A sync that ends with no index and had none before, such as a first sync with every source unreachable, does not touch `AGENTS.md` (R6).
- A sync that fails every source while an earlier index remains keeps the section.
- Remove writes the section only when `knowledge-index.md` exists (FR-015).
- Configure never applies the section, because no index exists before the first sync.
- A damaged section leaves the state damaged until the developer fixes the markers by hand (FR-011).
