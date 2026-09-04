# Contract: Command Surface (v1.5.0)

**Feature**: [../spec.md](../spec.md) · **Plan**: [../plan.md](../plan.md)

The CLI surface consumers depend on. **No command is added or removed** — the count stays at five,
so Constitution Quality Gate §2 needs no amendment this release.

**Exit code is `0` on every path**, including every path introduced here (FR-022). Degraded
operation is a message, never a process error.

---

## 1. Commands

| Command | Change in this feature |
|---------|----------------------|
| `speckit.knowledge.configure` | Accepts and validates `max_items` / `max_bytes`; reports a clamp |
| `speckit.knowledge.sync` | Applies the budget; emits the withholding report and the advisory warning |
| `speckit.knowledge.search` | **Reads manifests instead of the index** (FR-035) |
| `speckit.knowledge.status` | Shows each source's contribution against the limit applied |
| `speckit.knowledge.remove` | Unchanged |

---

## 2. Flags

| Flag | Command | Change |
|------|---------|--------|
| `--verbose` | sync | Additionally lists every withheld path (FR-034) |
| `--verbose` | status, search, configure | Unchanged |
| `--force` | sync | Unchanged — bypasses cache freshness, **never** the budget |
| `--no-context-output` | sync | Unchanged |

**No flag raises or bypasses the budget** (FR-012). This is deliberate and load-bearing: the four
automatic synchronization points are exactly where a context overflow does the most damage, so an
escape hatch reachable from them would defeat the guarantee. Unlike `--force`, whose
hook-unreachability is structural (hook entries declare no arguments), the budget needs no such
protection — the flag simply does not exist.

> Adding a bypass flag later would silently reopen this. Constitution Quality Gate §10 asserts no
> hook declares arguments, which protects `--force` but would **not** protect a new budget flag
> invoked manually.

---

## 3. Output contracts

### 3.1 Sync — nothing withheld

No withholding lines and no withholding fields in the index header (FR-016, SC-011). Identical to
today apart from the generation timestamp every sync writes.

### 3.2 Sync — budget binds

**Worked from the § 2.2 algorithm.** `max_items: 120`, `max_bytes: 1mb`, four sources holding
312 / 55 / 88 / 12 items (467 total, ≈3.9 mb).

`full-topology.md` (2.4 mb) exceeds the whole size ceiling alone, so FR-009 removes it before
allocation — it neither consumes nor blocks the budget. Progressive fill on items then runs:
share `⌊120/4⌋ = 30`; shared-contracts needs only 12 so it is satisfied and releases 18;
`⌊108/3⌋ = 36` and no one else fits, so the remaining three take 36 each. **12 + 36 + 36 + 36 =
120**, the ceiling exactly. One conflict withdrawal then removes a further item.

```
🔄 Syncing cross-repo knowledge sources...

  payment-service    ✅ fresh    35 items  (synced 2026-09-04T14:00:00Z)
                     ✂️  budget: 35 of 312 items (115kb of 3.4mb) — limit 36 items (equal share of 120)
  adr-repo           ✅ fresh    36 items  (synced 2026-09-04T14:00:00Z)
                     ✂️  budget: 36 of 55 items (124kb of 190kb) — limit 36 items (equal share of 120)
  design-notes       ✅ fresh    36 items  (synced 2026-09-04T14:00:00Z)
                     ✂️  budget: 36 of 88 items (123kb of 300kb) — limit 36 items (equal share of 120)
  shared-contracts   ⏭️  current  12 items  (cached 12m ago; policy 4h — no network)
                     ✓  budget: 12 of 12 items (40kb) — within its 30-item share; 18 released

⚠️  Withheld: payment-service › specs/architecture/full-topology.md (2.4mb) exceeds the
    1mb size ceiling on its own; excluded without consuming the budget.
⚠️  Conflict withdrawn: specs/events/payment-completed.md — present in payment-service and
    adr-repo, whose repository identities differ; not every version fits, so none was
    included. The freed capacity is not reallocated.

✅ Knowledge index updated: 119 items from 4 sources (348 withheld, 3.5mb).
   → .specify/extensions/knowledge/knowledge-index.md
```

Every figure reconciles: 35 + 36 + 36 + 12 = 119 injected; 467 − 119 = 348 withheld;
115 + 124 + 123 + 40 = 402 kb injected against a ≈3.9 mb corpus, leaving ≈3.5 mb withheld.

**No source is starved here, and none may be**: FR-008a authorises a zero contribution only when
the item ceiling is below the *number of sources with items*, and 120 > 4. A source that indexes
nothing for its own reasons — empty, or a path filter matching nothing — must **not** be reported
as withheld by the budget at all.

Starvation looks like this instead, with `max_items: 2` across three sources holding items:

```
  adr-repo           ✅ fresh    1 item   (share of 2)
  design-notes       ✅ fresh    1 item   (share of 2)
  payment-service    ✅ fresh    0 items
                     ⚠️  contributed nothing — the item ceiling (2) is below the number of
                        sources with items (3), so some source must receive nothing. Chosen
                        by the same rule: the remainder went to the lowest labels in order.
```

Required elements: per-source injected-vs-total counts and sizes; the limit applied (FR-013,
FR-018); starved sources named (FR-008a); oversized items named with their size (FR-009); conflict
withdrawals named as one event (FR-033).

### 3.3 Sync — `--verbose`

Adds, beside the existing per-source file listing:

```
--- VERBOSE: items withheld from payment-service ---
specs/architecture/full-topology.md
specs/events/payment-completed.md
specs/events/refund-issued.md
[... 274 more]
--- END VERBOSE ---
```

277 withheld from payment-service (312 total − 35 injected), so three shown and 274 elided.

### 3.4 Sync — advisory warning, no budget configured

```
⚠️  This project's knowledge corpus is 340 items / 2.7mb, past the advisory
    threshold of 200 items / 2mb. An agent instructed to read all of it may
    exhaust its context. Consider setting `max_items` or `max_bytes` in
    knowledge-config.yml.
```

Names both the measured value and the threshold (FR-032a, SC-017). Informational only — it alters
nothing (SC-015), exactly like the existing "more than ten sources" warning.

### 3.5 Index header

```markdown
<!-- knowledge-index-meta: schema_version=1.0 generated_at=<ISO8601> sources=4 items=119
     withheld_items=348 withheld_bytes=3694592 limit_items=120 limit_bytes=1048576 -->

## Shared Knowledge Index

> Generated: <ISO8601> | Sources: 4 | Items: 119
> ⚠️ Partial: 348 items (3.5mb) withheld by the configured context budget
> (120 items / 1mb). Search the corpus to reach them.
```

The four `withheld_*` / `limit_*` fields and the `⚠️ Partial` line are **omitted entirely** when
nothing was withheld. **No withheld path is ever named here** (FR-014).

`generated_at` and the `Generated:` line change on every run, so two indexes are never byte-equal
even when they select identical items. Any check for sameness must compare the item list, not the
file.

### 3.6 Context Output block — one added line

Inserted only when something was withheld (FR-015):

```
0. This corpus is PARTIAL — a context budget withheld some items. Do not
   present it as the project's complete knowledge. Say so if asked.
```

The block is otherwise literal and unchanged. The rules remain 70 × `═`.

### 3.7 Status

```
│ Source           │ Revision │ Status  │ Items      │ Budget            │ Cache Age │
│ payment-service  │ default  │ fresh   │ 35 of 312  │ 36 items (share)  │ 14 min    │
│ adr-repo         │ v2.4.1   │ fresh   │ 36 of 55   │ 36 items (share)  │ 3d        │
│ design-notes     │ default  │ fresh   │ 36 of 88   │ 36 items (share)  │ 1h        │
│ shared-contracts │ default  │ current │ 12 of 12   │ 30 items (share)  │ 12 min    │

Budget: 120 items / 1mb project-wide · no per-source ceilings set
```

Figures match § 3.2: payment-service shows 35 rather than its 36-item share because a conflict
withdrawal removed one, and shared-contracts sits under its share, having released 18.

Names the limit applied to each source (FR-018, SC-013), mirroring the existing rule that a
reported freshness state always states its threshold.

### 3.8 Search — unchanged output, new source of truth

Output format is unchanged. The inventory now comes from the per-source `.manifest.json` files
rather than `knowledge-index.md` (FR-035), so a withheld item is still returned (FR-017, SC-006).

The missing-inventory messages keep their existing three-way distinction — no sources configured,
sources unreachable with no cache, or index absent — evaluated against manifests instead of the
index.

---

## 4. Error contract

| Condition | Behaviour | Exit |
|-----------|-----------|------|
| `max_items` / `max_bytes` malformed, per source | Skip that source, name field and value | 0 |
| `max_items` / `max_bytes` malformed, project-wide | Report, ignore, continue with per-source values | 0 |
| Per-source ceiling exceeds project ceiling | Clamp, report | 0 |
| Ceiling is `0` | Treated as malformed (above) | 0 |
| Single item exceeds the size ceiling alone | Exclude, name it and its size | 0 |
| Item ceiling below the source count | Some sources get nothing; each named | 0 |
| Conflict pair cannot fit in full | All versions withdrawn, reported once | 0 |
| Budget configured, corpus fits | Nothing reported | 0 |
| No budget, corpus above advisory threshold | Warning; index unaffected | 0 |
| No enabled sources | Existing empty-config path; budget never runs | 0 |

---

## 5. Compatibility

`extension.yml` `version` **1.4.0 → 1.5.0** — additive and backward-compatible, so a minor bump.

| Contract | Status |
|----------|--------|
| Command count (5) | Unchanged — Quality Gate §2 unaffected |
| Hook entries (4, no arguments) | Unchanged — Quality Gate §10 unaffected |
| `config-template.yml` `schema_version` | Unchanged at `"1.0"` |
| Validation Rules block duplicated across 3 files | **Two rows added to all three** — Quality Gate §11 fails if they drift |
| README command table | Unchanged — no command added |
