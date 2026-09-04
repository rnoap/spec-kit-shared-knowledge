---
description: "Refresh local cache for all configured knowledge sources"
---

## speckit.knowledge.sync

**Purpose**: Refresh the local cache for all configured, enabled knowledge sources.

**Arguments**: `$ARGUMENTS` — optional flags only:
- `--verbose` — print list of files loaded from each source and items written to index
- `--force` — ignore the cache freshness policy and fetch every enabled source
- `--no-context-output` — suppress the trailing Context Output for AI Agents block (diagnostic use only)

---

## Algorithm Reference (shared with speckit.knowledge.status)

### Source Slug Generation

Every source is reduced to a stable 12-character slug used as its cache directory name.

```bash
# 1. Normalize URL
normalized=$(echo "$url" \
  | sed 's/\.git$//' \           # strip trailing .git
  | sed 's|/$||' \               # strip trailing slash
  | tr '[:upper:]' '[:lower:]')  # lowercase

# 2. Fold in the revision ONLY when one is pinned.
#
#    This conditional is the whole backward-compatibility guarantee (FR-024).
#    A source with no `revision` hashes exactly the bytes it hashed in 1.3.0, so
#    upgrading re-downloads nothing. Always including a default like "HEAD" would
#    change every existing slug and invalidate every consumer's cache.
#
#    The separator is a NEWLINE, not "@": SSH URLs already contain "@", so
#    (url="git@h:o/r", rev="v1") and (url="git@h:o/r@v1", rev="") would collide.
#    git refuses control characters in refnames and no URL scheme permits a raw
#    newline, so the two operands cannot be confused.
if [ -z "$revision" ]; then
  hash_input=$(printf '%s' "$normalized")
else
  hash_input=$(printf '%s\n%s' "$normalized" "$revision")
fi

# 3. SHA-256 and take first 12 chars
#
#    Use `printf '%s'`, NEVER `echo -n`. `echo -n` is not portable: under a POSIX
#    shell (/bin/sh on macOS is bash in POSIX mode) it emits the literal "-n "
#    before the string, so the same URL hashes to a different slug depending on
#    which shell the agent happened to use. Verified:
#      /bin/sh   echo -n → 1dcedc6df20c   (hashes "-n https://…")
#      bash/zsh  echo -n → 18dbb51ec4eb
#      printf %s          → 18dbb51ec4eb
if command -v sha256sum >/dev/null 2>&1; then
  slug=$(printf '%s' "$hash_input" | sha256sum | cut -c1-12)
else
  # macOS fallback
  slug=$(printf '%s' "$hash_input" | shasum -a 256 | cut -c1-12)
fi
```

**Example — unpinned** (identical to 1.3.0):
- Input: `https://GitHub.com/org/payment-service.git`
- Normalized: `https://github.com/org/payment-service`
- Slug: first 12 hex chars of SHA-256 → `abc123def456`
- Cache dir: `.specify/extensions/knowledge/cache/abc123def456/`

**Example — pinned**: the same URL with `revision: v2.4.1` hashes
`https://github.com/org/payment-service\nv2.4.1` and lands in a **different**
directory. That is what keeps two revisions of one repository from contaminating
each other (FR-011), and what makes a revision change serve new content on the
next sync with no invalidation logic at all (FR-012) — the old slug is simply no
longer looked up.

### Repository Identity

A **different** normalization, used for exactly one purpose: deciding whether a
shared file path is a conflict (step 7, FR-026).

```text
1. Strip a leading scheme:          https://  http://  ssh://  git://  git+ssh://
2. Strip a leading credential:      everything up to and including the first "@"
3. Convert SCP-style to path form:  host:org/repo   →   host/org/repo
4. Strip a trailing ".git"
5. Strip a trailing "/"
6. Lowercase
```

All four of these yield the identity `github.com/org/payments`:

```text
https://github.com/org/payments.git
https://user@github.com/org/payments
git@github.com:org/payments
ssh://git@github.com/org/payments/
```

For a **local path** source, identity is the resolved absolute path (symlinks
followed, `~` expanded). A local clone is therefore not identified with the remote
it was cloned from — an accepted limitation, documented in the README.

**Identity is deliberately broader than the slug.** The slug must separate
`https://…` from `git@…` because they are different fetch targets with different
credentials and different cache state. Identity must unite them because they are
the same body of knowledge. Collapsing the two functions into one would break
either FR-011 or FR-026.

### Cache Freshness Gate

Decides whether a source is refreshed at all. Runs **before** any network access.

**Effective policy** = the source's own `max_cache_age`, else the project-level
`max_cache_age`, else **none**. With no policy, every source fetches, exactly as in
1.3.0 (FR-017).

**Convert the duration to minutes** with integer arithmetic — `Nm` → `N`, `Nh` →
`N × 60`, `Nd` → `N × 1440`.

```bash
manifest=".specify/extensions/knowledge/cache/<slug>/.manifest.json"

if [ -n "$(find "$manifest" -maxdepth 0 -mmin +"$max_age_minutes" 2>/dev/null)" ]; then
  verdict=stale     # over policy, or manifest missing → attempt a refresh
else
  verdict=fresh     # under policy → skip the network entirely
fi
```

**Why `find -mmin` and not `date`.** `date -d "$iso8601" +%s` is GNU-only;
`date -j -f '%Y-%m-%dT%H:%M:%SZ' "$iso8601" +%s` is BSD-only; `stat` differs the
same way. POSIX `find -mmin` behaves identically on macOS and Linux, and is
already in this extension's tool surface. A `python3` one-liner would work too, but
`extension.yml` declares no interpreter beyond `git`, and adding one would raise
the install bar for every consumer to save four lines.

**Manifest mtime is authoritative for the gate; `synced_at` is what is displayed.**
Sync writes `.manifest.json` last, deliberately, as its "this cache is complete"
signal — so its mtime *is* the instant the cache became valid, which is the same
instant `synced_at` records, without the parsing problem. If the two ever disagree
— a file copied without preserving timestamps, say — the gate wins and the
displayed timestamp is advisory.

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

### 1. Read and validate configuration

Read `.specify/extensions/knowledge/knowledge-config.yml`.

**File-level checks** — each aborts the run, because none of them leaves anything
safe to iterate over:

- If file absent: print `❌ Error: knowledge-config.yml not found. Run __SPECKIT_COMMAND_KNOWLEDGE_CONFIGURE__ to initialize.` and exit 0.
- If YAML invalid: print `❌ Error: knowledge-config.yml contains invalid YAML: <parse error>` and exit 0.
- If `schema_version` missing or unknown: print `❌ Error: Unrecognized schema_version. Expected "1.0".` and exit 0.
- If the `sources` key is entirely absent: print `❌ Error: knowledge-config.yml is missing the required "sources" key.` and exit 0.

**`sources` present but empty** — written as `sources:` with no value (which parses
as null), or as `sources: []`. This is a valid state, not an error: the project
declares no knowledge. Skip to step 10's empty-configuration path (FR-031).

**Per-source validation** — apply every rule in § Configuration Validation Rules to
each entry **before using any of its values** (FR-029). Then:

- A source whose values all pass is processed normally.
- A source with **any** failing value is skipped, with one line naming the field
  and the offending value. Every other source still synchronizes and the command
  still exits 0 (FR-030).
- Label uniqueness is checked across the whole list. On a collision, skip **all**
  sources sharing that label — there is no safe way to tell which one a later
  command means (FR-028).

```
⚠️  payments-v2: skipped — invalid `revision` value "-u" (must not begin with "-")
⚠️  adr-repo, adr-repo: skipped — duplicate label "adr-repo" (labels must be unique)
```

Validation runs here, on the read path, rather than only inside `configure`.
A value that arrived by hand-edit, by pull request, or from an older version of
this extension is checked exactly like one this extension wrote.

### 1a. No enabled sources — the empty-configuration path

When **no enabled sources remain** — because `sources` is empty or null, because
every source was removed, or because every source was disabled — do all of the
following and then stop (FR-031):

1. Report the project as having no configured knowledge.
2. **Delete `knowledge-index.md`** if it exists.
3. Do **not** emit the Context Output for AI Agents block.
4. Exit 0.

```
ℹ️  No enabled knowledge sources are configured for this project.
✅ Removed the stale knowledge index (.specify/extensions/knowledge/knowledge-index.md).
   Run __SPECKIT_COMMAND_KNOWLEDGE_CONFIGURE__ <url> to add a source, or
   __SPECKIT_COMMAND_KNOWLEDGE_REMOVE__ <label> --enable to re-enable a disabled one.
```

**The index is deleted rather than left in place.** A stale index would let an
agent keep reading and citing knowledge the project no longer declares — a silent
failure that looks like success. Deleting it costs nothing in interface terms,
because `status` already reports and explains a missing index.

Disabled sources keep their cache directories through this path (FR-004); only the
index is removed. Cache pruning is a separate concern, handled in step 8a.

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

Skip sources where `enabled: false`. A disabled source is not fetched, contributes
no items to the index, and appears in no status line (FR-008) — but its cache
directory is left intact so that re-enabling it costs no download (FR-004).

For each enabled source, compute the slug using the Source Slug Generation algorithm above.

**Apply the Cache Freshness Gate first — before choosing a sync path and before
any network access** (FR-018).

- `verdict=fresh` and `--force` was **not** passed → **skip this source entirely**.
  Reuse its cached content, read its item list from the existing
  `.manifest.json`, set status `current`, and move to the next source. No `git`
  runs. No network is touched.
- `verdict=stale`, or `--force` was passed → continue below.

With no effective policy configured the verdict is always `stale`, so this gate is
invisible to a project that has not opted in (FR-017, FR-024).

**Determine sync path**:
- **Cold path**: `cache/<slug>/` does not exist → fresh clone
- **Warm path**: `cache/<slug>/` exists → fetch update

**Detect source type** before choosing clone flags:
- **Local path**: `url` starts with `/`, `~/`, `./` → expand `~` to `$HOME`
- **Remote URL**: everything else

#### Cold path (fresh clone)

**Remote URL** — three tiers, tried in order. Every `git` call keeps the `--`
separator required by FR-034.

**Tier 1 — no revision pinned, or a branch or tag.** The common case, and the
cheapest. A source with **no** `revision` omits `--branch` entirely and clones the
remote's default revision, byte-identically to 1.3.0 (FR-010).

```bash
mkdir -p .specify/extensions/knowledge/cache/<slug>

timeout 10 git clone \
  --filter=blob:none \
  --no-checkout \
  --depth=1 \
  [--branch <revision>] \
  -- <url> \
  .specify/extensions/knowledge/cache/<slug>
```

**Tier 2 — a full commit SHA.** `git clone --branch` rejects a SHA, so clone empty
and fetch that one object. Escalate here only when Tier 1 failed **and**
`<revision>` matches `^[0-9a-f]{40}$` (or `^[0-9a-f]{64}$` in a SHA-256 repository).

```bash
timeout 10 git clone --filter=blob:none --no-checkout --depth=1 \
  -- <url> .specify/extensions/knowledge/cache/<slug>

cd .specify/extensions/knowledge/cache/<slug>
timeout 10 git fetch --depth=1 origin -- <revision>
git checkout -- <revision>
```

**Tier 3 — the server refuses an unadvertised object.** Fetching an arbitrary SHA
requires the server to advertise `uploadpack.allowAnySHA1InWant`. GitHub and
GitLab do; self-hosted Gitea, Bitbucket Server, and bare-repo-over-SSH often do
not, and Tier 2 fails with `error: Server does not allow request for unadvertised
object`. Trade bandwidth for correctness — note the longer timeout, since this is
a full history fetch.

```bash
cd .specify/extensions/knowledge/cache/<slug>
timeout 30 git fetch --unshallow origin
git checkout -- <revision>
```

**All three tiers failed** → this is FR-015. Report the source `unreachable` with
the declared revision named, fall back to its existing cache if the Cache
Integrity Check passes, and continue to the next source. Exit code stays 0.

```
  payments-v2        ❌  unreachable — revision "v9.9.9" could not be resolved on the remote
```

**Abbreviated SHAs are rejected, not escalated.** A 7-character prefix like
`a1b2c3d` is not fetchable by any tier, and worse, is not stable — a prefix that
is unique today can become ambiguous as the repository grows. It passes the
syntactic rule in § Configuration Validation Rules, so it surfaces here, at Tier 1
failure, as an unresolvable revision rather than degrading silently:

```
  payments-v2        ❌  unreachable — revision "a1b2c3d" looks like an abbreviated SHA;
                        pin the full 40-character commit id, a branch, or a tag
```

**Local path** (no network flags needed — clone is instant):
```bash
mkdir -p .specify/extensions/knowledge/cache/<slug>

git clone \
  --no-checkout \
  [--branch <revision>] \
  -- <expanded-path> \
  .specify/extensions/knowledge/cache/<slug>
```

After clone (both remote and local), apply sparse-checkout if `path_filter` is set. The `path_filter` field may be either a single string (`specs/`) or a YAML list (`[specs/, docs/decisions/]`); normalize to a space-separated argument list for `git sparse-checkout set`:

```bash
cd .specify/extensions/knowledge/cache/<slug>
# Use --no-cone so each pattern restricts checkout to ONLY those folders.
# Cone mode always includes root-level files (package.json, Dockerfile, etc.)
# regardless of the pattern, which violates the path_filter contract.
git sparse-checkout init --no-cone
# Normalize each pattern: ensure trailing slash so git treats it as a directory match.
# `--` before the patterns keeps a pattern beginning with "-" from being read as an
# option (FR-034).
# For a single string  → one arg:    git sparse-checkout set -- "specs/"
# For a YAML list      → multi-arg:  git sparse-checkout set -- "specs/" "docs/decisions/"
git sparse-checkout set -- <pattern1> [<pattern2> ...]
git checkout
```

> **Pattern semantics**: in `--no-cone` mode, git uses gitignore-style patterns. A bare directory name like `specs/` matches every file recursively under `specs/` and **nothing else**. Root-level files at the cache root are excluded. This matches user expectations: `path_filter: specs/` means "only `specs/` content"; `path_filter: [specs/, docs/decisions/]` means "only those two trees".

If no `path_filter`:
```bash
cd .specify/extensions/knowledge/cache/<slug>
git checkout HEAD -- .
```

#### Warm path (update)

Before pulling new content, **re-apply the sparse-checkout configuration in `--no-cone` mode** if `path_filter` is set. This is idempotent and self-heals caches that were originally cloned with the buggy `--cone` configuration (which always included root-level files). Pass each pattern in the (possibly list-form) `path_filter` as a separate argument:

```bash
cd .specify/extensions/knowledge/cache/<slug>
if [ -n "<path_filter>" ]; then
  git sparse-checkout init --no-cone
  # one or more patterns — same normalization as the cold path, same `--` (FR-034)
  git sparse-checkout set -- <pattern1> [<pattern2> ...]
  # Remove any stray files outside the path_filter that an older --cone
  # checkout may have left behind in the working tree.
  git sparse-checkout reapply
fi
```

**Remote URL** — check out the declared revision when one is pinned, and the
remote's default when none is (FR-010, FR-012). `--` retained per FR-034.

```bash
cd .specify/extensions/knowledge/cache/<slug>

if [ -z "<revision>" ]; then
  timeout 10 git fetch --depth=1 origin
  git checkout origin/HEAD -- .
else
  timeout 10 git fetch --depth=1 origin -- <revision>
  git checkout FETCH_HEAD -- .
fi
```

**Local path** (fetch from local remote — also instant, no timeout needed):
```bash
cd .specify/extensions/knowledge/cache/<slug>

if [ -z "<revision>" ]; then
  git fetch origin
  git checkout origin/HEAD -- .
else
  git fetch origin -- <revision>
  git checkout FETCH_HEAD -- .
fi
```

> A revision **change** never reaches this path. Changing `revision` changes the
> slug, so the next sync finds no cache at the new slug and takes the cold path
> instead. There is no stale-content window and no invalidation step to write.
> The directory built for the previous revision is pruned in step 8a.

#### On timeout or failure

1. Run the Cache Integrity Check on existing `cache/<slug>/`.
2. If intact: set status = `cached`; read items from existing cache; record `last_synced_at` from `.manifest.json`; continue.
3. If absent or corrupted: set status = `unreachable`; skip this source; emit warning; continue to next source.

**An over-age cache is still served here** (FR-027). `max_cache_age` governs only
whether a refresh is *attempted*, never whether cached content may be *served* — a
source that is past its policy **and** unreachable falls back to exactly the same
cache it would have used before any policy existed, and reports its staleness.
Treating an over-age cache as unusable would turn a performance optimization into
an availability cliff, silently stripping all cross-repo context from a developer
working offline. Configuring a freshness policy must never leave a project with
less available knowledge than it had before.

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
  "revision": "<revision>",
  "synced_at": "<ISO8601-timestamp>",
  "item_count": <N>,
  "items": [
    {"path": "<relative-path>", "sha256": "<hex>"},
    ...
  ]
}
```

`revision` is `null` when the source pins none. It is written for diagnosability
only — nothing reads it to make a decision, because the slug already guarantees
that two revisions never share a directory. A manifest written by 1.3.0 has no
`revision` field at all; readers treat absent as `null`, and no migration or
re-sync is needed.

Writing the manifest last signals cache integrity — an absent manifest means the
sync was interrupted. Its **mtime** therefore marks the instant the cache became
valid, which is what the freshness gate in step 4a relies on.

### 7. Detect conflicts

After indexing all sources, compare relative paths across all `fresh`, `cached`,
and `current` sources.

A shared path is a conflict **only when the two sources' repository identities
differ** (FR-026). Derive each identity with the Repository Identity algorithm in
§ Algorithm Reference above.

- **Different identity, same path** → conflict. Two teams disagree about the same
  filename, which is exactly what the user needs to know.
  - Record a `KnowledgeConflict`: `{path, sources: [label-a, label-b]}`
  - Both items are included in the index (no silent winner)
  - Emit `⚠️ CONFLICT` in the index and in the per-source status line
- **Same identity, same path** → **not** a conflict, and nothing is emitted. Two
  revisions of one repository are the same body of knowledge seen at two points
  in time, not a disagreement. Once revision pinning exists, identical paths
  across them are the normal case; reporting them would bury real conflicts in
  noise.

Identity ignores the access protocol, so a team where one developer configures
HTTPS and another SSH does not see every shared file reported as conflicting.

### 8. Write knowledge-index.md

Assemble `knowledge-index.md` using the format defined in the Algorithm Reference above.

Write to `.specify/extensions/knowledge/knowledge-index.md`.

Include a conflict section footer if any conflicts were detected.

### 8a. Prune orphaned caches

After the per-source loop, delete every cache directory that belongs to no
configured source (FR-032):

```text
expected = { slug(s) : s ∈ sources }        # ALL sources — enabled AND disabled
actual   = { directory names under cache/ }
prune      actual − expected
```

**Computing `expected` over disabled sources too is essential.** Restricting it to
enabled sources would delete exactly the caches FR-004 promises to keep, and turn
`--disable` into a slow `remove`.

This exists because a **revision change** strands a directory. FR-003 purges the
cache when a source is removed, but editing `revision` in place gives the source a
new slug, and nothing would ever read or delete the old one. Over a few revision
bumps a project would accumulate dead trees — the same outcome FR-003 was written
to prevent.

Report each removal on its own line:

```
🧹 Pruned orphaned cache abc123def456/ (no configured source resolves to it)
```

### 9. Print summary

For each source, print one status line:

```
  payment-service    ✅ fresh    12 items  (synced 2026-06-11T14:00:00Z)
  identity-service   ✅ fresh    8 items   (synced 2026-06-11T14:00:00Z)
```

Skipped for freshness — reported **distinctly** from `fresh`, so the user can see
that no network access occurred (FR-019):

```
  payments-v2        ⏭️  current   12 items  (cached 12m ago; policy 4h — no network)
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
- ≥ 1 source returned status `current` — skipped for freshness (FR-020), OR
- All sources are `cached` but ≥ 1 has a usable cache (i.e., `knowledge-index.md` exists), OR
- Mix of `cached` + `unreachable`, ≥ 1 source has a usable cache.

> **A `current` source counts as usable knowledge.** Suppressing the block because
> a cache was *too fresh to need refetching* would strip cross-repo context from
> the agent for precisely the wrong reason. The emission contract keys off whether
> any source has usable content, and a cache that is fresh by policy qualifies.

**Do NOT emit the block when** any of:
- `suppress_context_output = true` (flag `--no-context-output` was passed), OR
- An early-exit error was printed in step 1 (config absent, invalid YAML, unknown schema_version, missing sources key) — there is no `knowledge-index.md` to point to on these paths, OR
- **No enabled sources remain** — step 1a already deleted the index and reported the project as unconfigured (FR-031), OR
- All sources are `unreachable` AND no prior `knowledge-index.md` exists — instead print the soft warning below.

**Soft warning (all unreachable + no cache, FR-013a)**:

```
⚠️  No knowledge-index.md found yet. Run __SPECKIT_COMMAND_KNOWLEDGE_SYNC__ once when sources are reachable.
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

## --force flag

When `--force` is present in `$ARGUMENTS`, the Cache Freshness Gate is bypassed:
every enabled source is fetched regardless of how recently its cache was written
(FR-021). Nothing else changes — status values, the summary, and the Context
Output block behave exactly as they would without a freshness policy configured.

Parsed with the same `$ARGUMENTS` token scan as `--verbose`, and composes
orthogonally with both `--verbose` and `--no-context-output`.

**`--force` is unreachable from an automatic trigger.** The four `hooks.*` entries
in `extension.yml` declare no arguments, so a hook-driven sync cannot pass it —
the freshness policy always applies to automatic runs (FR-022). This is enforced
by construction rather than by a runtime check, the same mechanism that keeps
`--no-context-output` hook-unreachable (spec 003, FR-016). **Adding an argument to
a hook entry would break this**; `extension.yml` carries a comment saying so.

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
| `sources` absent, null, or `[]` | Empty-configuration path; index deleted | 0 |
| No enabled sources remain | Empty-configuration path; index deleted; no context block | 0 |
| A source fails a field validation rule | That source skipped; others continue | 0 |
| Two sources share a label | Both skipped; others continue | 0 |
| `sources` count > 10 | Warning + continue | 0 |
| Cache fresh by policy | `current`; no network access | 0 |
| Declared revision unresolvable on the remote | `cached` or `unreachable` | 0 |
| Abbreviated SHA pinned | `unreachable` with a message naming the cause | 0 |
| Git timeout on cold sync | `cached` or `unreachable` | 0 |
| Git timeout on warm sync | `cached` or `unreachable` | 0 |
| Over-age cache, source unreachable | `cached`, content still served | 0 |
| Manifest corrupted | Discard + retry or `unreachable` | 0 |
| Conflict between differing repository identities | `⚠️ CONFLICT` in index | 0 |
| Same path across two revisions of one repository | Not a conflict; nothing emitted | 0 |
| Orphaned cache directory found | Pruned, one line reported | 0 |
| All sources unreachable, no prior index | Soft warning, no context block | 0 |
| `--force` flag present | Freshness gate bypassed | 0 |
| `--no-context-output` flag present | Context block suppressed | 0 |

---

## Side effects

- Creates `cache/<slug>/` directories with sparse-checkout git state
- Writes `cache/<slug>/.manifest.json` per source
- **Deletes** cache directories that belong to no configured source (step 8a)
- Writes/updates `knowledge-index.md`, or **deletes** it when no enabled sources remain
- Does **not** modify `knowledge-config.yml`
- Does **not** modify `.specify/extensions.yml`
