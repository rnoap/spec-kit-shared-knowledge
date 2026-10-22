# Research: Point the agent at shared knowledge from AGENTS.md

## R1. Opt-out key: `agents_md`

**Decision**: An optional top-level boolean, `agents_md`. It defaults to `true` and must be exactly `true` or `false`, like `enabled`. With an invalid value, sync and remove warn once and leave `AGENTS.md` untouched: no create, no update, no removal.

**Rationale**: snake_case, named after the file it controls. An invalid value cannot follow the `max_items` precedent of "reported and treated as unconfigured": that default writes to a committed file the developer may have tried to protect with a typo such as `agents_md: no`. Leaving the file alone is the reversible choice.

**Alternatives considered**:
- `agent_context`: reads as the spec-kit `agent-context` extension, which also edits `AGENTS.md`.
- A per-source key: the section is project-wide, so a per-source key has nothing to control.

## R2. No `schema_version` bump

**Decision**: Stay on `"1.1"`.

**Rationale**: the key is optional, and every valid 1.1 file remains valid. The 005 contract added `max_items` and `max_bytes` the same way. Constitution §I asks for a bump only on breaking schema changes.

## R3. Markers

**Decision**: `<!-- KNOWLEDGE START -->` and `<!-- KNOWLEDGE END -->`, each matched as a whole line. A section is well-formed when the file has exactly one of each, start before end. No markers means absent. Any other combination is damaged.

**Rationale**: this mirrors the `agent-context` extension's `<!-- SPECKIT START -->`/`<!-- SPECKIT END -->`, which already sits in many consumer `AGENTS.md` files. Two tools with distinct markers never touch each other's block. Whole-line matching means a label can never close the section, because every label line starts with `- `.

## R4. One procedure, defined in sync

**Decision**: `§ Agent Context Section` lives in `speckit.knowledge.sync.md` § Algorithm Reference. `remove` applies it by reference, as it already does with § Source Slug Generation.

**Rationale**: two copies of an edit-in-place procedure would drift, and rule 11 guards only the validation block. A reference keeps one source of truth without a shared file, which §I rules out.

## R5. Placement, replacement and removal

**Decision**:
- **Write, absent:** append to the end. Ensure the file ends with a newline, add one empty line, then the section. A missing or whitespace-only file is written with the section and a final newline only.
- **Write, present:** replace the lines from the start marker through the end marker in place. Compare first, and do not write when the bytes are equal.
- **Remove:** delete the start-to-end lines plus one empty line directly above them, if there is one. When nothing but whitespace remains, delete the file.

**Rationale**: these rules satisfy FR-006 and FR-007. Removing the empty line that write added keeps write followed by remove byte-neutral, except for a final newline added to a file that lacked one. A reference run of these rules found that exception and the whitespace-only case during implement. Deleting a file left empty undoes the create, instead of leaving an empty committed `AGENTS.md`.

**Alternatives considered**: inserting near the top was rejected. Order in `AGENTS.md` is the team's choice, and appending touches nothing they wrote.

## R6. When no index exists, sync leaves the section alone

**Decision**: sync removes the section only when it deletes the index (step 1a) or when `agents_md: false`. When a sync ends with no index and no prior index, as on a first sync with every source unreachable, sync does not touch `AGENTS.md`.

**Rationale**: `AGENTS.md` is committed, while the index is git-ignored. A teammate's fresh clone carries the section but no index. Removing it there would create a working-tree diff in a shared file on every offline first sync. FR-002 already covers that case: the section tells the agent to suggest a sync when the index is missing. This narrows the spec's Key Entity wording, "exists exactly when the index exists", to what sync itself produces. FR-009 is satisfied as written.

## R7. Labels in the section

**Decision**: list the labels of the enabled sources that pass validation, in configuration order, one per line as `- ` followed by a code span. Escape each label under "Values in messages (007 FR-005)". When a label contains a backtick, wrap it in a code span whose backtick run is longer than any run inside the label.

**Rationale**: these are the sources the index can describe. Configuration order is deterministic, so the same configuration produces the same bytes (FR-007, SC-002). The escaping rule already governs every label shown to a developer. Code spans keep markdown in a label inert (FR-013).

## R8. Section wording

**Decision**: restate items 1–4 of sync step 10's "SHARED KNOWLEDGE CONTEXT" block in persistent form, scoped to questions about other repositories, with two additions:
- use only the listed sources;
- suggest a sync when the index or a source's entries are missing.

Use the project-relative index path. Name the sync command by its canonical id, `speckit.knowledge.sync`, not the `__SPECKIT_COMMAND_KNOWLEDGE_SYNC__` token. The token renders per host at install, so teammates on different hosts would commit different bytes. Validator check 5 flags only `/speckit` and `$speckit` invocations.

**Rationale**: one voice across the printed block and the persistent one. A relative path holds on every machine (FR-008). The exact text is in [contracts/agents-md-section.md](./contracts/agents-md-section.md).

## R9. `--no-context-output` does not affect the section

**Decision**: the flag keeps controlling only the printed step-10 block. `agents_md` alone governs `AGENTS.md`.

**Rationale**: one switch per surface. Callers that pass the flag want a quiet run, not a change to a committed file.

## R10. Configure keeps every other top-level key

**Decision**: configure step 4 states that every top-level key other than `schema_version` and `sources` is preserved as it is on edits.

**Rationale**: the step lists only `schema_version` and the sources today. An agent that rebuilds the file from that list would drop `agents_md: false`, and also `max_items`, `max_bytes` and `max_cache_age`, which already have this exposure.

## R11. Verification

**Decision**: a [quickstart.md](./quickstart.md) walkthrough covering create, idempotent re-run, label change, disable, remove of the last source, opt-out, damaged markers and a hostile label. `validate-extension.sh` covers rule 11 and the command tokens. No new harness.

**Rationale**: the edit is performed by the agent's file-writing tool from prose. `test-sync-git.sh` extracts only bash blocks, and the constitution names the quickstart walkthrough as the behavior check for prose.
