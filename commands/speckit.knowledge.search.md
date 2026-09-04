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

### 1. Load the corpus inventory

Read every `.specify/extensions/knowledge/cache/<slug>/.manifest.json` belonging to
an **enabled** configured source. Their combined `items[]` are the search corpus.

> **Search reads the manifests, not `knowledge-index.md`.** The two files have
> different audiences and different sizes on purpose. The index is bounded by the
> context budget because an agent reads **all** of it; a search returns only what a
> query matched, so it has no reason to be bounded — and binding it would make a
> withheld item unfindable, which is exactly the difference between *un-injected*
> and *unavailable* (FR-017, FR-035).
>
> The manifest is written **before** the budget is applied, so it always holds the
> complete item list for its source. That is what makes this work with no third
> record to maintain.

Run the Cache Integrity Check from `__SPECKIT_COMMAND_KNOWLEDGE_SYNC__`
§ Algorithm Reference before trusting a manifest; discard a corrupted one and treat
its source as unavailable for this search.

- If **no manifest exists for any enabled source**, print the following and run
  sync first:
  ```
  ℹ️  No cached knowledge found — running sync first...
  ```
  Execute the sync command (`__SPECKIT_COMMAND_KNOWLEDGE_SYNC__`), then re-read.

  If nothing is readable after that, the cause determines the message. Distinguish
  the three — they call for different actions, and conflating them sends the user
  to debug a problem that does not exist:

  **No enabled sources are configured.** Reachable by ordinary use — removing or
  disabling the last source produces it.
  ```
  ℹ️  No enabled knowledge sources are configured for this project — nothing to search.
     Add one with __SPECKIT_COMMAND_KNOWLEDGE_CONFIGURE__ <url>, or re-enable a
     disabled source with __SPECKIT_COMMAND_KNOWLEDGE_REMOVE__ <label> --enable.
  ```

  **Sources are configured but none could be reached and none has an intact cache.**
  ```
  ❌ Unable to search. Sources are configured but none is reachable and none has an
     intact cache. Run __SPECKIT_COMMAND_KNOWLEDGE_STATUS__ to see why.
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

For each item in the corpus inventory from step 1:

1. Apply `--source` filter: skip if source label does not match (when flag is present)
2. Apply `--tag` filter: skip if derived tags do not include the tag value (when flag is present)
3. Apply text match: case-insensitive match of query against:
   - item `path`
   - item topic tags (space-joined)
   - first 500 characters of file content (read from `cache/<slug>/<path>`)

Items passing all active filters are returned as results.

**The context budget does not filter this set.** An item withheld from the index is
still in its source's manifest and still on disk, so it is still returned here
(FR-017, SC-006). If a search cannot find something the cache holds, the
inventory in step 1 is being read from the wrong file.

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
