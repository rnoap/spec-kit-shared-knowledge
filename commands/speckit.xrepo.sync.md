---
description: "Refresh local cache for all configured knowledge sources"
---

## speckit.xrepo.sync

**Purpose**: Refresh the local cache for all configured, enabled knowledge sources.

**Arguments**: `$ARGUMENTS` — optional flags only:
- `--verbose` — print list of files loaded from each source and items written to index

---

## Algorithm Reference (shared with speckit.xrepo.status)

### Source Slug Generation

Every source URL is normalized to a stable 12-character slug used as the cache directory name.

```bash
# 1. Normalize URL
normalized=$(echo "$url" \
  | sed 's/\.git$//' \           # strip trailing .git
  | sed 's|/$||' \               # strip trailing slash
  | tr '[:upper:]' '[:lower:]')  # lowercase

# 2. SHA-256 and take first 12 chars
if command -v sha256sum >/dev/null 2>&1; then
  slug=$(echo -n "$normalized" | sha256sum | cut -c1-12)
else
  # macOS fallback
  slug=$(echo -n "$normalized" | shasum -a 256 | cut -c1-12)
fi
```

**Example**:
- Input: `https://GitHub.com/org/payment-service.git`
- Normalized: `https://github.com/org/payment-service`
- Slug: first 12 hex chars of SHA-256 → `abc123def456`
- Cache dir: `.specify/extensions/cross-repo-knowledge/cache/abc123def456/`

### Cache Integrity Check (`.manifest.json`)

Run this check before using an existing cache as fallback:

1. `.manifest.json` exists AND is valid JSON → pass step 1
2. `item_count` == `len(items)` == actual `.md` file count in directory (excluding `.manifest.json` and `.git/`) → pass step 2
3. Each item's `sha256` matches `sha256sum <file>` (or `shasum -a 256` on macOS) → pass step 3
4. All three pass → cache is intact; use it
5. Any failure → cache is corrupted; discard directory; attempt fresh sync

### `knowledge-index.md` Format

Written to `.specify/extensions/cross-repo-knowledge/knowledge-index.md`. This is the **only file** that `speckit-specify` and `speckit-plan` read directly.

```markdown
<!-- cross-repo-knowledge-index: generated_at=<ISO8601> sources=<N> items=<N> -->

## Cross-Repo Knowledge Index

> Generated: <ISO8601> | Sources: <N> | Items: <N>

### Source: <label> (<url>)
**Status**: <fresh|cached|unreachable> | **Synced**: <ISO8601> | **Items**: <N> | **Path filter**: <path_filter or "all .md files">

- [<relative-path>](cache/<slug>/<relative-path>)
- [<relative-path>](cache/<slug>/<relative-path>)
...

---
*⚠️ Conflicts: <N> — `<path>` present in <source-a> AND <source-b>. Both included.*
```

The machine-readable HTML comment on line 1 allows scripts to detect the index without reading the full file.

---

## Behavior

### 1. Read and validate configuration

Read `.specify/extensions/cross-repo-knowledge/cross-repo-knowledge.yml`.

- If file absent: print `❌ Error: cross-repo-knowledge.yml not found. Run /speckit-xrepo-configure to initialize.` and exit 0.
- If YAML invalid: print `❌ Error: cross-repo-knowledge.yml contains invalid YAML: <parse error>` and exit 0.
- If `schema_version` missing or unknown: print `❌ Error: Unrecognized schema_version. Expected "1.0".` and exit 0.
- If `sources` key missing: print `❌ Error: cross-repo-knowledge.yml is missing the required "sources" key.` and exit 0.

### 2. Source-count warning

If `len(enabled sources) > 10`:
```
⚠️  Warning: 12 knowledge sources configured. Syncing many sources may be slow.
    Tip: Use path_filter to reduce clone size per source.
```
Continue normally — this is informational only.

### 3. Print sync header

```
🔄 Syncing cross-repo knowledge sources...
```

### 4. For each enabled source

Skip sources where `enabled: false`.

For each enabled source, compute the slug using the Source Slug Generation algorithm above.

**Determine sync path**:
- **Cold path**: `cache/<slug>/` does not exist → fresh clone
- **Warm path**: `cache/<slug>/` exists → fetch update

#### Cold path (fresh clone)

```bash
mkdir -p .specify/extensions/cross-repo-knowledge/cache/<slug>

timeout 10 git clone \
  --filter=blob:none \
  --no-checkout \
  --depth=1 \
  <url> \
  .specify/extensions/cross-repo-knowledge/cache/<slug>
```

If `path_filter` is set:
```bash
cd .specify/extensions/cross-repo-knowledge/cache/<slug>
git sparse-checkout init --cone
git sparse-checkout set <path_filter>
git checkout
```

If no `path_filter`:
```bash
cd .specify/extensions/cross-repo-knowledge/cache/<slug>
git checkout HEAD -- .
```

#### Warm path (update)

```bash
cd .specify/extensions/cross-repo-knowledge/cache/<slug>
timeout 10 git fetch --depth=1 origin
git checkout origin/HEAD -- .
```

#### On timeout or failure

1. Run the Cache Integrity Check on existing `cache/<slug>/`.
2. If intact: set status = `cached`; read items from existing cache; record `last_synced_at` from `.manifest.json`; continue.
3. If absent or corrupted: set status = `unreachable`; skip this source; emit warning; continue to next source.

**Exit code is always 0** — degraded operation is not a failure.

### 5. Index .md files per source

After a successful sync (cold or warm), recursively find all `.md` files under the path_filter (or all `.md` files if no filter). For each file:
- Record relative path from cache root
- Compute SHA-256: `sha256sum <file>` or `shasum -a 256 <file>` (macOS)

### 6. Write `.manifest.json` (last step)

Write `.specify/extensions/cross-repo-knowledge/cache/<slug>/.manifest.json` **as the final step** after all `.md` files are written:

```json
{
  "schema_version": "1.0",
  "source_url": "<url>",
  "source_slug": "<slug>",
  "synced_at": "<ISO8601-timestamp>",
  "item_count": <N>,
  "items": [
    {"path": "<relative-path>", "sha256": "<hex>"},
    ...
  ]
}
```

Writing the manifest last signals cache integrity — an absent manifest means the sync was interrupted.

### 7. Detect conflicts

After indexing all sources, compare relative paths across all `fresh` and `cached` sources.

For each path that appears in two or more sources:
- Record a `KnowledgeConflict`: `{path, sources: [label-a, label-b]}`
- Both items are included in the index (no silent winner)
- Emit `⚠️ CONFLICT` in the index and in the per-source status line

### 8. Write knowledge-index.md

Assemble `knowledge-index.md` using the format defined in the Algorithm Reference above.

Write to `.specify/extensions/cross-repo-knowledge/knowledge-index.md`.

Include a conflict section footer if any conflicts were detected.

### 9. Print summary

For each source, print one status line:

```
  payment-service    ✅ fresh    12 items  (synced 2026-06-11T14:00:00Z)
  identity-service   ✅ fresh    8 items   (synced 2026-06-11T14:00:00Z)
```

Cache fallback:
```
  identity-service   ⚠️  cached   8 items   (last synced 2026-06-10T09:00:00Z — 29h ago)
                     Could not reach https://github.com/org/identity-service (timeout after 10s)
```

Unreachable with no cache:
```
  shared-contracts   ❌  unreachable — no cache available; source skipped
```

Final summary line:
```
✅ Knowledge index updated: 20 items from 2 sources.
   → .specify/extensions/cross-repo-knowledge/knowledge-index.md
```

---

## --verbose flag

When `--verbose` is present in `$ARGUMENTS`, after each source's status line print:

```
--- VERBOSE: files loaded from payment-service ---
specs/events/payment-completed.md
specs/events/payment-failed.md
decisions/retry-policy.md
[... 9 more]
--- END VERBOSE ---
```

---

## Error cases summary

| Condition | Status | Exit |
|-----------|--------|------|
| Config file absent | Error message | 0 |
| Config YAML invalid | Error message | 0 |
| `schema_version` unknown | Error message | 0 |
| `sources` count > 10 | Warning + continue | 0 |
| Git timeout on cold sync | `cached` or `unreachable` | 0 |
| Git timeout on warm sync | `cached` or `unreachable` | 0 |
| Manifest corrupted | Discard + retry or `unreachable` | 0 |
| Conflict detected | `⚠️ CONFLICT` in index | 0 |

---

## Side effects

- Creates `cache/<slug>/` directories with sparse-checkout git state
- Writes `cache/<slug>/.manifest.json` per source
- Writes/updates `knowledge-index.md`
- Does **not** modify `cross-repo-knowledge.yml`
- Does **not** modify `.specify/extensions.yml`
