# Feature Specification: Auto-Integration with /speckit-specify and /speckit-plan

**Feature Branch**: `003-auto-integration`

**Created**: 2026-06-17

**Status**: Draft

**Input**: User description: "Auto-Integration with /speckit-specify and /speckit-plan (Layers 1 + 2): eliminate the manual setup steps currently documented in README.md § 'Integration with /speckit-specify and /speckit-plan' so that, after a user installs the Shared Knowledge extension, the cross-repo context is injected automatically into spec and plan generation without further configuration."

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Zero-Config Knowledge Injection in /speckit-specify (Priority: P1)

A developer installs the `knowledge` extension into their spec-kit project (`specify extension add knowledge --dev <path>` or via the catalog), runs `/speckit-knowledge-configure` to register at least one source, runs `/speckit-knowledge-sync`, and then runs `/speckit-specify "..."`. The cross-repo knowledge they configured shows up in the resulting `spec.md` — cited by source label and relative path — without the developer having edited `.specify/extensions.yml` or any SKILL.md file.

**Why this priority**: This is the headline outcome of the feature. Without it, the extension is functionally identical to today's manually-wired setup. Every other story in this spec exists to support this single user-facing behavior.

**Independent Test**: From a clean spec-kit project, install the extension via `specify extension add knowledge --dev <path>`, configure one local-path knowledge source pointing at a fixture repo with a known `.md` file (e.g., `payment-completed.md`), run `/speckit-knowledge-sync`, then run `/speckit-specify "Add a checkout flow"`. Verify the produced `spec.md` contains at least one citation in the form `<source-label> › <relative-path>` referencing the fixture's known file.

**Acceptance Scenarios**:

1. **Given** a project with the extension freshly installed and a single configured & reachable knowledge source, **When** the developer runs `/speckit-specify "<feature description>"`, **Then** the `before_specify` hook fires `speckit.knowledge.sync` automatically without any prior hand-edit of `.specify/extensions.yml`
2. **Given** the sync completes successfully, **When** the AI agent generates the spec, **Then** the resulting `spec.md` includes at least one citation in the form `<source-label> › <relative-path>` for any knowledge file it referenced
3. **Given** an item in the index carries a `⚠️ CONFLICT` annotation, **When** the agent references that item in the generated spec, **Then** both source versions are surfaced and the conflict is flagged to the user
4. **Given** the same project, **When** the developer subsequently runs `/speckit-plan`, **Then** the `before_plan` hook also fires `speckit.knowledge.sync` automatically and the resulting `plan.md` cites cross-repo knowledge by `<source-label> › <relative-path>`

---

### User Story 2 — Sync Emits a Context Output Block for the AI Agent (Priority: P1)

When the developer (or the auto-triggered hook) invokes `/speckit-knowledge-sync`, the command's stdout ends with a clearly delimited "Context Output for AI Agents" block that instructs the consuming AI agent — in plain English, second person — to read `knowledge-index.md`, open every referenced cache file, and cite each piece of borrowed information by `<source-label> › <relative-path>`.

**Why this priority**: This block is the entire mechanism by which Layer 2 replaces the deleted SKILL.md preamble step. The hook ran — but without this output landing in the agent's context window, the agent would not know to read the knowledge corpus. P1 because Story 1's outcome is impossible without it.

**Independent Test**: Run `/speckit-knowledge-sync` directly (without going through `/speckit-specify`) in a project with a configured source. Verify the last lines of stdout are a clearly delimited block (visible rule above and below) that names `.specify/extensions/knowledge/knowledge-index.md` and contains directives addressed to the AI agent.

**Acceptance Scenarios**:

1. **Given** `knowledge.yml` exists with at least one source and sync completes (fresh or cached), **When** the command finishes, **Then** the last section of stdout — appearing after the existing summary line — is a "Context Output for AI Agents" block delimited by visible markers (e.g., `══` rules above and below)
2. **Given** the Context Output block is emitted, **When** an AI agent reads it, **Then** the block instructs the agent — in second person, plain English — to (a) read `.specify/extensions/knowledge/knowledge-index.md` before drafting the current spec or plan, (b) open every `.md` file referenced by that index from `.specify/extensions/knowledge/cache/<slug>/...`, (c) cite each piece of referenced information by `<source-label> › <relative-path>`, and (d) surface both versions and flag the conflict to the user when an item has a `⚠️ CONFLICT` annotation
3. **Given** all sources are unreachable but a previous cache exists (degraded mode, `cached` status), **When** sync completes, **Then** the Context Output block is still emitted, still references the existing `knowledge-index.md`, and the per-source status table reports `⚠️ cached` as it does today
4. **Given** `knowledge.yml` does not exist (extension not configured), **When** sync runs, **Then** the existing "not configured" message is printed, the command exits 0, and no Context Output block is emitted (no orphan block referencing a missing index)

---

### User Story 3 — README No Longer Documents Manual Hook Registration (Priority: P2)

A developer reading the project's `README.md` to learn how to integrate the extension finds that the "Integration with /speckit-specify and /speckit-plan" section no longer instructs them to hand-edit `.specify/extensions.yml`. Instead, a short paragraph explains that hooks declared in `extension.yml` are auto-registered by spec-kit when the extension is installed.

**Why this priority**: P2 because incorrect documentation actively misleads new adopters into making manual edits that are now redundant (and that may collide with auto-registration). Critical for adoption correctness, but not part of the runtime behavior.

**Independent Test**: After this feature ships, read `README.md` § "Integration with /speckit-specify and /speckit-plan" end-to-end. Confirm there are no instructions to edit `.specify/extensions.yml` and no SKILL.md preamble snippets to copy.

**Acceptance Scenarios**:

1. **Given** the post-feature `README.md`, **When** a reader scans the "Integration" section, **Then** they find a single short paragraph stating that the `before_specify` and `before_plan` hooks are auto-registered on install and pointing at the spec-kit Extension Development Guide for the underlying mechanism
2. **Given** the post-feature `README.md`, **When** a reader searches the file for the string `.specify/extensions.yml`, **Then** the only matches outside the Integration section are removed too if they referred to manual hook registration (the file may still mention it for unrelated context, but never as a required manual setup step)
3. **Given** the post-feature `README.md`, **When** a reader searches the file for SKILL.md preamble snippets (the literal "Cross-repo knowledge check" block previously printed), **Then** zero matches are found — that block is replaced by a reference to the Context Output block emitted by sync
4. **Given** a previous adopter who already hand-edited `.specify/extensions.yml` per the old README, **When** they upgrade to this feature, **Then** the README contains a short migration note telling them they may safely remove the hand-added `knowledge` entries (auto-registration handles them now)

---

### User Story 4 — Diagnostic Opt-Out for Manual Sync (Priority: P3)

A developer running `/speckit-knowledge-sync` manually for diagnostic purposes (e.g., debugging which sources are reachable) wants to suppress the Context Output block so the terminal shows only the per-source status table and the summary line.

**Why this priority**: P3 because the auto-triggered hook path is the dominant case (always emits the block) and developers rarely need the suppression. Still meaningful for log readability and parsing.

**Independent Test**: Run `/speckit-knowledge-sync --no-context-output` in a project with a configured source. Verify the per-source status table and summary line appear as before but the Context Output block is absent. Then run without the flag and verify the block is present.

**Acceptance Scenarios**:

1. **Given** a configured project, **When** the developer invokes `/speckit-knowledge-sync --no-context-output`, **Then** the per-source status table and summary line are printed exactly as today and the Context Output block is suppressed
2. **Given** the auto-triggered hook path (`before_specify`, `before_plan`), **When** sync is invoked by the hook, **Then** the `--no-context-output` flag is NOT passed and the Context Output block is always emitted (the hook path cannot accidentally suppress it)
3. **Given** any combination of `--verbose` with or without `--no-context-output`, **When** sync runs, **Then** the two flags interact independently (verbose still lists files per source; no-context-output still suppresses only the final block)

---

### Edge Cases

- **Spec-kit auto-registration claim is wrong or version-gated**: If a particular spec-kit release does not auto-register hooks declared in `extension.yml`, the user sees `/speckit-specify` run with no sync triggering and no knowledge in the spec. We document the required spec-kit version (`>= 0.10.0`, already declared in `extension.yml#requires.speckit_version`) and rely on `specify extension add` to surface a version-mismatch error if applicable.
- **Adopter previously hand-edited `.specify/extensions.yml`**: They may end up with duplicate `knowledge` hook entries (one auto-registered, one manual). Today's spec-kit hook executor de-duplicates by `(extension, command, hook-point)` — duplicates are harmless but cosmetically ugly. The README migration note tells them to delete the manual entries.
- **Sync block reaches a non-conforming agent**: If the consuming AI agent doesn't honor instructions emitted via stdout, the block is informational only. We accept this — Copilot, Claude Code, and other compliant agents do honor it; non-compliant agents fall back to today's "no knowledge in spec" behavior, which is no worse than before.
- **Conflict annotation across many sources**: If `⚠️ CONFLICT` lists 3+ sources for the same path, the Context Output block's directive ("surface both versions") naturally extends to "surface all versions" — the directive uses "both/all" or equivalent wording.
- **Empty knowledge index**: If sources are configured but every source returns zero `.md` files (or every source is `unreachable` with no prior cache), `knowledge-index.md` exists but contains no items. The Context Output block is still emitted; the agent reads an empty index and proceeds without citations. Sync still exits 0.
- **`--no-context-output` passed alongside auto-trigger**: Not possible by design — the hook entries in `extension.yml` declare no arguments to the sync command. If a future change adds arguments, that change must explicitly avoid passing `--no-context-output`.

---

## Requirements *(mandatory)*

### Functional Requirements

**README cleanup (Layer 1):**

- **FR-001**: `README.md` § "Integration with /speckit-specify and /speckit-plan" MUST be rewritten to remove the entire "Step 1: Register the sync hooks in `.specify/extensions.yml`" subsection
- **FR-002**: The same section MUST also remove the "Step 2: Amend your SKILL.md files" subsection — that mechanism is replaced by the Context Output block emitted by sync (Layer 2)
- **FR-003**: The replacement section MUST contain a short paragraph (≤ 4 sentences) stating that hooks declared under the top-level `hooks:` key in `extension.yml` are auto-registered by spec-kit when the extension is installed via `specify extension add`, and pointing to the official spec-kit Extension Development Guide for the underlying mechanism
- **FR-004**: The replacement section MUST contain a short migration note for existing adopters: "If you previously followed the prior README and added `knowledge` entries to your project's `.specify/extensions.yml`, you may safely remove them — auto-registration handles them now."
- **FR-005**: After the rewrite, `README.md` MUST NOT contain any instruction directing the user to hand-edit `.specify/extensions.yml` for the purpose of registering this extension's hooks

**Sync command Context Output block (Layer 2):**

- **FR-006**: `commands/speckit.knowledge.sync.md` MUST be amended so that, after the existing per-source status table and summary line, the command emits a "Context Output for AI Agents" block as the final section of its stdout
- **FR-007**: The Context Output block MUST be wrapped above and below by a horizontal rule of exactly 70 box-drawing double-bar characters (U+2550, `═`) on its own line, with the banner line `📚 SHARED KNOWLEDGE CONTEXT (for the AI agent)` immediately under the top rule, so the consuming AI agent can locate it deterministically. (The plan and quickstart lock this contract verbatim.)
- **FR-008**: The Context Output block MUST instruct the AI agent, in second-person plain English, to read `.specify/extensions/knowledge/knowledge-index.md` before drafting the current spec or plan
- **FR-009**: The Context Output block MUST instruct the AI agent to open every `.md` file referenced by `knowledge-index.md` from `.specify/extensions/knowledge/cache/<slug>/...` before generating output
- **FR-010**: The Context Output block MUST instruct the AI agent to cite each piece of referenced information using the format `<source-label> › <relative-path>` (e.g., `payment-service › specs/events/payment-completed.md`)
- **FR-011**: The Context Output block MUST instruct the AI agent that, when an item carries a `⚠️ CONFLICT` annotation in the index, it must surface every version present and flag the conflict to the human user
- **FR-012**: The Context Output block MUST be emitted on every successful sync invocation (status `fresh` for any source) by default
- **FR-013**: The Context Output block MUST also be emitted in degraded mode (every source falls back to `cached`, OR the mix is partly `cached` partly `unreachable`) so long as at least one source has a usable cached index
- **FR-013a**: When all sources are unreachable AND no prior `knowledge-index.md` exists in the consumer project, sync MUST print the soft warning line `⚠️  No knowledge-index.md found yet. Run /speckit-knowledge-sync once when sources are reachable.`, MUST NOT emit the Context Output block, and MUST exit 0 (degraded-no-cache boundary path; see plan § "Degraded-mode behavior")
- **FR-014**: The Context Output block MUST be suppressed when and only when the developer invokes sync with the `--no-context-output` flag
- **FR-015**: The Context Output block MUST NOT be emitted when sync exits with a "not configured" message (no `knowledge.yml`), invalid YAML, missing `schema_version`, or missing `sources` key — these paths already return early today and must continue to do so
- **FR-016**: The auto-triggered hook invocations declared in `extension.yml` (under `hooks.before_specify` and `hooks.before_plan`) MUST NOT pass `--no-context-output` — auto-trigger always emits the block
- **FR-017**: All sync paths MUST continue to exit 0 (no crashes, no non-zero exits), preserving today's behavior

### Key Entities

- **Context Output block**: A trailing section of `speckit.knowledge.sync` stdout containing AI-agent directives. Delimited above and below by visible markers. Always references `.specify/extensions/knowledge/knowledge-index.md`. Suppressed only by `--no-context-output`.
- **Auto-registered hook**: A `before_specify` or `before_plan` entry that spec-kit injects into the consumer's `.specify/extensions.yml` automatically when the extension is installed, sourced from the top-level `hooks:` key in `extension.yml`. No new artifact — already declared in the existing `extension.yml`.
- **Migration note** (in README): A one-paragraph instruction telling adopters who followed the prior README to remove their hand-edited entries from `.specify/extensions.yml`.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A developer who installs the extension fresh (`specify extension add knowledge --dev <path>`), configures one reachable source, and runs `/speckit-specify "<feature>"` sees ≥ 1 citation in `<source-label> › <relative-path>` form in the resulting `spec.md` — without performing any manual edits to `.specify/extensions.yml` or any SKILL.md file
- **SC-002**: The post-feature `README.md` contains zero instructions to hand-edit `.specify/extensions.yml` for the purpose of registering this extension's hooks (verified by inspection of the Integration section and a workspace-wide search)
- **SC-003**: 100% of `/speckit-knowledge-sync` invocations that exit after a successful or degraded sync (i.e., `knowledge.yml` exists and at least one source produced or had a usable cache) and that were NOT passed `--no-context-output` end stdout with the Context Output block
- **SC-004**: 100% of `/speckit-knowledge-sync` invocations that exit early (no `knowledge.yml`, invalid YAML, missing `schema_version`, missing `sources`) emit zero Context Output blocks and still exit 0
- **SC-005**: Time from `specify extension add knowledge --dev <path>` to seeing knowledge cited in a generated `spec.md` is under 2 minutes for a single reachable source (configure → sync → specify)
- **SC-006**: For an existing adopter who follows the README migration note, removing the previously hand-edited `knowledge` entries from `.specify/extensions.yml` leaves `/speckit-specify` and `/speckit-plan` behavior unchanged (auto-registration covers them)

---

## Assumptions

- Spec-kit `>= 0.10.0` (already declared in `extension.yml#requires.speckit_version`) auto-registers hook objects declared under the top-level `hooks:` key in an extension's `extension.yml` when the extension is installed via `specify extension add` or `specify extension add --dev`. This is the mechanism documented in the official Spec Kit Extension Development Guide (https://github.com/github/spec-kit/blob/main/extensions/EXTENSION-DEVELOPMENT-GUIDE.md). If a specific spec-kit release breaks this contract, the extension surfaces a version-mismatch error at install time — that failure is out of scope for this feature.
- The current `extension.yml` already declares both `before_specify` and `before_plan` hooks pointing at `speckit.knowledge.sync` (verified at spec-time), so no changes to `extension.yml` are required for hook registration.
- Consuming AI agents (GitHub Copilot, Claude Code, Cursor, etc.) honor instructions emitted via the sync command's stdout when that output lands in their context window via the `before_specify` / `before_plan` hook execution. Non-compliant agents fall back to behavior identical to a project without the extension installed.
- `--no-context-output` is the only opt-out flag; no environment-variable or config-file toggle is introduced (YAGNI per constitution).
- The Context Output block is always emitted on stdout (never stderr) so that it lands in the agent's context regardless of how the runtime captures hook output.
- Hook auto-registration is idempotent — reinstalling the extension does not multiply hook entries. (Confirmed by spec-kit's documented behavior; not a contract we control.)
- The cross-cutting outcome (Story 1) requires Layer 1 + Layer 2 to ship together; partial delivery (e.g., README rewrite without the Context Output block) is explicitly NOT a viable MVP because the agent would have no instruction to read the index.

---

## Out of Scope

The following are explicitly NOT part of this feature and MUST NOT be touched by the implementation:

- Patching `.claude/skills/speckit-specify/SKILL.md` or `.claude/skills/speckit-plan/SKILL.md` directly. We do not modify core spec-kit files. Any future "integrate" command that auto-patches those files is a separate feature (Layer 3).
- Adding any new commands. The four existing commands (`configure`, `sync`, `search`, `status`) are unchanged in count.
- Changing hook registration mechanics in `extension.yml`. The `hooks.before_specify` and `hooks.before_plan` entries already exist and are correct.
- Modifying `scripts/install-local.sh`. Auto-registration is spec-kit's job, not the install script's.
- Modifying `config-template.yml` or its `schema_version`. No new config keys are introduced.
- Any change to `commands/speckit.knowledge.configure.md`, `commands/speckit.knowledge.search.md`, or `commands/speckit.knowledge.status.md`.

---

## Extension Impact *(mandatory for this feature — touches commands/ and README)*

### extension.yml Changes

| Field | Current Value | Proposed Value | Reason |
|-------|--------------|----------------|--------|
| `extension.version` | `1.0.0` | `1.1.0` | Minor bump — additive runtime behavior (Context Output block) and corrected docs; no breaking change to config schema or command IDs |
| `provides.commands` | unchanged | unchanged | No new or removed commands |
| `hooks.before_specify` | already declared | unchanged | Confirms Layer 1 needs no manifest edit |
| `hooks.before_plan` | already declared | unchanged | Confirms Layer 1 needs no manifest edit |

### config-template.yml Changes

None. `schema_version` is NOT bumped — no new config keys, no schema change.

**`schema_version` bump required?** [ ] Yes — breaking change   [x] No — no schema change

### New / Modified Commands

| Command file | Command ID | Trigger | What it does |
|-------------|-----------|---------|-------------|
| `commands/speckit.knowledge.sync.md` | `speckit.knowledge.sync` | `/speckit-knowledge-sync` | (modified) Append "Context Output for AI Agents" block as the final stdout section unless `--no-context-output` is passed; recognize the new flag in argument parsing |

No new command files are added. Three of the four existing command files (`configure`, `search`, `status`) are untouched.

### Install Script Impact

- [ ] Yes
- [x] No — `scripts/install-local.sh` is unchanged. Auto-registration of hooks is performed by spec-kit's `specify extension add` flow, not by this script.

### README.md Impact

`README.md` is rewritten in the "Integration with /speckit-specify and /speckit-plan" section:

- Step 1 ("Register the sync hooks in `.specify/extensions.yml`") is removed entirely.
- Step 2 ("Amend your SKILL.md files") is removed entirely.
- A single short paragraph replaces both, explaining that hooks declared in `extension.yml` are auto-registered by spec-kit on `specify extension add` and that the AI agent's reading-the-index behavior is now driven by the Context Output block emitted by sync (Layer 2).
- A short migration note tells previous adopters they may safely remove their hand-edited entries from `.specify/extensions.yml`.

### CHANGELOG.md Impact

A new `## [1.1.0] - <release date>` entry MUST be added under `[Unreleased]` (per constitution Quality Gates §4) describing:
- `feat(sync): emit Context Output for AI Agents block by default; add --no-context-output flag`
- `docs(readme): remove obsolete manual hook registration and SKILL.md preamble steps; add migration note`
