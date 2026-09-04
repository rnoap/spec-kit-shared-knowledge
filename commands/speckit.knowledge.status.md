---
description: "Show reachability, last-sync timestamp, item count, and cache age per source"
---

## speckit.knowledge.status

**Purpose**: Display current state of all configured knowledge sources — reachability, last-sync timestamp, item count, and cache age.

**Arguments**: `$ARGUMENTS` — optional flags only:
- `--verbose` — list all cached file paths per source

---

## Algorithm Reference

Uses the same **Source Slug Generation**, **Repository Identity**, and **Cache Integrity Check** algorithms defined in `speckit.knowledge.sync.md` § Algorithm Reference.

> **The slug depends on `revision`.** A source that pins one hashes
> `<normalized-url>\n<revision>`; a source that pins none hashes the normalized URL
> alone, exactly as in 1.3.0. Resolving a source's cache directory here therefore
> requires reading its `revision` first — looking up the unpinned slug for a pinned
> source finds nothing and would report `not synced` for a perfectly good cache.

---

## Configuration Validation Rules

> **This block is duplicated verbatim in `speckit.knowledge.configure`,
> `speckit.knowledge.sync`, and `speckit.knowledge.status`.** That is deliberate.
> Extracting it to a shared file would create a runtime dependency `extension.yml`
> does not declare, so spec-kit would not install it and every command would break
> in a consumer project. Keep the three copies identical.

Apply these rules **every time `knowledge-config.yml` is read**, not only when a
command writes it (FR-029). Configuration reaches a project by hand-editing, by
pull request, and from older versions of this extension — validating only on write
leaves all three routes unchecked.

`sources:` written with no value parses as **null**, not as an empty list. Treat
absent, null, and `[]` identically: the project has no configured sources.

| Field | Rule |
|-------|------|
| `schema_version` | Required. Exactly `"1.0"`. |
| `max_cache_age` (top level and per source) | Optional. Matches `^[0-9]+[mhd]$` — `30m`, `4h`, `7d`. |
| `url` | Required, non-empty. Either a local path (`/`, `./`, `../`, `~`) that exists and contains `.git`, or a remote URL matching `^(https?://\|ssh://\|git\+ssh://\|git@)`. **Must not begin with `-`.** |
| `label` | Optional in the file, derived when absent. Non-empty, no whitespace, **unique across `sources`** (FR-028). |
| `revision` | Optional. Non-empty, matching `^[A-Za-z0-9._/-]+$`. **Must not begin with `-`**, must not contain `..`, must not end with `.lock`. |
| `path_filter` | Optional. A string or a list of strings. Each entry non-empty, **no leading `/`**, **no `..`**, and **must not begin with `-`**. |
| `enabled` | Optional, default `true`. Exactly `true` or `false` — `"yes"` and `1` are rejected. |

### Why no value may begin with `-`

Every `url`, `revision`, and `path_filter` is interpolated into a `git` command
line. A value beginning with `-` is parsed by `git` as an **option**, not as data.
A `revision` of `--upload-pack=<command>` handed to `git fetch` is remote code
execution on the developer's machine, triggered by nothing more than a pull
request that edits a YAML file.

FR-034 therefore requires **two** defenses, and neither is sufficient alone:

1. **Reject** — any value beginning with `-` fails its rule above.
2. **Neutralize** — every `git` invocation that consumes a configuration value
   places `--` before it, so a value that bypassed defense 1 still cannot be read
   as an option.

### On failure

A value that violates its rule skips **only its own source** (FR-030):

```
⚠️  payments-v2: skipped — invalid `revision` value "-u" (must not begin with "-")
```

Every other source is processed normally and the command exits **0** (FR-023).
Always name the field and the offending value, so the user can fix it without
guessing.

---

## Behavior

### 1. Read configuration

Read `.specify/extensions/knowledge/knowledge-config.yml`.

- If absent: print:
  ```
  ℹ️  knowledge extension is not configured for this project.
  Run __SPECKIT_COMMAND_KNOWLEDGE_CONFIGURE__ to add knowledge sources.
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
   Config: .specify/extensions/knowledge/knowledge-config.yml
   Index:  .specify/extensions/knowledge/knowledge-index.md

┌──────────────────────┬──────────────┬──────────────┬──────────┬───────┬────────────┐
│ Source               │ Reachability │ Revision     │ Status   │ Items │ Cache Age  │
├──────────────────────┼──────────────┼──────────────┼──────────┼───────┼────────────┤
│ payment-service      │ ✅ reachable │ default      │ fresh    │ 12    │ 14 min     │
│ payments-v2          │ ✅ reachable │ v2.4.1       │ fresh    │ 12    │ 3d         │
│ identity-service     │ ✅ reachable │ main         │ fresh    │ 8     │ 14 min     │
│ shared-contracts     │ ❌ timeout   │ default      │ cached   │ 5     │ 29h        │
│ legacy-service       │ — disabled  │ default      │ —        │ —     │ —          │
└──────────────────────┴──────────────┴──────────────┴──────────┴───────┴────────────┘

Freshness policy: payments-v2 7d (per-source) · others 4h (project) · legacy-service none (24h default)
Total: 37 items from 4 sources (3 reachable, 1 cached, 1 disabled)
```

The **Revision** column shows each source's effective revision, or `default` when
none is pinned (FR-014). Two rows may share a URL and differ only here — that is
the point of pinning, and the label is what tells them apart.

Status values:
- `fresh` — the cache is within its effective `max_cache_age`
- `cached` — the cache is older than its effective `max_cache_age`
- `not synced` — no manifest found
- `corrupted` — manifest exists but fails integrity check

**The policy determines the label, not any fixed threshold** (FR-033). The
effective policy is the source-level `max_cache_age`, else the project-level one,
else **none**. A source with no policy keeps the legacy 24-hour heuristic —
`fresh` within 24h, `cached` beyond it. That fallback is not a leftover: FR-024
requires a project that upgrades and changes nothing to report exactly as before.

Without this rule a source with `max_cache_age: 7d` synced three days ago would be
*fresh by policy* and *cached by heuristic* — two contradictory labels for one
state. Always print the **Freshness policy** line so the threshold behind each
label is visible, and no label is ever unexplained.

Indicate if `knowledge-index.md` is absent:
```
⚠️  knowledge-index.md not found — run __SPECKIT_COMMAND_KNOWLEDGE_SYNC__ to generate it.
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
