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

### Corpus Measurement

Every indexed `.md` file carries a byte size, summed per source and project-wide.
Both numbers are needed even when no budget is configured, because the advisory
warning in step 9a reports them.

```bash
size=$(wc -c < "$file")
```

**Use `wc -c`, and read via redirection.** `wc -c < file` emits the count alone;
`wc -c file` appends the filename and pads differently on GNU than on BSD.

**`du` and `stat` are forbidden here**, for the same reason `date` was rejected in
favour of `find -mmin` for the freshness gate:

- `du` reports **disk blocks**, not bytes, and its default unit is 1 KiB on GNU
  versus 512 B on BSD. The same corpus would measure differently on two machines.
- `stat` needs `-c%s` on GNU and `-f%z` on BSD — mutually exclusive spellings.

Either one would break FR-007: two developers with identical configuration would
select different subsets, and the index would stop being explainable by the
configuration alone.

Size is measured over **the file content the agent is instructed to read**, never
over `knowledge-index.md` itself (FR-010). The index is a small fraction of what
its own instruction pulls in.

### Context Budget Allocation

Applies when `max_items` or `max_bytes` is in effect. Runs entirely on already
cached content — it never influences what is fetched (FR-012a).

**Effective limit** for one source, per dimension, is the **lower** of:

1. its own declared ceiling, where set, and
2. its share of the project-wide ceiling.

Taking the source's own value in preference to its share would let the total
exceed the project ceiling — with 120 items across three sources, a source
declaring 60 against a 40 share would push the total to 140. A per-source ceiling
above the project ceiling is clamped down to it and the clamp reported (FR-003a);
it never costs the source its place.

> This is a **sub-ceiling**, not an override. `max_cache_age` occupies the same
> two positions in the configuration file and behaves the opposite way — its
> per-source value *replaces* the project value. Do not carry that reading over.

**Share** is computed by progressive fill, run **independently on each
dimension**. `B` = the project ceiling for that dimension, `S` = the enabled
sources holding at least one item:

```text
1. share = floor(B / |S|)
2. EVERY source whose total need <= share is satisfied in full:
   subtract each one's need from B, drop them from S, restart at 1.
3. When a pass satisfies nobody, every source left in S receives `share`.
4. Distribute the remainder (B - share * |S|) one unit each,
   in ascending LABEL order.
```

**Step 2 is what makes this a fair share rather than a flat division.** Releasing
capacity a small source cannot use back to the others is what fills the ceiling.
With 120 items across four sources needing 312 / 55 / 88 / 12, a flat
`floor(120/4)` injects only 30 + 30 + 30 + 12 = 102 and strands 18. Progressive
fill gives 36 + 36 + 36 + 12 = 120. **An implementation that stops after one pass
satisfies neither FR-006 nor FR-007a, and the shortfall is invisible unless the
injected total is compared against the ceiling.**

Terminates in at most `|S|` passes — each pass either removes a source or exits.
Labels are unique by construction (FR-028), so step 4's tiebreak is never
ambiguous. With no project ceiling on a dimension, every share on that dimension
is unbounded and only the source's own value binds.

No configuration value influences **which** items are chosen (FR-007a) — only how
many. The rule is fixed and owned by this extension so that a user can reproduce
their own index on paper (FR-007b).

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
<!-- knowledge-index-meta: schema_version=1.0 generated_at=<ISO8601> sources=<N> items=<N>
     withheld_items=<N> withheld_bytes=<N> limit_items=<N> limit_bytes=<N> -->

## Shared Knowledge Index

> Generated: <ISO8601> | Sources: <N> | Items: <N>
> ⚠️ Partial: <N> items (<size>) withheld by the configured context budget
> (<limit_items> items / <limit_bytes>). Search the corpus to reach them.

### Source: <label> (<url>)
**Status**: <fresh|cached|unreachable> | **Synced**: <ISO8601> | **Items**: <N> | **Path filter**: <path_filter or "all .md files">

- [<relative-path>](cache/<slug>/<relative-path>)
- [<relative-path>](cache/<slug>/<relative-path>)
...

---
*⚠️ Conflicts: <N> — `<path>` present in <source-a> AND <source-b>. Both included.*
```

The machine-readable HTML comment on line 1 allows scripts to detect the index without reading the full file.

The four `withheld_*` / `limit_*` fields and the `⚠️ Partial` line are **omitted
entirely** when the budget withheld nothing — including when no budget is
configured. A non-binding budget therefore leaves the index indistinguishable from
an unbudgeted one, apart from the generation timestamp (FR-016).

**No withheld path is ever named here** (FR-014). This is the one document the
agent is instructed to read in full; naming the excluded files would invite it to
open exactly what the budget removed.

`generated_at` and the `Generated:` line change on every run, and the `cache/<slug>/`
link targets are derived from each machine's own source locations. **Two indexes are
therefore never byte-equal even when they select identical items** — any check for
sameness must compare the item list, not the file.

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
| `max_items` (top level and per source) | Optional. Matches `^[0-9]+$` and is `>= 1`. |
| `max_bytes` (top level and per source) | Optional. Matches `^[0-9]+(kb\|mb)$` — `512kb`, `2mb`. |

### Why a budget ceiling of `0` is rejected

`max_items: 0` and `max_bytes: 0kb` are refused by the rules above rather than
honoured. A literal reading would withhold the entire corpus while reporting
success — the silent-truncation failure this budget exists to prevent. Rejecting
it routes the mistake through the loud paths instead: per source it skips only
that source and names the field, and project-wide it is reported and treated as
unconfigured.

Neither `max_items` nor `max_bytes` is ever handed to `git`, so the leading-`-`
ban below does not apply to them. Their anchored patterns reject an option-shaped
value regardless.

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

**Project-wide validation** — the top-level `max_cache_age`, `max_items`, and
`max_bytes` are validated by the same rules, but a failure is handled
**differently on purpose**:

- A malformed **per-source** value skips only its own source (above). Its blast
  radius is naturally bounded.
- A malformed **project-wide** value has no such boundary. Treating it as a
  binding ceiling would strip every source's knowledge on the strength of one
  typo, so it is **reported and treated as though it were not configured**
  (FR-021). Per-source ceilings still apply.

```
⚠️  Ignoring project-wide `max_items` value "banana" (must be a whole number ≥ 1).
    Proceeding with no project-wide item ceiling; per-source ceilings still apply.
```

Failing **open** here is the same reasoning that keeps an over-age cache readable
when its source is unreachable: a configuration mistake must never leave the
project with less knowledge than it had before the setting existed. Exit code
stays 0 (FR-022).

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

### 7a. Apply the context budget

Runs **after** conflict detection, because a conflict pair must be known before
any of its members can be selected, and **before** the index is written, because
the index is what the budget bounds.

It runs **after step 6 by requirement**: `.manifest.json` is already on disk
holding the **complete** item list for its source. Nothing here removes a cached
file or shortens a manifest (FR-012a). That separation is what makes three
requirements satisfiable at once — the cache stays whole, `search` still reaches
every item (FR-017, FR-035), and the verbose withheld list is simply
*manifest items − indexed items* (FR-034) with no third record to maintain.

Skip this step entirely when neither `max_items` nor `max_bytes` is in effect.
With no budget the index is exactly what it was before this feature existed
(FR-004), and nothing below runs.

The budget applies to the assembled corpus **regardless of how each source's
content was obtained** — freshly fetched, served from a policy-fresh cache
(`current`), or served from a stale cache after an unreachable source (FR-011).
The agent reads one index in all three cases.

**1 — Resolve effective limits.** Per source, per dimension, using § Context
Budget Allocation. Report any per-source ceiling clamped down to the project
ceiling (FR-003a).

**2 — Select per source.** Take the longest **ascending relative-path** prefix of
the source's items that fits within **both** effective limits (FR-006).

> Path order, not smallest-first. Smallest-first packs more items into the same
> byte ceiling, but adding one large file would silently change which unrelated
> small files survive — no user could predict their own corpus, defeating
> FR-007b. Path order confines the effect of any change to files after it.

**3 — Reconcile conflicts (FR-033).** For each path reported as a conflict in
step 7:

- If **every** version was selected, keep them all.
- If **any** version was not selected, **withdraw all of them**. A budget that
  keeps one team's version of a contested contract and hides the other
  manufactures precisely the silent winner conflict reporting exists to prevent.
- **Do not reallocate the freed capacity.** Reuse would make the result depend on
  how many passes the selection makes, breaking the on-paper predictability
  FR-007b requires. The slack is wasted deliberately.
- Report the withdrawal as **one** conflict event, not as unrelated per-source
  exclusions. A source left holding nothing by a withdrawal is named the same way
  a source that received no allocation is named — the user cannot infer the
  mechanism that emptied it.

**4 — Assemble the withholding report** for step 9: per-source injected-vs-total
counts and sizes with the limit applied, oversized items named individually,
starved sources named, conflict withdrawals named.

**Oversized items are removed before allocation** (FR-009). An item larger than
the effective size ceiling on its own can never be included; it is excluded, named
with its size, and **neither consumes nor blocks** the budget available to
everything else.

### 8. Write knowledge-index.md

Assemble `knowledge-index.md` using the format defined in the Algorithm Reference above.

Write to `.specify/extensions/knowledge/knowledge-index.md`.

Include a conflict section footer if any conflicts were detected.

When step 7a withheld anything, the index references **only the selected subset**
and carries the withholding fields and the `⚠️ Partial` line from the format above.
When nothing was withheld — including when no budget is configured — those fields
and that line are **omitted entirely**, leaving the index indistinguishable from
the one produced before this feature existed, apart from the generation timestamp
every sync writes (FR-016).

**No withheld path is ever named in the index** (FR-014). This is the one document
the agent is instructed to read in full; listing the excluded files here would
invite it to open exactly what the budget removed. The verbose output carries the
identities instead.

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

#### Withholding report (only when the budget withheld something)

Print a second line under each affected source giving injected-of-total counts and
sizes and **the limit that produced them** (FR-013, FR-018). A reported reduction
must never be unexplained.

```
  payment-service    ✅ fresh    35 items  (synced 2026-09-04T14:00:00Z)
                     ✂️  budget: 35 of 312 items (115kb of 3.4mb) — limit 36 items (equal share of 120)
  shared-contracts   ⏭️  current  12 items  (cached 12m ago; policy 4h — no network)
                     ✓  budget: 12 of 12 items (40kb) — within its 30-item share; 18 released
```

Then the individually named exceptions:

```
⚠️  Withheld: payment-service › specs/architecture/full-topology.md (2.4mb) exceeds the
    1mb size ceiling on its own; excluded without consuming the budget.
⚠️  Conflict withdrawn: specs/events/payment-completed.md — present in payment-service and
    adr-repo, whose repository identities differ; not every version fits, so none was
    included. The freed capacity is not reallocated.
⚠️  design-notes contributed nothing — the item ceiling (2) is below the number of
    sources with items (3), so some source must receive nothing. Chosen by the same
    rule: the remainder went to the lowest labels in order.
```

The summary line then carries the totals:

```
✅ Knowledge index updated: 119 items from 4 sources (348 withheld, 3.5mb).
```

**A source that indexes nothing for its own reasons — empty, or a path filter
matching nothing — MUST NOT be reported as withheld by the budget at all.** The
starvation line above is authorised only when the item ceiling is genuinely below
the number of sources holding items (FR-008a).

When the budget withheld nothing, none of these lines appear and the summary keeps
its original form (FR-016).

#### 9a. Advisory threshold (only when NO budget is configured)

When neither `max_items` nor `max_bytes` is in effect and the corpus exceeds either
built-in threshold, emit one informational line (FR-032):

| Dimension | Threshold |
|-----------|-----------|
| Items | **200** |
| Total size | **2 mb** |

```
⚠️  This project's knowledge corpus is 340 items / 2.7mb, past the advisory
    threshold of 200 items / 2mb. An agent instructed to read all of it may
    exhaust its context. Consider setting `max_items` or `max_bytes` in
    knowledge-config.yml.
```

Name **both** the measured value and the threshold, for whichever dimension
triggered it, so the user can judge the recommendation against their own corpus
rather than taking it on trust (FR-032a).

There is one threshold per dimension because the two ceilings are independent — a
corpus can hit either wall alone, and a single-dimension warning would stay silent
for the other.

**It alters nothing.** No item is withheld, the index is byte-for-byte what it
would have been without the warning, and the command still exits 0. This has the
same standing as the existing "more than ten sources" warning in step 2.

The two figures are a **calibration, not a contract**: markdown of the kind this
extension indexes runs roughly 4–8 kb per file, so 200 items ≈ 1.2 mb and the two
thresholds describe about the same wall from two directions. They may be re-tuned
in a later release without a schema change.

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

**When the context budget withheld anything**, insert one additional numbered line
immediately after line 4, before the closing rule (FR-015):

```
5. This corpus is PARTIAL — a context budget withheld some items. Do not
   present it as the project's complete knowledge. Say so if asked, and
   note that the full corpus is reachable with
   __SPECKIT_COMMAND_KNOWLEDGE_SEARCH__.
```

The line is **absent** when nothing was withheld, so an unbudgeted or non-binding
project sees the block exactly as before. Without it the agent would read a
deliberately trimmed corpus and present it as everything the project knows — the
silent failure this feature exists to prevent.

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

When the context budget withheld anything from that source, follow it with the
**withheld identities** (FR-034). Derive them as *manifest items − indexed items* —
both already on disk, so no third record is maintained:

```
--- VERBOSE: items withheld from payment-service ---
specs/architecture/full-topology.md
specs/events/refund-issued.md
[... 275 more]
--- END VERBOSE ---
```

This list is deliberately **absent from the default output**: sync runs at up to
four automatic points per feature cycle, and a list of that size would bury the
summary it exists to support. It is **also absent from the index**, for a different
reason — the index is the one document the agent reads in full, and naming the
excluded files there would invite it to open them.

### No flag raises or bypasses the budget

`--force` overrides the **cache freshness policy** only. There is deliberately no
flag that raises, relaxes, or disables a context ceiling (FR-012): the automatic
sync points are exactly where a context overflow does the most damage, so an escape
hatch reachable from them would defeat the guarantee.

> Note for future changes: Constitution Quality Gate §10 keeps `--force`
> hook-unreachable by asserting that no hook declares arguments. That gate would
> **not** protect a budget-bypass flag invoked manually. Do not add one.

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
| `max_items` / `max_bytes` malformed, per source | That source skipped, field and value named | 0 |
| `max_items` / `max_bytes` malformed, project-wide | Reported and ignored; per-source ceilings still apply | 0 |
| A budget ceiling of `0` | Treated as malformed, as above | 0 |
| Per-source ceiling exceeds the project ceiling | Clamped to the project ceiling, clamp reported; source still contributes | 0 |
| Single item exceeds the size ceiling alone | Excluded and named with its size; consumes no budget | 0 |
| Item ceiling below the number of sources with items | Some sources get nothing; each one named | 0 |
| Conflict pair cannot fit in full | All versions withdrawn, reported once; capacity not reused | 0 |
| Budget configured, corpus fits inside it | Nothing withheld, nothing reported | 0 |
| No budget configured, corpus past the advisory threshold | Warning only; index unaffected | 0 |

---

## Side effects

- Creates `cache/<slug>/` directories with sparse-checkout git state
- Writes `cache/<slug>/.manifest.json` per source
- **Deletes** cache directories that belong to no configured source (step 8a)
- Writes/updates `knowledge-index.md`, or **deletes** it when no enabled sources remain
- Does **not** modify `knowledge-config.yml`
- Does **not** modify `.specify/extensions.yml`
