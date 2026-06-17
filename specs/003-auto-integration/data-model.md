# Phase 1 Data Model: Auto-Integration with /speckit-specify and /speckit-plan

**Date**: 2026-06-17 | **Branch**: `003-auto-integration` | **Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

---

## Scope

This feature has no persistent data model — it neither defines new files on disk nor changes the on-disk schema of any existing file. The only "data" introduced is a transient stdout emission: the **Context Output Block** appended to `speckit.knowledge.sync` runtime output.

This document captures the logical schema of that emission so future tooling (e.g., a parser that ingests sync output into a richer context channel) has a stable contract to depend on.

---

## Entity: Context Output Block

A delimited section of `speckit.knowledge.sync` stdout that instructs the consuming AI agent to read `knowledge-index.md` and the `.md` files it references.

### Lifecycle

| Phase | Trigger | State |
|-------|---------|-------|
| **Not emitted** | `knowledge.yml` absent / invalid YAML / missing `schema_version` / missing `sources` (early-exit paths) | Block is skipped entirely |
| **Not emitted** | `--no-context-output` flag present in `$ARGUMENTS` (manual diagnostic invocation only) | Block is suppressed |
| **Emitted (fresh)** | At least one source returned status `fresh` | Full block appears as the last section of stdout |
| **Emitted (degraded)** | All sources `cached`, or mix of `cached` / `unreachable`, but at least one source has a usable cached index | Same block content; cached sources still contribute citations through `knowledge-index.md` |

The block is always emitted on **stdout** (not stderr) and as the **final** section of output, after the per-source status table and the existing summary line ("✅ Knowledge index updated: …").

### Logical Field Schema

| Field | Type | Required | Description | Example |
|-------|------|:--------:|-------------|---------|
| `delimiter_top` | Visible horizontal rule | ✅ | Marks the start of the block; agents and humans use it to locate emission boundaries (Invariant I1) | `══════════════════════════════════════════════════════════` |
| `header` | Markdown heading | ✅ | Names the block; second-person addressee is implicit | `## Context Output for AI Agents` |
| `directive_index` | Plain-English sentence | ✅ | Tells the agent to read the index file before drafting the parent artifact (FR-008) | "Read `.specify/extensions/knowledge/knowledge-index.md` before drafting the current spec or plan." |
| `directive_open_files` | Plain-English sentence | ✅ | Tells the agent to open every referenced cache file (FR-009) | "Open every `.md` file referenced by that index from `.specify/extensions/knowledge/cache/<slug>/...`." |
| `directive_citation_format` | Plain-English sentence with format token | ✅ | Tells the agent how to cite each item (FR-010) | "Cite each piece of referenced information as `<source-label> › <relative-path>` (example: `payment-service › specs/events/payment-completed.md`)." |
| `directive_conflict` | Plain-English sentence | ✅ | Tells the agent how to handle `⚠️ CONFLICT` items (FR-011) | "When an item is annotated `⚠️ CONFLICT` in the index, surface every version present and flag the conflict to the human user." |
| `delimiter_bottom` | Visible horizontal rule | ✅ | Marks the end of the block | `══════════════════════════════════════════════════════════` |

**Total emission length**: < 30 lines of plain text (constraint per spec § Technical Context). The plain-English form is intentional — agents respond to natural-language directives more reliably than to machine-readable schemas at this layer.

### Invariants

- **I1 (delimiter symmetry)**: `delimiter_top` and `delimiter_bottom` use the same character sequence, on their own lines, with no trailing whitespace.
- **I2 (addressee)**: All four `directive_*` fields are in second person ("you / your") and address the AI agent, not the human terminal user.
- **I3 (paths)**: `directive_index` and `directive_open_files` reference the canonical paths `.specify/extensions/knowledge/knowledge-index.md` and `.specify/extensions/knowledge/cache/<slug>/...` exactly — these are the paths produced by the existing sync algorithm (per [commands/speckit.knowledge.sync.md](../../commands/speckit.knowledge.sync.md) § "Algorithm Reference"), and no other paths are valid.
- **I4 (citation format)**: `directive_citation_format` uses the literal token `<source-label> › <relative-path>` with a U+203A `›` separator, matching the convention in [commands/speckit.knowledge.search.md](../../commands/speckit.knowledge.search.md)'s output. No alternative separator is permitted.
- **I5 (no fabrication)**: The block contains directives only — no per-source data, no item counts, no file paths beyond the canonical ones above. All concrete data lives in `knowledge-index.md`, which is the agent's input.
- **I6 (idempotence)**: Repeated `speckit.knowledge.sync` invocations produce the same block (modulo any future evolution of the directive wording). The block is not a snapshot of a particular sync run.
- **I7 (exit-0 contract)**: Emission of the block does not affect exit status. Sync continues to exit 0 in all paths (fresh, degraded, early-exit), per FR-017 and the extension-wide constitution invariant.

### Relationship to Existing Entities

The block references — but does not own — two existing on-disk artifacts produced by today's sync algorithm:

- **`knowledge-index.md`** (defined in [commands/speckit.knowledge.sync.md](../../commands/speckit.knowledge.sync.md) § "Algorithm Reference") — the file the `directive_index` field points the agent at. Schema version 1.0; not changed by this feature.
- **Cache directory entries `cache/<slug>/<relative-path>`** (defined in the same Algorithm Reference) — the files the `directive_open_files` field tells the agent to open. Slug computation, manifest format, and integrity check are unchanged.

No new on-disk artifact is created. No existing artifact's schema is modified.

---

## Non-Entities (intentionally NOT in this model)

The following were considered and explicitly excluded:

- **Per-source emission metadata** (timestamps, item counts inside the block) — would duplicate the per-source status table that already precedes the block, and would require updating the directive whenever the index format evolves. Rejected per Invariant I5.
- **Machine-readable JSON sibling block** (e.g., `<!-- context-output-meta: ... -->`) — speculative (YAGNI per Constitution §III). The plain-English directive is sufficient for compliant agents; a structured sibling can be added in a future feature without breaking the current emission.
- **Schema-version field on the block itself** — would require coordination with `knowledge-index.md`'s `schema_version`, but the block has no on-disk persistence and is regenerated every run. Reuse the natural-language form as the contract.
