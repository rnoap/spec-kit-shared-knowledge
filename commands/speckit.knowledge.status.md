---
description: "Show reachability, last-sync timestamp, item count, and cache age per source"
---

## speckit.knowledge.status

**Purpose**: Display current state of all configured knowledge sources — reachability, last-sync timestamp, item count, and cache age.

**Arguments**: `$ARGUMENTS` — optional flags only:
- `--verbose` — list all cached file paths per source

---

## Algorithm Reference

Uses the same **Source Slug Generation** and **Cache Integrity Check** algorithms defined in `speckit.knowledge.sync.md` § Algorithm Reference.

---

## Behavior

### 1. Read configuration

Read `.specify/extensions/knowledge/knowledge.yml`.

- If absent: print:
  ```
  ℹ️  knowledge extension is not configured for this project.
  Run /speckit-knowledge-configure to add knowledge sources.
  ```
  Exit 0.
- If YAML invalid: print error and exit 0.

### 2. Read manifests

For each source (enabled or disabled), compute the slug and read `cache/<slug>/.manifest.json`:
- If manifest exists and valid: record `synced_at`, `item_count`, derived cache age
- If manifest absent: status = `not synced`
- If manifest invalid JSON: status = `corrupted`

Cache age is computed from `synced_at` to now:
- `< 60 min`: display as `N min`
- `1h–48h`: display as `Nh`
- `> 48h`: display as `Nd`

### 3. Check reachability

**Detect source type**: `url` starts with `/`, `~/`, `./` → local path; otherwise remote URL.

**Remote URL**:
```bash
timeout 5 git ls-remote --exit-code <url> HEAD
```
- Exit 0 → `✅ reachable`
- Non-zero / timeout → `❌ timeout`

**Local path** (expand `~` to `$HOME` first):
```bash
[ -d "<expanded-path>/.git" ] || git -C "<expanded-path>" rev-parse --git-dir 2>/dev/null
```
- Directory exists and is a git repo → `✅ reachable (local)`
- Directory absent or not a git repo → `❌ not found`

Disabled sources: show `— disabled` without a reachability check.

### 4. Print status table

```
📊 Shared Knowledge Status
   Config: .specify/extensions/knowledge/knowledge.yml
   Index:  .specify/extensions/knowledge/knowledge-index.md

┌──────────────────────┬──────────────┬──────────┬───────┬────────────┐
│ Source               │ Reachability │ Status   │ Items │ Cache Age  │
├──────────────────────┼──────────────┼──────────┼───────┼────────────┤
│ payment-service      │ ✅ reachable │ fresh    │ 12    │ 14 min     │
│ identity-service     │ ✅ reachable │ fresh    │ 8     │ 14 min     │
│ shared-contracts     │ ❌ timeout   │ cached   │ 5     │ 29h        │
│ legacy-service       │ — disabled  │ —        │ —     │ —          │
└──────────────────────┴──────────────┴──────────┴───────┴────────────┘

Total: 25 items from 3 sources (2 reachable, 1 cached, 1 disabled)
```

Status values:
- `fresh` — synced_at is within the last 24h
- `cached` — synced_at is older than 24h
- `not synced` — no manifest found
- `corrupted` — manifest exists but fails integrity check

Indicate if `knowledge-index.md` is absent:
```
⚠️  knowledge-index.md not found — run /speckit-knowledge-sync to generate it.
```

### 5. --verbose flag

When `--verbose` is present, after each source row that has a cache, print the list of cached `.md` file paths:

```
--- VERBOSE: cached files for payment-service ---
specs/events/payment-completed.md
specs/events/payment-failed.md
decisions/retry-policy.md
[... 9 more]
--- END VERBOSE ---
```

---

## Exit codes

`0` always.
