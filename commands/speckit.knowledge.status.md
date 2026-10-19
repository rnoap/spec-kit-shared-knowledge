---
description: "Show reachability, last-sync timestamp, item count, and cache age per source"
---

## speckit.knowledge.status

**Purpose**: Display current state of all configured knowledge sources — reachability, last-sync timestamp, item count, and cache age.

**Arguments**: `$ARGUMENTS` — optional flags only:
- `--verbose` — list all cached file paths per source

---

## Algorithm Reference

Uses the same **Source Slug Generation**, **Repository Identity**, **Bounded Network Call**, and **Cache Integrity Check** algorithms defined in `speckit.knowledge.sync.md` § Algorithm Reference.

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

Apply every rule in the agent's own reasoning, never by sending an unchecked value
to a shell. After the schema gate, check the character rule first, then the other
syntax rules, then local existence or any other use. Check `url`, then each
`path_filter` entry, before the remaining source fields. No value of a source
that is not accepted reaches a shell, not even for its slug or a message
(007 FR-001, FR-002).

**Schema gate (007 FR-014):** before using any source, accept only configuration
schema `"1.1"`. For `"1.0"`, print as agent output:

```text
Error: knowledge-config.yml schema_version "1.0" requires migration to "1.1". Back up the file, review the README migration notes, then change only schema_version. No sources or caches were used or changed.
```

For a missing or unknown version, print the following, substituting `<missing>`
when absent and escaping the value under the message rule below:

```text
Error: Unrecognized knowledge-config.yml schema_version "<value>". Expected "1.1". No sources or caches were used or changed.
```

Both paths exit 0 before computing slugs, reading source manifests, checking
reachability, pruning, or writing configuration or caches. A hook finishes and
its parent command continues. Never migrate or downgrade automatically. configure
uses `"1.1"` when creating a missing file and preserves it on edits. This gate
does not change the separate manifest or index schema versions.

`sources:` written with no value parses as **null**, not as an empty list. Treat
absent, null, and `[]` identically: the project has no configured sources.

| Field | Rule |
|-------|------|
| `schema_version` | Required. Exactly `"1.1"`. Check before using any source; missing, `"1.0"` and unknown versions stop with the schema diagnostic, exit 0 and no configuration or cache changes (007 FR-014). |
| `max_cache_age` (top level and per source) | Optional. Matches `^[0-9]+[mhd]$` — `30m`, `4h`, `7d`. |
| `url` | Required, non-empty. Either a local path (`/`, `./`, `../`, `~/`) that exists and contains `.git`, or a remote URL matching `^(https?://\|ssh://\|git\+ssh://\|git@)`. **Must not begin with `-`.** **Only ASCII letters, digits and `.` `_` `~` `:` `/` `@` `%` `+` `-`**; a local path may also contain spaces, but **no space followed by `-`** (007 FR-001). |
| `label` | Optional in the file, derived when absent. Non-empty, no whitespace, **unique across `sources`** (FR-028). |
| `revision` | Optional. Non-empty, matching `^[A-Za-z0-9._/-]+$`. **Must not begin with `-`**, must not contain `..`, must not end with `.lock`. |
| `path_filter` | Optional. A string or a list of strings. Each entry non-empty, **no leading `/` or `~`**, **no `..`**, **must not begin with `-`**, and **only ASCII letters, digits and `.` `_` `~` `:` `/` `@` `%` `+` `-`** (007 FR-001). |
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

### Two layers against option injection and shell syntax

1. **Refuse** with both the leading-`-` rule and the character rule. A local path
  is recognized by its prefix alone: `/`, `./`, `../` or `~/`. Only that form
  admits spaces, never a space followed by `-`. A `path_filter` cannot start
  with `~`. Report the first disallowed character from left to right.
2. **Neutralize** with `--` before every configuration-derived git operand
  (FR-034) and single quotes around every configuration placeholder in a shell
  command (007 FR-006), including commands the agent composes itself. Copy the
  value literally, replacing each `'` with `'\''`. For `<expanded-path>`,
  expand `~/` to the actual home directory before quoting. `$HOME` and `~` do
  not expand inside single quotes. `with_timeout` forwards only through `"$@"`.

Fetched file names enter commands only through the double-quoted shell variable
`"$file"`, never pasted into command text. Read through redirection:
`wc -c < "$file"`, `sha256sum < "$file"`, or `shasum -a 256 < "$file"` on macOS.
Labels and messages never reach a shell.

### Values in messages (007 FR-005)

Every message quoting a configuration value, source label or fetched file name
is agent output, never `echo` or `printf`. Escape line feed as `\n`, tab as `\t`,
carriage return as `\r`, escape U+001B as `\e`, and other characters below U+0020
or from U+007F to U+009F as `\xHH`. Show backslash as `\\` and a double quote
inside a quoted value as `\"`. Leave other characters unchanged.

### On failure

A value that violates its rule skips **only its own source** (FR-030):

```
⚠️  payments-v2: skipped — invalid `revision` value "-u" (must not begin with "-")
⚠️  source 3: skipped — invalid `url` value "https://example.com/$(touch /tmp/pwned)" ("$" is not allowed)
```

Every other source is processed normally and the command exits **0** (FR-023).
Always name the field and the offending value, so the user can fix it without
guessing. Emit only the first failure per source, on one escaped line. Use its
label; without one, derive a label only from an accepted URL, otherwise use
`source <n>`, its 1-based position. A character-rule failure names `"<c>" is not
allowed`; a local space followed by `-` names `a space followed by "-" is not
allowed`; a leading `~` filter names `must not begin with "~"`. A URL matching no
accepted form names `not a Git URL, nor a local path starting /, ./, ../ or ~/`.

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
- Before inspecting sources, apply the file-level schema gate in § Configuration
  Validation Rules (007 FR-014). Only `"1.1"` proceeds. For a missing, `"1.0"` or
  unknown version, emit its escaped schema diagnostic and exit 0 without using
  source values, computing slugs, reading manifests, checking reachability, or
  writing configuration or caches. Never migrate automatically.
- If `sources` is absent, null, or `[]`: print the same not-configured message and
  exit 0. Installing the extension scaffolds the file with `sources:` empty, so
  this is how a freshly installed project reads.

Before step 2, validate **every source, including disabled sources**, under
§ Configuration Validation Rules (007 FR-002). A source that is not accepted gets
no slug, no manifest read and no reachability check. Print its first refusal line
as escaped agent output before `📊 Shared Knowledge Status`, and retain it for an
`⚠️ invalid` row. Every other source continues normally (007 FR-004, FR-005).

### 2. Read manifests

For each accepted source (enabled or disabled), compute the slug using its `url`
and `revision`. Before using it, confirm in the agent's own reasoning that it is
exactly 12 lowercase hex characters (`^[0-9a-f]{12}$`). If it has any other form,
show `not synced`; do not construct a cache path or read a manifest through it
(007 FR-006). Only a valid slug may resolve `cache/<slug>/.manifest.json`:
- If manifest exists and valid: record `synced_at`, `item_count`, derived cache age
- If manifest absent: status = `not synced`
- If manifest invalid JSON: status = `corrupted`

Cache age is computed from `synced_at` to now:
- `< 60 min`: display as `N min`
- `1h–48h`: display as `Nh`
- `> 48h`: display as `Nd`

### 3. Check reachability

**Detect source type for accepted sources only**: `url` starts with `/`, `~/`,
`./` or `../` → local path; otherwise remote URL.

**Remote URL** (`with_timeout` is the Bounded Network Call function — define it first):
```bash
with_timeout 5 git ls-remote --exit-code -- '<url>' HEAD
```
- Exit 0 → `✅ reachable`
- Non-zero / timeout → `❌ timeout`

**Local path** (expand `~/` to the actual home directory before quoting;
`<expanded-path>` contains that directory, not a literal `$HOME` or `~`):
```bash
[ -d '<expanded-path>/.git' ] || git -C '<expanded-path>' rev-parse --git-dir 2>/dev/null
```
- Directory exists and is a git repo → `✅ reachable (local)`
- Directory absent or not a git repo → `❌ not found`

Invalid sources: show `⚠️ invalid` without a reachability check, even when
`enabled: false`. Only accepted disabled sources show `— disabled`.

### 4. Print status table

```
⚠️  notes: skipped — invalid `path_filter` value "docs/*.md" ("*" is not allowed)
📊 Shared Knowledge Status
   Config: .specify/extensions/knowledge/knowledge-config.yml
   Index:  .specify/extensions/knowledge/knowledge-index.md

┌──────────────────────┬──────────────┬──────────────┬──────────┬────────────┬───────────────────┬────────────┐
│ Source               │ Reachability │ Revision     │ Status   │ Items      │ Budget            │ Cache Age  │
├──────────────────────┼──────────────┼──────────────┼──────────┼────────────┼───────────────────┼────────────┤
│ payment-service      │ ✅ reachable │ default      │ fresh    │ 36 of 312  │ 36 items (share)  │ 14 min     │
│ payments-v2          │ ✅ reachable │ v2.4.1       │ fresh    │ 36 of 55   │ 36 items (share)  │ 3d         │
│ identity-service     │ ✅ reachable │ main         │ fresh    │ 8 of 8     │ 30 items (share)  │ 14 min     │
│ shared-contracts     │ ❌ timeout   │ default      │ cached   │ 5 of 5     │ 40kb (per-source) │ 29h        │
│ notes                │ ⚠️ invalid   │ —            │ —        │ —          │ —                 │ —          │
│ legacy-service       │ — disabled  │ default      │ —        │ —          │ —                 │ —          │
└──────────────────────┴──────────────┴──────────────┴──────────┴────────────┴───────────────────┴────────────┘

Freshness policy: payments-v2 7d (per-source) · others 4h (project) · legacy-service none (24h default)
Context budget: 120 items / 1mb (project) · shared-contracts 40kb (per-source)
Total: 85 of 380 items from 4 sources (3 reachable, 1 cached, 1 disabled, 1 invalid)
```

`⚠️ invalid` takes precedence over `— disabled`. An invalid row shows its escaped
source name, `⚠️ invalid`, and `—` in every other cell; do not read its old cache
or include it in item totals, policy/budget details, or any other reachability
count. Always include the `invalid` count in the `Total` line, even when zero.
Escape labels and values in the table and diagnostics under § Values in messages
(007 FR-004, FR-005).

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

### 4a. Budget column

`Items` shows **indexed of total** — how many of the source's cached items the
index actually references. `Budget` names the limit that produced that number
(FR-018), by the same principle: a reported contribution must never be
unexplained.

| Value shown | Meaning |
|-------------|---------|
| `36 items (share)` | Bounded by its share of the project ceiling |
| `40kb (per-source)` | Bounded by its own declared ceiling |
| `— (no limit)` | No budget in effect for this source |
| `0 items (share)` | Contributed nothing — see the sync output for why |

Always print the **Context budget** line beneath the table naming the project
ceilings and any per-source ceilings, so the numbers in the column can be checked
against the configuration.

When no budget is configured anywhere, omit the `Budget` column and the
`Context budget` line entirely, and show `Items` as a plain count — the table is
then exactly what it was before this feature existed.

Indicate if `knowledge-index.md` is absent:
```
⚠️  knowledge-index.md not found — run __SPECKIT_COMMAND_KNOWLEDGE_SYNC__ to generate it.
```

### 5. --verbose flag

When `--verbose` is present, after each accepted source row that has a cache
resolved through a valid slug, print the list of cached `.md` file paths. Emit
the label and paths as agent output, never through a shell, escaping control
characters, backslashes and quoted double quotes under § Values in messages
(007 FR-005). Invalid sources have no verbose cache listing.

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
