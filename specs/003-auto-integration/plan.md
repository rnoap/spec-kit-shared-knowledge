# Implementation Plan: Auto-Integration with /speckit-specify and /speckit-plan

**Branch**: `003-auto-integration` | **Date**: 2026-06-17 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from [specs/003-auto-integration/spec.md](spec.md)

## Summary

Two-layer change that turns cross-repo knowledge injection into a zero-config behavior for consumers of the `knowledge` extension:

- **Layer 1 (docs):** Rewrite [README.md](../../README.md) § "Integration with /speckit-specify and /speckit-plan" to remove the obsolete manual steps (hand-editing `.specify/extensions.yml`; copying SKILL.md preambles). Replace with a short paragraph explaining that hooks declared in `extension.yml` are auto-registered by spec-kit on `specify extension add`, plus a one-paragraph migration note for v1.0.0 adopters.
- **Layer 2 (runtime):** Append a "Context Output for AI Agents" block to the runtime stdout of [commands/speckit.knowledge.sync.md](../../commands/speckit.knowledge.sync.md). The block lands in the agent's context window via the already-declared `before_specify` / `before_plan` hooks and instructs the agent — in plain English, second person — to read `knowledge-index.md`, open every referenced cache file, cite each item as `<source-label> › <relative-path>`, and surface both versions when `⚠️ CONFLICT` is annotated. The block is suppressed only by an explicit `--no-context-output` flag (manual diagnostic use only).

**Technical approach:** Markdown-only edits. No new commands, no new scripts, no schema changes. The block is emitted on every successful or degraded sync path (status `fresh` for any source, or `cached` with at least one usable cache) and never on early-exit paths (no `knowledge.yml`, invalid YAML, missing `schema_version`, missing `sources`). Every existing exit-0 path stays exit 0.

## Technical Context

**Language/Version**: Markdown (CommonMark) for the command file and README; embedded Bash pseudocode used only to document the new flag's parse logic. No compiled code.

**Primary Dependencies**: spec-kit `>= 0.10.0` (already declared in `extension.yml#requires.speckit_version`); `git >= 2.25`; `python3` — all pre-existing requirements; nothing new.

**Storage**: No new storage. The Context Output block is read-time only — it references the existing `.specify/extensions/knowledge/knowledge-index.md` and `.specify/extensions/knowledge/cache/<slug>/...` produced by today's sync algorithm. No new files; no schema changes.

**Testing**: Manual smoke test in a real spec-kit consumer project — same approach as 001 and 002 specs. No automated test framework. Verification steps captured in [quickstart.md](quickstart.md).

**Target Platform**: Any POSIX environment with spec-kit `>= 0.10.0` and git `>= 2.25` (unchanged from 1.0.0).

**Project Type**: spec-kit extension package — agent-prompt files are the deliverable. (No `src/`, no `tests/`, no compiled artifacts.)

**Performance Goals**: No measurable change. The Context Output block adds < 30 lines of plain text to sync's stdout. Sync's per-source 10s timeout and overall < 30s budget for a single remote source remain unchanged.

**Constraints**:
- Zero new failure paths. Every existing exit-0 path stays exit 0 (FR-017).
- Block emitted on every successful or degraded sync; never emitted on the four early-exit paths (no config, invalid YAML, missing `schema_version`, missing `sources`).
- Block always lands on stdout (never stderr) so it is captured by the spec-kit hook runtime.
- `--no-context-output` is the sole opt-out — no env-var or config-file toggle (YAGNI per Constitution §III; spec § Assumptions bullet 4).
- Auto-trigger paths (`before_specify`, `before_plan`) MUST NOT pass `--no-context-output`; the entries in `extension.yml#hooks.*` declare no arguments to the sync command.

**Scale/Scope**: 2 files modified — [commands/speckit.knowledge.sync.md](../../commands/speckit.knowledge.sync.md) and [README.md](../../README.md). 1 manifest field updated: `extension.yml#extension.version` (`1.0.0` → `1.1.0`). 1 new entry in [CHANGELOG.md](../../CHANGELOG.md).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

| Principle / Gate | Pre-Design | Post-Design | Notes |
|------------------|:----------:|:-----------:|-------|
| **I. Extension-Package Discipline** — `extension.yml` is the single source of truth for id/version/commands/hooks | ✅ | ✅ | Bumps `extension.version` only. No new commands, no new hooks, no `schema_version` change. |
| **I. Extension-Package Discipline** — `config-template.yml` `schema_version` policy | ✅ | ✅ | Schema unchanged; no new config keys. |
| **I. Extension-Package Discipline** — Commands are self-contained Markdown agent prompts | ✅ | ✅ | Edits to `commands/speckit.knowledge.sync.md` add output and a flag; no hidden runtime dependencies introduced. |
| **I. Extension-Package Discipline** — Install logic only in `scripts/install-local.sh` | ✅ | ✅ | Out of scope per spec; install script untouched. |
| **II. Source-of-Truth Hierarchy** — README mirrors `extension.yml` and the command files | ✅ | ✅ | README is rewritten to match the new auto-registration reality and the new sync output. Authority order respected: `extension.yml` (1) → `commands/*.md` (3) → `README.md` (5). |
| **III. Simplicity (YAGNI)** — Markdown-only when expressible as Markdown | ✅ | ✅ | Both layers are Markdown edits. No Bash script, no env-var toggle, no config-file toggle. |
| **III. Simplicity (YAGNI)** — No CI / no test framework requirement | ✅ | ✅ | Verification is manual (see [quickstart.md](quickstart.md)). |
| **IV. Conventional Commits (NON-NEGOTIABLE)** | ✅ | ✅ | Commits will follow `feat(sync): …`, `docs(readme): …`, `chore(release): bump version to 1.1.0` patterns; CHANGELOG entry under `[Unreleased]` then promoted to `## [1.1.0]`. |
| **Quality Gates §1** — install script runs cleanly in a fresh project | ✅ | ✅ | Install script not modified. |
| **Quality Gates §2** — all four commands registered post-install | ✅ | ✅ | Command count unchanged (still four). |
| **Quality Gates §3** — `extension.yml` `version` matches release tag | ⚙️ pending bump | ✅ | Bumped to `1.1.0` as part of implementation tasks. |
| **Quality Gates §4** — `CHANGELOG.md` has an entry for the new version | ⚙️ pending entry | ✅ | Added under `[Unreleased]` then promoted to `## [1.1.0]`. |
| **Quality Gates §5** — README command table matches `extension.yml` `provides.commands` | ✅ | ✅ | No commands added or removed; existing table stays accurate. |
| **Extension-wide invariant** — exit-0 contract for every command path | ✅ | ✅ | This feature only ADDS output to existing successful/degraded paths; no new failure surface introduced. |

**Gate result**: All gates pass with no violations. Complexity Tracking section is therefore empty.

## Project Structure

### Documentation (this feature)

```text
specs/003-auto-integration/
├── spec.md           # Feature specification (already authored)
├── plan.md           # This file
├── research.md       # Phase 0 output — resolves the three open questions
├── data-model.md     # Phase 1 output — Context Output Block logical schema
├── quickstart.md     # Phase 1 output — manual verification walkthrough
├── checklists/
│   └── requirements.md
└── tasks.md          # Phase 2 output — generated by /speckit-tasks (NOT this command)
```

`contracts/` is intentionally omitted — this feature exposes no external interfaces. The Context Output block is internal CLI output read by AI agents; its logical schema is documented in [data-model.md](data-model.md).

### Source Code (repository root — files modified by this feature)

```text
commands/
└── speckit.knowledge.sync.md     # MODIFIED — add `--no-context-output` flag and append "Context Output for AI Agents" block

README.md                          # MODIFIED — rewrite "Integration with /speckit-specify and /speckit-plan" section

extension.yml                      # MODIFIED — bump `extension.version` 1.0.0 → 1.1.0 (no other field changes)

CHANGELOG.md                       # MODIFIED — add 1.1.0 entry under [Unreleased]
```

**Files NOT modified (out of scope per spec):**
- `commands/speckit.knowledge.configure.md`, `commands/speckit.knowledge.search.md`, `commands/speckit.knowledge.status.md`
- `scripts/install-local.sh`
- `config-template.yml` (no `schema_version` change)
- `.claude/skills/speckit-specify/SKILL.md`, `.claude/skills/speckit-plan/SKILL.md` (Layer 3, future feature)
- `extension.yml#hooks.*` — `before_specify` and `before_plan` are already correctly declared at v1.0.0 and need no edit

**Structure Decision**: Inherits the same "no `src/`, no compiled code, files-are-the-deliverable" structure as 001 and 002. The two modified files in `commands/` and root are the only behavior-bearing artifacts; the manifest version bump and CHANGELOG entry are the release-hygiene artifacts.

## Contract: Context Output Block (the format IS the contract)

This feature exposes no public API. The agent-facing contract is the literal stdout block emitted by [commands/speckit.knowledge.sync.md](../../commands/speckit.knowledge.sync.md) at the tail of every successful or degraded sync (FR-006…FR-013). No `contracts/` directory is generated; the canonical wire-format is defined here and its logical schema in [data-model.md](data-model.md).

### Emission ordering (locked)

`speckit.knowledge.sync` stdout, when emitted, ends in this exact order:

1. Per-source status lines (existing behavior, unchanged)
2. Summary line `✅ Knowledge index updated: N items from M sources.` (existing behavior, unchanged)
3. Pointer line `   → .specify/extensions/knowledge/knowledge-index.md` (existing behavior, unchanged)
4. **One blank line**
5. **The Context Output block (NEW — defined below)**

The block is the LAST thing on stdout. Nothing follows it.

### Literal block format

```text
══════════════════════════════════════════════════════════════════════
📚 SHARED KNOWLEDGE CONTEXT (for the AI agent)

You are about to draft a spec or plan in this project. Before you do:

1. Read `.specify/extensions/knowledge/knowledge-index.md` in full.
2. Open every `.md` file referenced by that index from
   `.specify/extensions/knowledge/cache/<slug>/...`.
3. When you cite borrowed information, use the format
   `<source-label> › <relative-path>` (example:
   `payment-service › specs/events/payment-completed.md`).
4. When the index annotates an item with `⚠️ CONFLICT`, surface every
   version present and flag the conflict to the human user.
══════════════════════════════════════════════════════════════════════
```

### Conformance rules

| Rule | Source FR | Notes |
|------|-----------|-------|
| Top rule and bottom rule are identical: 70 × U+2550 (`══`) on their own line, no trailing whitespace | FR-007 | Visually distinct from data lines (✅ 🔄 ❌); locatable by both humans and agents |
| Banner line `📚 SHARED KNOWLEDGE CONTEXT (for the AI agent)` immediately follows the top rule | FR-007 | Emoji prefix matches existing UI style in [commands/speckit.knowledge.sync.md](../../commands/speckit.knowledge.sync.md) |
| All directives are second-person plain English | FR-008…FR-011, data-model I2 | "You / your"; addresses the AI agent, not the terminal user |
| Citation token is literally `<source-label> › <relative-path>` with U+203A `›` separator | FR-010, data-model I4 | Matches `speckit.knowledge.search` output convention |
| Exit code stays 0 on every emission path | FR-017, Constitution invariant | Block is informational; never gates exit status |

### Suppression semantics — `--no-context-output`

- Parsed by the same `$ARGUMENTS` token-scan pattern as the existing `--verbose` flag (research § R3).
- Present → skip steps 4 + 5 above; everything else (status lines, summary, pointer) prints identically. Exit 0.
- Absent → emit block.
- Auto-trigger paths (`before_specify`, `before_plan`) declare no arguments in [extension.yml](../../extension.yml) → flag is structurally unreachable from the hook → block always emits via auto-trigger (FR-016).
- Composes orthogonally with `--verbose` (per spec § US-4 acceptance scenario 3).

### Suppression semantics — early-exit paths (FR-015)

The block is **never** emitted from any path that prints an early-exit error message. Specifically:

| Early-exit condition | Existing message | Block emitted? |
|----------------------|------------------|:--------------:|
| `knowledge.yml` absent | `❌ Error: knowledge.yml not found. Run /speckit-knowledge-configure to initialize.` | ❌ no |
| Invalid YAML | `❌ Error: knowledge.yml contains invalid YAML: <parse error>` | ❌ no |
| Unknown `schema_version` | `❌ Error: Unrecognized schema_version. Expected "1.0".` | ❌ no |
| `sources` key missing | `❌ Error: knowledge.yml is missing the required "sources" key.` | ❌ no |

Rationale: there is no `knowledge-index.md` to point at on these paths, so the block would reference a missing file. Silence is contractually correct.

### Degraded-mode behavior (FR-013)

| Scenario | Block emitted? | Rationale |
|----------|:--------------:|-----------|
| ≥ 1 source returned status `fresh` | ✅ yes | Standard happy path |
| All sources `cached`, ≥ 1 has a usable cache | ✅ yes | `knowledge-index.md` is still valid context |
| Mix of `cached` + `unreachable`, ≥ 1 source has a usable cache | ✅ yes | Same reasoning |
| All sources `unreachable` AND no prior `knowledge-index.md` exists | ❌ no + soft warning | Print `⚠️  No knowledge-index.md found yet. Run /speckit-knowledge-sync once when sources are reachable.` then exit 0 |

## Phase 0 — Outline & Research

**Status**: ✅ Complete. Output: [research.md](research.md).

Three open questions surfaced by the planner were resolved before locking the Phase 1 design:

| ID | Question | Decision |
|----|----------|----------|
| R1 | spec-kit auto-registers our hooks on `specify extension add`? | Yes — relies on documented Extension Development Guide contract; `requires.speckit_version >= 0.10.0` already declared |
| R2 | Hook stdout reaches the parent agent's context window? | Yes — emit on stdout (never stderr); compliant agents (Copilot, Claude Code, Cursor) treat captured hook output as prompt context |
| R3 | `--no-context-output` flag fits existing parse pattern? | Yes — same `$ARGUMENTS` scan as `--verbose`; orthogonal interaction; auto-trigger never passes it |

No NEEDS CLARIFICATION items remain.

## Phase 1 — Design & Contracts

**Status**: ✅ Complete. Outputs:

| Artifact | Path | Status | Notes |
|----------|------|:------:|-------|
| Data model | [data-model.md](data-model.md) | ✅ generated | Models the Context Output Block as a transient logical entity (no on-disk persistence). I1–I7 invariants captured. |
| Contracts directory | `contracts/` | ⏭️ explicitly skipped | This feature exposes no public API or external interface. The agent-facing contract is the literal stdout block; format is locked in the **Contract: Context Output Block** section above (per user direction: "the format IS the contract"). |
| Quickstart | [quickstart.md](quickstart.md) | ✅ generated | Six-step manual validation walkthrough (install → configure → sync → specify → flag → degraded mode). |
| Agent context | `AGENTS.md` (this repo's spec-kit start/end markers) | ✅ updated | The plan reference between `<!-- SPECKIT START -->` and `<!-- SPECKIT END -->` now points to this plan file. |

## Complexity Tracking

> *Empty — no Constitution Check violations to justify.*

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| *(none)*  | *(n/a)*    | *(n/a)*                             |
