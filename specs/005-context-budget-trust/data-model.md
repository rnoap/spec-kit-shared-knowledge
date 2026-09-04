# Phase 1 — Data Model: Context Budget & Trust Model

**Feature**: [spec.md](spec.md) · **Plan**: [plan.md](plan.md) · **Research**: [research.md](research.md)

This feature adds no new persisted file. It adds two optional keys to an existing configuration
file and introduces four **derived** entities that exist only during a synchronization run.

---

## 1. Persisted entities

### 1.1 `knowledge-config.yml` — two new optional keys

Both are valid at the top level and inside each `sources[]` entry, matching the two positions
`max_cache_age` already occupies.

| Key | Type | Default | Rule |
|-----|------|---------|------|
| `max_items` | integer as string or scalar | absent (no limit) | `^[0-9]+$` and `>= 1` |
| `max_bytes` | duration-style size | absent (no limit) | `^[0-9]+(kb\|mb)$` |

```yaml
schema_version: "1.0"          # UNCHANGED — both keys are optional (FR-005)

max_items: 120                 # project-wide ceiling
max_bytes: 1mb                 # project-wide ceiling

sources:
  - url: https://github.com/org/payments
    label: payments-v2
    max_items: 40              # sub-ceiling — can only lower, never raise (FR-003)
    path_filter: specs/
```

**`0` is rejected, not honoured.** A ceiling of zero would silently strip the entire corpus —
the precise failure the reporting half of this feature exists to prevent. Rejecting it routes
the value through FR-020 (per source: skip, name the field) or FR-021 (project-wide: report and
ignore).

### 1.2 `.manifest.json` — unchanged, but its role changes

No new field. Its **meaning** is load-bearing in a way it was not before: the manifest is written
before the budget is applied, so it holds the **complete** item list for its source while the
index holds only the injected subset.

That difference is what makes three requirements satisfiable at once:

- FR-012a — the cache is not bounded by the budget.
- FR-017 / FR-035 — search reads manifests, so withheld items stay findable.
- FR-034 — the verbose withheld list is `manifest.items − indexed items`, with no third record.

### 1.3 `knowledge-index.md` — a header line gains withholding fields

The existing machine-readable comment is extended. Fields are **omitted entirely** when nothing
was withheld, so a non-binding budget produces a byte-identical index (FR-016, SC-011).

```markdown
<!-- knowledge-index-meta: schema_version=1.0 generated_at=<ISO8601> sources=<N> items=<N>
     withheld_items=<N> withheld_bytes=<N> limit_items=<N> limit_bytes=<N> -->
```

The index states counts and sizes and **never names a withheld path** (FR-014) — it is the one
document the agent is instructed to read in full, and naming excluded files there would invite
it to open exactly what the budget removed.

---

## 2. Derived entities (never written to disk)

### 2.1 Effective limit

The ceiling that actually applies to one source, per dimension.

```text
effective(source, dimension) = min(
    source.<dimension>   if set else ∞,
    share(source, dimension)
)
```

Where `share` comes from § 2.2. **This is a sub-ceiling, not an override** — unlike
`max_cache_age`, whose per-source value *replaces* the project value. A per-source budget can
only lower what a source contributes. A per-source value above the project ceiling is clamped and
the clamp reported (FR-003a); it never costs the source its place, because the value is
well-formed and has exactly one safe reading.

### 2.2 Allocation

Progressive fill, run independently per dimension. `B` = project ceiling, `S` = enabled sources
that have at least one item.

```text
1. share = floor(B / |S|)
2. Every source whose total need <= share is satisfied in full:
   subtract its need from B, drop it from S, restart at 1.
3. When a pass satisfies nobody, every source left in S gets `share`.
4. Distribute the remainder (B − share × |S|) one unit each,
   in ascending LABEL order.
```

Terminates in at most `|S|` passes. Labels are unique by construction (feature 004, FR-028), so
step 4's tiebreak is never ambiguous. With no project ceiling on a dimension, every source's share
on that dimension is ∞ and only its own value binds.

**Step 2 is the step that makes this a fair share rather than a flat division.** Releasing the
capacity a small source cannot use back to the others is what fills the ceiling: with 120 items
across four sources needing 312 / 55 / 88 / 12, a flat `⌊120/4⌋` would inject only 30 + 30 + 30 +
12 = 102 and strand 18. Progressive fill gives 36 + 36 + 36 + 12 = 120. An implementation that
stops after one pass satisfies neither FR-006 nor FR-007a, and the shortfall is invisible unless
the injected total is compared against the ceiling.

### 2.3 Selection

Within a source, items are taken in **ascending relative-path order** — the longest prefix that
fits within *both* effective limits.

Path order rather than smallest-first: smallest-first packs more items, but adding one large file
would silently change which unrelated small files survive, and no user could predict the corpus
from their own repository. Path order localises the effect of any change to files after it, which
is what makes FR-007b achievable.

### 2.4 Withholding report

```text
WithholdingReport
├── per_source[]        label, injected_count, injected_bytes,
│                       withheld_count, withheld_bytes, limit_applied
├── oversized[]         path, size            — item exceeds the ceiling alone (FR-009)
├── starved[]           label, reason         — contributed nothing (FR-008a, FR-033)
├── conflict_drops[]    path, labels[]        — pair withdrawn as a unit (FR-033)
└── withheld_paths[]    path, label           — VERBOSE ONLY (FR-034)
```

---

## 3. State and ordering

### 3.1 Position in the sync pipeline

```text
5.  Index .md files per source
6.  Write .manifest.json          ← COMPLETE item list; budget has not run
7.  Detect conflicts              ← conflict pairs must be known first (FR-033)
7a. APPLY CONTEXT BUDGET          ← NEW
8.  Write knowledge-index.md      ← injected subset only
8a. Prune orphaned caches
9.  Print summary                 ← withholding report
10. Emit Context Output block     ← partial-corpus line when anything was withheld
```

Step 7a sits after 7 because conflict pairs must be known before any of their members can be
selected, and before 8 because the index is what the budget bounds. It is after 6 by requirement:
placing it earlier would bound the cache, which FR-012a forbids.

### 3.2 Step 7a in detail

```text
1. Resolve effective limits per source (§ 2.1, § 2.2).
2. Select per source in path order (§ 2.3).
3. Conflict reconciliation: for each conflict pair, if not every version was
   selected, withdraw ALL versions. Do NOT reallocate the freed capacity.
4. Assemble the withholding report (§ 2.4).
```

Step 3 runs once and does not iterate. Reallocating recovered capacity would make the result
depend on the pass count, which FR-007b forbids — the slack is wasted deliberately.

### 3.3 Budget decision table

| Project ceiling | Per-source ceiling | Corpus vs. ceiling | Outcome |
|---|---|---|---|
| absent | absent | any | No budget. Index unchanged from today (FR-004). Advisory warning above 200 items / 2 mb (FR-032) |
| absent | set | under | Nothing withheld; index indistinguishable from unbudgeted (FR-016) |
| absent | set | over | Only that source is trimmed; others untouched |
| set | absent | under | Nothing withheld (FR-016, SC-011) |
| set | absent | over | Progressive fill across all sources (§ 2.2) |
| set | set (≤ project) | over | `min` of the two per source (§ 2.1) |
| set | set (> project) | any | Per-source clamped to project ceiling, clamp reported (FR-003a) |
| set | malformed | any | That source skipped, field named (FR-020) |
| malformed | any | any | Project value reported and ignored; per-source values still apply (FR-021) |

### 3.4 Interaction with existing contracts

| Existing behaviour | Interaction | Resolution |
|---|---|---|
| Cache freshness policy (004) | A `current` source is served from cache without fetching | The budget applies to its cached corpus exactly as to a fetched one (FR-011, SC-012) |
| Unreachable source served from stale cache (004) | Same | Same — the agent reads one index regardless of provenance |
| Conflict reporting (004, FR-026) | Pairs are atomic under the budget | FR-033: all versions or none; freed capacity not reused |
| Empty configuration (004, FR-031) | Index deleted, no context block | Budget never runs; there is no corpus to bound |
| Context Output block (003) | Emitted when any source has usable content | Unchanged. A budgeted corpus is usable — it gains one line saying it is partial (FR-015) |
| `search` reads the index (002) | Would break FR-017 | FR-035: search reads manifests instead |
| Orphan cache pruning (004, step 8a) | Unaffected | The budget touches no cache directory (FR-012a) |

---

## 4. Validation rules to add

Two rows, appended to the Configuration Validation Rules table:

| Field | Rule |
|-------|------|
| `max_items` (top level and per source) | Optional. Matches `^[0-9]+$` and is `>= 1`. |
| `max_bytes` (top level and per source) | Optional. Matches `^[0-9]+(kb\|mb)$` — `512kb`, `2mb`. |

> **That table is duplicated verbatim across three command files, and Constitution Quality Gate
> §11 asserts on every pull request that the copies are byte-identical.** Both rows must land in
> `speckit.knowledge.configure.md`, `speckit.knowledge.sync.md`, and
> `speckit.knowledge.status.md` in the same change, or CI fails.

Neither value is ever passed to `git`, so the leading-`-` ban that governs `url`, `revision`, and
`path_filter` does not apply — but both rules are anchored regex matches, so an option-shaped
value fails regardless.
