# Data Model: Shell-Safe Configuration

**Feature**: [shell-safe-config.spec.md](shell-safe-config.spec.md) · **Plan**: [plan.md](plan.md) · **Research**: [research.md](research.md)

No data file changes shape. `knowledge-config.yml`, `.manifest.json` and `knowledge-index.md` keep their fields, and `schema_version` stays `"1.0"`, since no field, type or form changes (research § 12). What changes is which characters a source's values may hold, the route every value takes to a shell, what each command does with a source it refuses, and the slug that names each cache. Outside the runtime, the documentation, the CHANGELOG, the constitution and the agent guidance pointer move with them (§ 8).

```text
knowledge-config.yml (committed, shared; read by every command, and by sync before specify, clarify, plan, tasks)
└── Knowledge source (§ 1) ── checked by the agent before any other use, with no shell involved (§ 2)
      ├─ refused ──▶ Refusal (§ 3): one line of agent output; no slug, no shell; that sync prunes nothing
      └─ accepted ─▶ Shell-bound values (§ 4): single-quoted, `--` before every git operand
                       ├── url + revision ──▶ Source slug (§ 5) ──▶ cache/<slug>/
                       └── path_filter ─────▶ Indexable Items ──▶ Fetched item names (§ 6): read only as "$file"

Any value, label or file name a message quotes ──▶ Messages (§ 7): control characters escaped
```

## 1. Knowledge source

One entry under `sources:`. Two rules narrow. No field is added, removed or retyped.

| Field | Today | After | Req |
| --- | --- | --- | --- |
| `url` | Non-empty. A local path (`/`, `./`, `../`, `~`) that exists and contains `.git`, or a remote URL matching `^(https?://\|ssh://\|git\+ssh://\|git@)`. Must not begin with `-`. Any character passes. | The same, plus the character rule below. A local path starts with `/`, `./`, `../` or `~/`, and may also hold spaces, never one followed by `-`. | FR-001 |
| `path_filter`, each entry | Non-empty. No leading `/`, no `..`, must not begin with `-`. Any character passes. | The same, plus the character rule. No spaces, and must not begin with `~`. | FR-001 |
| `revision` | `^[A-Za-z0-9._/-]+$`. Must not begin with `-`, contain `..` or end with `.lock`. | Unchanged. Its pattern already admits nothing a shell reads as syntax. | — |
| `label` | Non-empty, no whitespace, unique. | Rule unchanged. Never handed to a shell; quoted in a message only in escaped form. | FR-005 |
| `enabled`, `max_cache_age`, `max_items`, `max_bytes` | Booleans and anchored patterns. | Unchanged. | — |

### Accepted characters

An allow-list: any character not in this table is refused, whatever it is. A deny-list would miss whatever nobody listed (research § 4).

| Characters | Needed for | Remote `url` | Local-path `url` | `path_filter` entry |
| --- | --- | --- | --- | --- |
| ASCII letters and digits | every form; `é` is refused | yes | yes | yes |
| `.` `_` | host names, `.git`, `./`, `../`, folder names | yes | yes | yes; `..` stays refused |
| `-` | names | yes, not first | yes, not first, not after a space | yes, not first |
| `/` | path separators | yes | yes | yes, not first |
| `~` | `~/` local paths, a server-side `~user` path | yes | yes | yes, not first |
| `:` | scheme, port, SCP-style `host:org/repo` | yes | yes | yes |
| `@` | the user in `git@` and `ssh://git@` | yes | yes | yes |
| `%` | percent-encoding, such as `%20` | yes | yes | yes |
| `+` | the `git+ssh://` scheme | yes | yes | yes |
| space | folder names on disk | no; write `%20` | yes | no; configure splits filters at spaces |

Every form SC-002 names is spelled within the list: `https://`, `ssh://`, `git+ssh://`, `git@`, and local paths starting with `/`, `~/`, `./` and `../`. Apart from the space, which only a local path admits and every command quotes (FR-006), none of these characters runs a command, redirects, globs, comments out the rest of a line or splits a value, even unquoted.

The rule concerns shell syntax, not trust. A well-formed value pointing somewhere hostile is accepted, and the README's review checklist still applies.

Each class SC-001 seeds needs a character outside the list, so it is refused wherever it appears. Seeded alone, the refusal names the character shown:

| Class | Needs | Refusal names |
| --- | --- | --- |
| command substitution | `$` `(` `)` | `$` |
| backticks | `` ` `` | `` ` `` |
| command separator | `;` | `;` |
| `&&` | `&` | `&` |
| pipe | `\|` | `\|` |
| redirection | `>` or `<` | `>` or `<` |
| single-quote break-out | `'` | `'` |
| line break | U+000A | `\n` (§ 7) |

### Values that stop being accepted

Each is skipped on every read until it is edited. Its cache stays (§ 3, § 5).

| Value | After | Why |
| --- | --- | --- |
| A wildcard `path_filter`, such as `docs/*.md` | refused | `path_filter` is documented as folder names. Quoted, `find` takes a pattern literally and indexes nothing. |
| A `path_filter` beginning with `~` | refused | Unquoted, it expands to the home directory and `find` indexes outside the cache. |
| A local path written `~user/…` | invalid: it matches no accepted form | It worked only because an unquoted shell expanded it. sync and status never treated it as local. |
| A local path holding a space followed by `-`, such as `kb - Copy` | refused | If a quote were missed, the piece after the space would read as an option. Rename the folder, or link to it under another name. |
| A remote `url` holding a space | refused | A remote address writes it `%20`. |
| A bracketed IPv6 host | refused | A host name works instead. |
| Any non-ASCII letter | refused | Letters means ASCII letters (spec Assumptions). |

### Local path or remote

The prefixes that make a `url` a local path:

| Where | Today | After |
| --- | --- | --- |
| § Configuration Validation Rules | `/`, `./`, `../`, `~` | `/`, `./`, `../`, `~/` |
| configure, type detection | `/`, `./`, `../`, `~` | `/`, `./`, `../`, `~/` |
| sync and status, type detection | `/`, `~/`, `./` | Unchanged. A `../` path still takes the remote route (Out of Scope). |

## 2. The check

The agent applies § 1 in its own reasoning, to every source, every time a command reads the file (research § 3). There is no validation snippet: running one would hand the unchecked value to a shell.

Order of use, per value (FR-002):

```text
read from knowledge-config.yml, or taken from configure's arguments
  1. the character rule (§ 1)                    agent only
  2. the field's other syntax rules              agent only: form, leading `-`, leading `/`, `..`, revision pattern
  3. first contact with a shell, quoted (§ 4)    configure's local-path check, status's reachability check,
                                                 the slug, every git call
```

A value that fails step 1 or 2 never reaches step 3.

**The first character that is not allowed** is, reading left to right, the first character refused at its position:

- a character outside the list;
- a space in a remote `url` or in a `path_filter` entry;
- a `-` that follows a space;
- a `~` that begins a `path_filter` entry.

A leading `-`, a leading `/` and `..` keep their own rules and messages.

**configure's arguments** (research § 13):

| Aspect | Today | After |
| --- | --- | --- |
| Splitting `$ARGUMENTS` | at whitespace | at whitespace outside matching `'…'` or `"…"`; a quoted span is one token, its quotes removed |
| First token | `url` or local path; `~` marks a local path | the same; `~/` marks a local path |
| Remaining tokens | path filters, `--revision <rev>`, `--verbose` | Unchanged. Each filter is checked by § 1 like a stored entry, so quoting a filter that holds a space does not make it valid. |

## 3. Refusal

The per-source outcome of a value that fails § 1: one line of the agent's own output, never `echo` or `printf` (research § 8).

| Field | Value | Req |
| --- | --- | --- |
| source | its label, configured or derived as today, escaped (§ 7) | FR-004 |
| field | `url` or `path_filter` | FR-003, FR-004 |
| character | the first character that is not allowed (§ 2), escaped (§ 7) | FR-003 to FR-005 |

A source with several refused values gets one line, naming the first in the order checked: `url`, then each `path_filter` entry. Wording is in [contracts/commands.md](contracts/commands.md).

### Source outcome

A value that fails any other rule skips its source as today, with today's message naming the field and the value, escaped (§ 7). Either way only that source is skipped, and every command exits 0.

```text
READ ─▶ CHECK (§ 2) ─┬─ every rule passes ─────────────▶ ACCEPTED ─▶ slug, git, cache (§ 4, § 5)
                     ├─ url or path_filter fails § 1 ──▶ REFUSED ─┐
                     └─ any other rule fails ──────────▶ INVALID ─┴─▶ skipped on every read until edited;
                                                                     its cache stays
```

Editing the value, or removing the source, is the only way out. `path_filter` is not a slug input, so a corrected filter finds its old cache and the next sync updates it in place.

No command computes a refused source's slug (research § 5):

| Command | A refused source |
| --- | --- |
| configure | Nothing is written. The line names the field and the character. |
| sync, by hand or from a hook | Skipped with one line; every other source syncs. A hook-driven run finishes and the spec-kit command it precedes continues. Step 8a prunes nothing that run (§ 5). |
| status | The refusal line, and an `invalid` row: no manifest read, no reachability check. |
| remove, as the target | Its entry is deleted or its `enabled` toggled, and nothing from the value runs. Its cache is left for the next prune. |
| remove, another source | Reported; the requested operation proceeds, as today. |
| search | Skipped: its manifest is not read. |

### Status row

`invalid` is a new Reachability value. It outranks `— disabled`, because status computes a disabled source's slug and reads its manifest too.

| Reachability | When | Slug and manifest | Check run |
| --- | --- | --- | --- |
| `invalid` (new) | a value is refused, or fails another rule in § Configuration Validation Rules | none | none |
| `— disabled` | `enabled: false` | computed, read | none |
| `✅ reachable`, `❌ timeout` | enabled remote `url` | computed, read | `git ls-remote`, quoted |
| `✅ reachable (local)`, `❌ not found` | enabled local path | computed, read | directory and `rev-parse` test, quoted |

## 4. Shell-bound values

Everything a command hands to a shell. Each arrives as one literal argument that the shell neither expands nor splits (FR-006).

| Value | Comes from | Checked by | Carried as | Reaches |
| --- | --- | --- | --- | --- |
| `url` | configuration | § 1, its form, no leading `-` | single-quoted placeholder | the slug procedure, clone Tiers 1 and 2, status's `git ls-remote` |
| local path | a local-path `url`, `~/` replaced by the home directory | § 1, on the value as configured | single-quoted placeholder | the local clone, configure's local-path check, status's local check, and any symlink resolution for Repository Identity done in a shell |
| `revision` | configuration | its pattern; no leading `-`, `..` or trailing `.lock` | single-quoted placeholder, empty when none is pinned | the slug procedure, `--branch`, `git fetch`, `git update-ref` |
| `path_filter` entry | configuration | § 1; no leading `/`, `..` or leading `-` | single-quoted placeholder; each `find` starting point begins with `./` | sparse-checkout, the warm-path test, Indexable Items |
| item name | the source repository | nothing can check it (§ 6) | the shell variable `"$file"`, never pasted | Corpus Measurement, the Cache Integrity Check, step 5 |
| slug | computed (§ 5) | `^[0-9a-f]{12}$` before any deletion | `<slug>`, unquoted | every cache path |
| freshness minutes | `max_cache_age`, converted by the agent | `^[0-9]+[mhd]$` | digits | `find -mmin` |
| `label` | configuration | its rule | — | never; messages only (§ 7) |

The quoting rule (research § 1):

```text
as configured             written into the bash block
specs/                    'specs/'
~/My Repos/kb             '/home/dev/My Repos/kb'      the agent expands ~/ itself: single quotes stop the shell doing it
it's  (check bypassed)    'it'\''s'                    each ' in a value becomes '\''
```

- Inside single quotes the shell expands nothing and splits nothing, in sh, bash and zsh alike. Double quotes are not enough: `$(…)` and backticks still run inside them, which is today's bug. With the check bypassed, the eight SC-001 values therefore run nothing (SC-004), and a local path with a space stays one argument (SC-005).
- § 1 refuses `'`, so on the normal path `'\''` fires only in the home-directory part of an expanded local path, which no rule checks.
- `--` still precedes every git operand. `find` takes no `--`, so each starting point begins with `./`.
- `with_timeout` hands its arguments on as `"$@"`, and its perl fallback execs them without a shell, so nothing re-reads a value.

### Placeholders

One vocabulary, shared by three files: the command snippets, static check 12, and `.github/scripts/test-sync-git.sh`, whose `render()` matches the placeholder text letter for letter. A renamed placeholder changes all three in the same commit (plan).

| Placeholder | Static check 12 |
| --- | --- |
| `<url>` | must sit inside single quotes |
| `<expanded-path>` | must sit inside single quotes |
| `<revision>`, also inside `[--branch <revision>]` | must sit inside single quotes |
| `<pattern1> [<pattern2> ...]`, `<path_filter>` | must sit inside single quotes |
| `<dir1> [<dir2> ...]` | must sit inside single quotes |
| `<slug>` | exempt: twelve hex characters the extension computed |

Check 12 reads every bash block in `commands/*.md`, skips comment lines, deletes single-quoted segments, and fails on any `<name>` left other than `<slug>`, reporting `file:line` (FR-007, SC-006, research § 10). A placeholder added later is checked without being listed. `render()` fills placeholders by literal substitution under the quoting rule; `sed` would read `|`, `&`, `\` and line breaks in a value as syntax (research § 11).

## 5. Source slug

Derived from `url` and `revision`. It appears as the cache directory name, as `source_slug` in `.manifest.json`, and in the index's link targets.

**Inputs**: `url` and `revision` exactly as configured, with no `~` expansion. The procedure assigns them first, `url='<url>'` and `revision='<revision>'`, with `revision` empty when none is pinned.

**Algorithm**, unchanged (FR-009):

```text
1. normalized = url, a trailing ".git" stripped, then a trailing "/" stripped, then lowercased
2. hash_input = normalized                     when revision is empty
                normalized + "\n" + revision   when a revision is pinned
3. slug       = the first 12 hex characters of SHA-256(hash_input)
```

**Format**: `^[0-9a-f]{12}$`.

**Eligibility**: a source gets a slug only when its `url`, its `revision` and every `path_filter` entry pass their rules. A refused source never gets one (research § 5). Extending that to every shell-bound field keeps a value that failed its rule out of the shell even under quotes; today step 8a hashes every configured source, including one skipped for an invalid `revision`.

### The procedure

| Aspect | Today | After | Req |
| --- | --- | --- | --- |
| Inputs | whatever `$url` and `$revision` the shell holds; a long-lived shell carries one source's `revision` into the next | assigned first, from single-quoted placeholders | FR-006, FR-009 |
| Comments | after each line continuation | on lines of their own | FR-008 |
| Printing `url` to normalize it | `echo` | `printf '%s\n'`: the same bytes for any value without a backslash, which § 1 guarantees | FR-008 |
| sh and bash, run as written | hash an empty address: every unpinned source gets `e3b0c44298fc`, and pinned sources that share a revision share a cache | the documented slug | FR-009 |
| zsh, run as written | stops with a parse error and assigns nothing; an empty slug makes `cache/<slug>/` the cache root | the documented slug | FR-008 |
| Worked example | `abc123def456`, a placeholder | `18dbb51ec4eb`, the real slug | — |

Reference values, computed with `printf '%s'` and SHA-256. The full set is in [contracts/commands.md](contracts/commands.md) § 4.

| `url` | `revision` | Slug |
| --- | --- | --- |
| `https://GitHub.com/org/payment-service.git` | none | `18dbb51ec4eb` |
| `https://GitHub.com/org/payment-service.git` | `v2.4.1` | `5e8b13c49fbe` |
| empty, as sh and bash read today's procedure | none | `e3b0c44298fc` |

### Deletion guards

| Action | Deletes | Only when |
| --- | --- | --- |
| remove, default mode | the target's `cache/<slug>/` | the target has a slug, and it matches the format |
| sync step 8a | each directory in `actual − expected` | every configured source has a slug, every slug in `expected` matches the format, and so does the directory's own name |

`expected` still covers every configured source, enabled and disabled. Without a slug for each, prune cannot tell which directory a source owns, so it deletes nothing that run (research § 5, § 6).

### Caches across the upgrade

```text
cache/<slug>/ named by the documented algorithm
  └─ next sync ─▶ same slug ─▶ warm path, updated in place                       SC-007: 0 re-clones

cache/<slug>/ named by the broken procedure: e3b0c44298fc, or the hash of "\n<revision>"
  └─ next sync ─▶ no source resolves to it
       ├─ each source it held ─▶ cold clone into its own documented slug          User Story 3, scenario 4
       └─ step 8a ─▶ pruned in the first run that meets the guard

anything else under cache/, including what an empty slug wrote into the cache root
  └─ left in place: remove and step 8a delete only names of 12 lowercase hex characters
```

## 6. Fetched item names

A file or directory name comes from whoever controls the source. No configuration rule sees it, so it is made safe by how it travels, not by what it holds (FR-006, research § 7).

**Item**: as today, a `.md` regular file under the filter that git does not record as a symbolic link. New: every item is a path relative to the cache root with no `..` segment, so nothing outside `cache/<slug>/` is ever read.

| Stage | Today | After |
| --- | --- | --- |
| Listing | `find` from the filter directories, one name per line | `find` from `./<dir>` starting points, or `.`; `./` keeps a filter that bypassed § 1 from reading as an option |
| Filtering | recorded links removed | recorded links removed; a line with a `..` segment, or beginning with `/`, dropped |
| Measuring and hashing | `wc -c < "$file"`; `sha256sum <file>` takes the name as an operand | both read through redirection from `"$file"`, so a name beginning with `-` never reads as an option |
| Writing the manifest and the index | not said | the agent's file-writing tool; strings in the manifest escaped as JSON requires |
| Search reading content | `cache/<slug>/<path>` | the same path, through the agent's file tool |
| Quoting a name in a message | raw | escaped (§ 7) |

Names travel as newline-separated text, so a directory name holding a line break splits into two lines, and the second is forged. A name `y`, line break, `..` forges `../z/a.md`. A name ending in a line break forges `/sub/file.md`, an absolute path. Run against those two directories, the § Indexable Items pipeline prints `specs/y`, `../z/a.md`, `specs/x` and `/sub/file.md`. The first halves name directories, not regular files, so they are not items either. Research § 7 drops the `..` line; the edge case "No item is read from outside the source's cache" needs the `/` line dropped too, so both belong in the behaviour test's fixture.

## 7. Messages

Every message is the agent's own output. No message that quotes a value is printed by `echo` or `printf`: `echo "…"` around a refused value would run its `$(…)` (research § 8). A configuration value, a source label or a fetched file name quoted in any message shows each control character escaped (FR-005):

| Character | Shown as |
| --- | --- |
| line feed | `\n` |
| tab | `\t` |
| carriage return | `\r` |
| escape | `\e` |
| any other control character (U+0000 to U+001F, U+007F to U+009F) | `\xHH` |

That covers refusal and invalid-value lines, the status table, every `--verbose` listing, sync's symbolic-link and withholding lines, search results, and the source lists configure and remove print. An escaped refusal stays on one line (SC-003). The label rule bans whitespace but not other control characters, so a label needs this as much as a file name does.

## 8. Records outside the runtime

### 8.1 Where the rule is stated

| Location | Today | After | Req |
| --- | --- | --- | --- |
| § Configuration Validation Rules in configure, sync and status; normative, kept byte-identical by check 11 | No character rule. "Why no value may begin with `-`" covers option injection only. | The `url` and `path_filter` rows carry the rule. That section becomes the account of both layers: refuse with the character rule and the leading-`-` rule, neutralize with single quotes and `--`. | FR-001, research § 2 |
| README, Configuration Reference | the forms only | the characters `url` and `path_filter` accept | FR-011 |
| `config-template.yml`, the `url` and `path_filter` comments | the forms only | the characters each accepts | FR-011 |
| README, Trust model | the defenses table covers option injection, not shell syntax | two rows and a bullet: the new defense covers a merged configuration change running commands on teammates' machines, and does not cover a well-formed value pointing somewhere hostile | FR-010 |

remove and search reach the rules by reference to sync's block, as they already reach the slug procedure (plan).

### 8.2 CHANGELOG, under `[Unreleased]`

No version bump and no tag (FR-012).

| Entry | Commit (plan) |
| --- | --- |
| Security fix: the character rule, quoting, fetched names | `fix(security)` |
| Slug procedure fix | `fix(sync)` |
| Documentation changes | `docs(readme)` |
| Static check 12 | `chore(ci)` |
| Constitution amendment | `docs(constitution)` |

The behaviour test (`test(sync)`) is not among FR-012's entries, and the `AGENTS.md` pointer (`chore(agents)`) gets no line (research § 14).

### 8.3 Constitution record

| Field | Today | After |
| --- | --- | --- |
| Version | 1.3.0 | 1.4.0 |
| Last Amended | 2026-10-14 | the date of the amending commit |
| Quality Gates, static validation | checks 1 to 11 | adds 12: configuration placeholders in the commands' bash blocks sit inside single quotes |
| Rationale notes | 1.1.0, 1.2.0, 1.3.0 | adds a 1.4.0 rationale |

One `docs(constitution):` commit lands it (Governance).

### 8.4 Agent guidance pointer

The spec-kit section of `AGENTS.md`: the latest feature, links to its documents, and one status line. It must name the same feature as `.github/copilot-instructions.md` (FR-013, SC-008). It stays hand-maintained and outside the archive (research § 14).

```text
today       AGENTS.md: 005, "completed — shipped in v1.5.0. No feature is in progress."
            .github/copilot-instructions.md: 006
after plan  the after-plan hook points .github/copilot-instructions.md at 007
a task      AGENTS.md, by hand: 007, in progress on the branch, not yet released
release     AGENTS.md: 007, shipped in the release that carries it (release process, out of scope)
```
