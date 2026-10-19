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

## Output safety (007 FR-005)

Every message is the agent's own output, never a shell `echo` or `printf`.
Escape configuration values (including the schema version), source labels,
fetched file names and paths, query text, tags, timestamps, excerpts and conflict
names before displaying them. Show line feed as `\n`, tab as `\t`, carriage return
as `\r`, escape U+001B as `\e`, other characters below U+0020 or from U+007F to
U+009F as `\xHH` (two hexadecimal digits), and backslash as `\\`. Inside a quoted
value, show a double quote as `\"`. Leave other characters unchanged. Match and
filter using the original values, not their display-escaped forms.

---

## Behavior

### 1. Load the corpus inventory

**Schema gate (007 FR-014).** First read
`.specify/extensions/knowledge/knowledge-config.yml` with the agent's file-reading
tool. If the file is absent or its YAML is invalid, report the corresponding
file-level error from `__SPECKIT_COMMAND_KNOWLEDGE_SYNC__` and exit 0 without
source or cache use. Accept only `schema_version: "1.1"`. For `"1.0"`, print:

```text
Error: knowledge-config.yml schema_version "1.0" requires migration to "1.1". Back up the file, review the README migration notes, then change only schema_version. No sources or caches were used or changed.
```

For a missing or unknown version, print the following, substituting `<missing>`
when absent and escaping `<value>` under Output safety:

```text
Error: Unrecognized knowledge-config.yml schema_version "<value>". Expected "1.1". No sources or caches were used or changed.
```

Both paths exit 0 before any source use, shell use of source values, slug
computation, manifest read, reachability check, pruning, automatic sync fallback,
or configuration/cache write or deletion. Leave configuration and caches
unchanged; never migrate or downgrade automatically. Manifest and index schema
versions are unchanged.

**Per-source validation (007 FR-002).** After the schema gate succeeds, apply
every rule in `__SPECKIT_COMMAND_KNOWLEDGE_SYNC__` § Configuration Validation Rules
to every configured source, including disabled sources, in the agent's own
reasoning. Follow its check order: `url`, then each `path_filter` entry, then the
remaining source fields; character checks precede other syntax checks, and all
syntax checks precede local existence checks. Check label uniqueness across the
whole source list and exclude every source sharing a duplicate label. Treat
absent, null and empty `sources` as no configured sources.

For each source that is not accepted, emit only its first failure, once per
search invocation, before any other output about sources and before `🔍 Search:`.
Use sync's `On failure` field and reason, with this format:

```text
⚠️  <source>: skipped — invalid `<field>` value "<value>" (<reason>)
```

Use its label; without one, derive a label only from an accepted URL, otherwise
use `source <n>`, its 1-based position. Escape the source, field, value and reason
under Output safety. Skip that source entirely: no value reaches a shell, no slug
is computed, no manifest is read, no reachability check runs, and it contributes
nothing to results or item/source counts. Leave its configuration and cache
unchanged, and continue with the other sources.

**Slug gate (007 FR-006).** For each accepted, enabled source, compute its slug
using sync's § Source Slug Generation, with its quoting rule. Before using the
slug in any path, confirm the procedure printed exactly 12 lowercase hex
characters (`^[0-9a-f]{12}$`). Otherwise leave the source out, read no manifest
through that slug, and contribute nothing to results or item/source counts.
Never substitute the cache root or another directory for an invalid slug.

Read every `.specify/extensions/knowledge/cache/<slug>/.manifest.json` belonging to
an **accepted, enabled source whose slug passed the gate** (an eligible source).
Their combined `items[]` are the search corpus.

Never paste a fetched file name into any shell command, including a command the
agent composes itself or an integrity check. Integrity commands follow sync's
quoted-variable and redirection rule: file names enter only through `"$file"`,
never as command text (007 FR-006).

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
§ Algorithm Reference only after the schema, source and slug gates, and before
trusting a manifest; discard a corrupted one and treat its source as unavailable
for this search.

If no enabled sources are configured, use the no-enabled-sources message below
and exit 0 without running sync. If enabled sources exist but none is eligible,
continue to step 2 with an empty corpus (0 sources), without running sync.

- If **eligible sources remain but none has a usable manifest**, print the
   following and run sync first:
  ```
  ℹ️  No cached knowledge found — running sync first...
  ```
   Re-read configuration and reapply the schema and source gates before executing
   the sync command (`__SPECKIT_COMMAND_KNOWLEDGE_SYNC__`); enforce the slug gate on
   its cache uses too. After sync, re-read configuration and repeat all three gates
   before re-reading manifests. Automatic sync never bypasses a gate. Do not repeat
   refusal lines already emitted during this search invocation, including during
   sync or the re-read.

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

Parse `$ARGUMENTS` as data in the agent's own reasoning, never by shell expansion
or evaluation. Split it into:
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
   - first 500 characters of file content (read from `cache/<slug>/<path>` only
     with the agent's file-reading tool)

All content reads for query matching, the first 150 characters used as an excerpt,
and `--verbose` use only the agent's file-reading tool, never a shell command.
A literal file name such as `$(touch pwned).md` is matched, shown and read as data;
it is never pasted into a shell or executed (007 FR-006).

Items passing all active filters are returned as results.

**The context budget does not filter this set.** An item withheld from the index is
still in its source's manifest and still on disk, so it is still returned here
(FR-017, SC-006). If a search cannot find something the cache holds, the
inventory in step 1 is being read from the wrong file.

### 5. Display results

Apply Output safety to every interpolated value in both result templates,
including the query, source labels, paths, tags, excerpts and conflict details.
Refused sources and invalid slugs contribute nothing to either count.

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

When `--verbose` is present, read the full file content with the agent's
file-reading tool, never a shell command, and replace the `Excerpt` line with it.
Escape metadata under Output safety. Preserve the content's line breaks as
layout, but escape its other control characters and backslashes under the same
rule; never execute the content:

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
