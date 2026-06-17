---
description: "Refresh local cache for all configured knowledge sources"
---

## speckit.knowledge.sync

**Purpose**: Refresh the local cache for all configured, enabled knowledge sources.

**Arguments**: `$ARGUMENTS` — optional flags only:
- `--verbose` — print list of files loaded from each source and items written to index
- `--no-context-output` — suppress the trailing Context Output for AI Agents block (diagnostic use only)

---

## Algorithm Reference (shared with speckit.knowledge.status)

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
- Cache dir: `.specify/extensions/knowledge/cache/abc123def456/`

### Cache Integrity Check (`.manifest.json`)

Run this check before using an existing cache as fallback:

1. `.manifest.json` exists AND is valid JSON → pass step 1
2. `item_count` == `len(items)` == actual `.md` file count in directory (excluding `.manifest.json` and `.git/`) → pass step 2
3. Each item's `sha256` matches `sha256sum <file>` (or `shasum -a 256` on macOS) → pass step 3
4. All three pass → cache is intact; use it
5. Any failure → cache is corrupted; discard directory; attempt fresh sync

### `knowledge-index.md` Format

Written to `.specify/extensions/knowledge/knowledge-index.md`. This is the **only file** that `speckit-specify` and `speckit-plan` read directly.

```markdown
<!-- knowledge-index-meta: schema_version=1.0 generated_at=<ISO8601> sources=<N> items=<N> -->

## Shared Knowledge Index

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

Read `.specify/extensions/knowledge/knowledge.yml`.

- If file absent: print `❌ Error: knowledge.yml not found. Run /speckit-knowledge-configure to initialize.` and exit 0.
- If YAML invalid: print `❌ Error: knowledge.yml contains invalid YAML: <parse error>` and exit 0.
- If `schema_version` missing or unknown: print `❌ Error: Unrecognized schema_version. Expected "1.0".` and exit 0.
- If `sources` key missing: print `❌ Error: knowledge.yml is missing the required "sources" key.` and exit 0.

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

**Detect source type** before choosing clone flags:
- **Local path**: `url` starts with `/`, `~/`, `./` → expand `~` to `$HOME`
- **Remote URL**: everything else

#### Cold path (fresh clone)

**Remote URL**:
```bash
mkdir -p .specify/extensions/knowledge/cache/<slug>

timeout 10 git clone \
  --filter=blob:none \
  --no-checkout \
  --depth=1 \
  <url> \
  .specify/extensions/knowledge/cache/<slug>
```

**Local path** (no network flags needed — clone is instant):
```bash
mkdir -p .specify/extensions/knowledge/cache/<slug>

git clone \
  --no-checkout \
  <expanded-path> \
  .specify/extensions/knowledge/cache/<slug>
```

After clone (both remote and local), apply sparse-checkout if `path_filter` is set:
```bash
cd .specify/extensions/knowledge/cache/<slug>
# Use --no-cone so the pattern restricts checkout to ONLY <path_filter>.
# Cone mode always includes root-level files (package.json, Dockerfile, etc.)
# regardless of the pattern, which violates the path_filter contract.
git sparse-checkout init --no-cone
# Normalize the pattern: ensure it ends with a slash so git treats it as
# a directory match (e.g. "specs" → "specs/", "specs/" stays "specs/").
git sparse-checkout set "<path_filter>"
git checkout
```

> **Pattern semantics**: in `--no-cone` mode, git uses gitignore-style patterns. A bare directory name like `specs/` matches every file recursively under `specs/` and **nothing else**. Root-level files at the cache root are excluded. This matches user expectations: `path_filter: specs/` means "only `specs/` content".

If no `path_filter`:
```bash
cd .specify/extensions/knowledge/cache/<slug>
git checkout HEAD -- .
```

#### Warm path (update)

Before pulling new content, **re-apply the sparse-checkout configuration in `--no-cone` mode** if `path_filter` is set. This is idempotent and self-heals caches that were originally cloned with the buggy `--cone` configuration (which always included root-level files):

```bash
cd .specify/extensions/knowledge/cache/<slug>
if [ -n "<path_filter>" ]; then
  git sparse-checkout init --no-cone
  git sparse-checkout set "<path_filter>"
  # Remove any stray files outside the path_filter that an older --cone
  # checkout may have left behind in the working tree.
  git sparse-checkout reapply
fi
```

**Remote URL**:
```bash
cd .specify/extensions/knowledge/cache/<slug>
timeout 10 git fetch --depth=1 origin
git checkout origin/HEAD -- .
```

**Local path** (fetch from local remote — also instant, no timeout needed):
```bash
cd .specify/extensions/knowledge/cache/<slug>
git fetch origin
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

Write `.specify/extensions/knowledge/cache/<slug>/.manifest.json` **as the final step** after all `.md` files are written:

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

Write to `.specify/extensions/knowledge/knowledge-index.md`.

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
   → .specify/extensions/knowledge/knowledge-index.md
```

### 10. Emit Context Output for AI Agents block (conditional)

This is the LAST thing printed on stdout. Nothing follows it.

**Emission ordering**: status lines (step 9) → summary line → pointer line → one blank line → the block.

**Emit the block when** (`suppress_context_output` is false AND one of):
- ≥ 1 source returned status `fresh`, OR
- All sources are `cached` but ≥ 1 has a usable cache (i.e., `knowledge-index.md` exists), OR
- Mix of `cached` + `unreachable`, ≥ 1 source has a usable cache.

**Do NOT emit the block when** any of:
- `suppress_context_output = true` (flag `--no-context-output` was passed), OR
- An early-exit error was printed in step 1 (config absent, invalid YAML, unknown schema_version, missing sources key) — there is no `knowledge-index.md` to point to on these paths, OR
- All sources are `unreachable` AND no prior `knowledge-index.md` exists — instead print the soft warning below.

**Soft warning (all unreachable + no cache, FR-013a)**:

```
⚠️  No knowledge-index.md found yet. Run /speckit-knowledge-sync once when sources are reachable.
```

Then exit 0.

**The block (literal — no substitution)**:

```
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

The top and bottom rules are exactly 70 × U+2550 (`═`), on their own lines with no trailing whitespace. Exit code remains 0 on all emission paths.

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

## --no-context-output flag

When `--no-context-output` is present in `$ARGUMENTS`, set `suppress_context_output = true` and skip emitting the trailing Context Output for AI Agents block (step 10). All other output — per-source status lines, summary line, pointer line — prints identically. Exit code remains 0.

This flag is parsed using the same `$ARGUMENTS` token-scan pattern as `--verbose`. It composes orthogonally with `--verbose` (both may be present simultaneously). The auto-trigger paths (`before_specify`, `before_plan`) declare no arguments in `extension.yml`, so `--no-context-output` is structurally unreachable from those hooks — the block always emits on auto-trigger.

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
| All sources unreachable, no prior index | Soft warning, no context block | 0 |
| `--no-context-output` flag present | Context block suppressed | 0 |

---

## Side effects

- Creates `cache/<slug>/` directories with sparse-checkout git state
- Writes `cache/<slug>/.manifest.json` per source
- Writes/updates `knowledge-index.md`
- Does **not** modify `knowledge.yml`
- Does **not** modify `.specify/extensions.yml`
