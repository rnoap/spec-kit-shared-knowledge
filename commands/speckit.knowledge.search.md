---
description: "Browse and search the knowledge corpus across all configured sources"
---

## speckit.knowledge.search

**Purpose**: Browse and search the knowledge corpus across all configured sources without triggering a full spec workflow.

**Arguments**: `$ARGUMENTS` — search query (free text) plus optional flags:
- `--source <label>` — limit results to a specific source label
- `--tag <tag>` — filter by topic tag (path-derived)
- `--verbose` — include full file content in results (not just path/excerpt)

---

## Behavior

### 1. Load knowledge index

Read `.specify/extensions/knowledge/knowledge-index.md`.

- If absent: print the following and run sync first:
  ```
  ℹ️  knowledge-index.md not found — running sync first...
  ```
  Execute the sync command (`__SPECKIT_COMMAND_KNOWLEDGE_SYNC__`), then re-read the index.

  If the index is still absent after sync, the cause determines the message.
  Distinguish the two — they call for different actions, and conflating them sends
  the user to debug a network problem that does not exist:

  **No enabled sources are configured.** Sync deletes the index in this state
  (FR-031), so it is reachable by ordinary use — removing or disabling the last
  source produces it.
  ```
  ℹ️  No enabled knowledge sources are configured for this project — nothing to search.
     Add one with __SPECKIT_COMMAND_KNOWLEDGE_CONFIGURE__ <url>, or re-enable a
     disabled source with __SPECKIT_COMMAND_KNOWLEDGE_REMOVE__ <label> --enable.
  ```

  **Sources are configured but none could be reached and none has a usable cache.**
  ```
  ❌ Unable to build knowledge index. Sources are configured but none is reachable
     and none has an intact cache. Run __SPECKIT_COMMAND_KNOWLEDGE_STATUS__ to see why.
  ```

  Exit 0 on both paths.

### 2. Parse arguments

Split `$ARGUMENTS` into:
- **query**: all tokens that are not flags or flag values (free text, case-insensitive)
- **--source `<label>`**: if present, restrict results to sources with this label (exact match, case-insensitive)
- **--tag `<tag>`**: if present, restrict results to items whose topic tags include this value
- **--verbose**: if present, include full file content

### 3. Derive topic tags per item

For each item path, derive tags as the path components (split on `/`, strip `.md` extension):
- `specs/events/payment-completed.md` → tags: `specs`, `events`, `payment-completed`
- `decisions/retry-policy.md` → tags: `decisions`, `retry-policy`

### 4. Filter and match

For each item in the index:

1. Apply `--source` filter: skip if source label does not match (when flag is present)
2. Apply `--tag` filter: skip if derived tags do not include the tag value (when flag is present)
3. Apply text match: case-insensitive match of query against:
   - item `path`
   - item topic tags (space-joined)
   - first 500 characters of file content (read from `cache/<slug>/<path>`)

Items passing all active filters are returned as results.

### 5. Display results

**Results found**:
```
🔍 Search: "<query>"

Found <N> items across <M> sources:

  📄 <label> › <path>
     Tags: <tag1>, <tag2>, <tag3>
     Last modified: <ISO8601>
     Excerpt: "<first 150 chars of content>..."

  📄 <label> › <path>
     Tags: <tag1>, <tag2>
     Last modified: <ISO8601>
     Excerpt: "<first 150 chars of content>..."
     ⚠️  CONFLICT: also in <other-label> › <path>
```

`Last modified` is read from `.manifest.json` item metadata if available, else omitted.

**No results**:
```
🔍 Search: "<query>"

No matching items found across <M> sources.
Tip: Run __SPECKIT_COMMAND_KNOWLEDGE_SYNC__ to refresh the cache, then try again.
```

---

## --verbose flag

When `--verbose` is present, replace the `Excerpt` line with the full file content:

```
  📄 <label> › <path>
     Tags: <tag1>, <tag2>
     Last modified: <ISO8601>

     --- Full content ---
     <full markdown content of the file>
     --- End content ---
```

---

## Exit codes

`0` always — "no results" is a successful search, not an error.
