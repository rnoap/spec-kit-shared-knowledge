# Contract: Command surface

**Feature**: [../shell-safe-config.spec.md](../shell-safe-config.spec.md) · **Plan**: [../plan.md](../plan.md) · **Research**: [../research.md](../research.md)

The five commands keep their names, arguments, flags and hooks. **Exit code is `0` on every path,
including every path added here.** What changes is what reaches a shell, and what a source that is
not accepted prints. Command prose cites this feature's requirements as `007 FR-001`
([research § 15](../research.md#15-requirement-citations)).

---

## 1. Commands

| Command | Change |
| --- | --- |
| `speckit.knowledge.configure` | Character rule before the local-path check; new error rows; a quoted argument stays whole; local paths recognised by `~/` |
| `speckit.knowledge.sync` | A source that is not accepted is skipped with one line; quoted placeholders; a runnable slug procedure; file names only through variables; manifest and index written with the file tool; prune guard |
| `speckit.knowledge.status` | Every source checked before step 2; `⚠️ invalid` row; quoted reachability checks |
| `speckit.knowledge.remove` | A target that is not accepted has its entry deleted or toggled, and keeps its cache for the next prune; slug form checked before purge |
| `speckit.knowledge.search` | Sources that are not accepted are left out; item content read with the file tool |

### 1.1 Schema gate

All five commands check the existing configuration's version before using any source (FR-014).
Only `schema_version: "1.1"` is accepted. For `"1.0"`, the agent prints:

```text
Error: knowledge-config.yml schema_version "1.0" requires migration to "1.1". Back up the file, review the README migration notes, then change only schema_version. No sources or caches were used or changed.
```

For a missing or unknown version it prints the following, with `<missing>` for a missing value:

```text
Error: Unrecognized knowledge-config.yml schema_version "<value>". Expected "1.1". No sources or caches were used or changed.
```

The value is escaped under § 2.3. Both paths exit 0 without handing source values to a shell,
computing slugs, reading source manifests, checking reachability, pruning or writing configuration
or caches. A hook finishes and its parent command continues. This gate precedes every per-source
rule, including remove's entry-only handling of a refused source. No unknown version is silently
downgraded.

If the file is absent, configure follows its existing creation flow using schema `"1.1"`. On a
successful edit it preserves `"1.1"`; every template, creation example, write instruction and
schema-error row in configure must agree. The old unknown-version warning that proceeds with
caution is replaced by this gate. Migration is the manual version-only procedure of
[knowledge-config.schema.md § 5](./knowledge-config.schema.md#5-compatibility), not a new flag.

---

## 2. Refusal

A source is **accepted** when every one of its values passes § Configuration Validation Rules,
checked in the order [knowledge-config.schema.md § 2](./knowledge-config.schema.md#2-check-order)
sets. A **refused** value is one that fails the character rule (FR-001).

### 2.1 The refusal line

Every command prints one line per configured source that is not accepted, before its other output
about sources, and goes on with every other source (FR-004). The format is today's `On failure`
line:

```text
⚠️  <source>: skipped — invalid `<field>` value "<value>" (<reason>)
```

| Part | Content |
| --- | --- |
| `<source>` | The `label`; without one, the label derived from an accepted `url`; otherwise `source <n>`, its 1-based position in `sources` |
| `<field>` | The field that failed |
| `<value>` | The value as configured; for a `path_filter` list, the failing entry only |
| `<reason>` | From the table below |

| Failure | `<reason>` |
| --- | --- |
| A character outside the accepted set | `"<c>" is not allowed`, `<c>` being the first such character |
| A space followed by `-`, in a local path | `a space followed by "-" is not allowed` |
| A `path_filter` entry beginning with `~` | `must not begin with "~"` |
| A `url` matching no accepted form, `~user/…` included | `not a Git URL, nor a local path starting /, ./, ../ or ~/` |
| Any other rule | Today's message, unchanged |

`<source>`, `<value>` and `<c>` are written under § 2.3.

```text
⚠️  payments-v2: skipped — invalid `url` value "https://example.com/x.git;touch /tmp/pwned" (";" is not allowed)
⚠️  source 3: skipped — invalid `url` value "https://example.com/$(touch /tmp/pwned)" ("$" is not allowed)
⚠️  adr-repo: skipped — invalid `url` value "https://example.com/x\ntouch /tmp/pwned" ("\n" is not allowed)
⚠️  kb-copy: skipped — invalid `url` value "~/kb - Copy" (a space followed by "-" is not allowed)
⚠️  alice-kb: skipped — invalid `url` value "~alice/kb" (not a Git URL, nor a local path starting /, ./, ../ or ~/)
⚠️  design: skipped — invalid `path_filter` value "docs/*.md" ("*" is not allowed)
⚠️  handbook: skipped — invalid `path_filter` value "~/notes" (must not begin with "~")
```

- The line is the agent's own output, never `echo` or `printf`
  ([research § 8](../research.md#8-messages)).
- sync prints it before `🔄 Syncing cross-repo knowledge sources...`, status before
  `📊 Shared Knowledge Status`, search before `🔍 Search:`.
- A hook-driven sync prints the same line, finishes and exits 0, so the spec-kit command the hook
  precedes continues.
- Everything else about a skipped source is unchanged: it is handled as a source failing any other
  rule is today.

### 2.2 configure

configure refuses to write a value that is not accepted (FR-003). It writes nothing, names the
field and the first character that is not allowed, and exits 0. New and changed rows in its
§ Error cases:

| Condition | Output |
| --- | --- |
| `url` contains a character outside the accepted set | `❌ Error: url contains "<c>", which is not allowed. A url may contain only letters, digits and . _ ~ : / @ % + - (a local path may also contain spaces).` |
| A local-path `url` contains a space followed by `-` | `❌ Error: url contains a space followed by "-", which is not allowed. Rename the folder, or link to it under another name.` |
| A `path_filter` entry contains a character outside the accepted set | `❌ Error: path_filter contains "<c>", which is not allowed. A path_filter may contain only letters, digits and . _ ~ : / @ % + -` |
| A `path_filter` entry begins with `~` | `❌ Error: path_filter must not begin with "~" (it would be read as a home directory)` |
| `url` empty or matching no accepted form (changed: `~` becomes `~/`) | `❌ Error: url must be a Git URL (https://, ssh://, git@) or a local path (/, ./, ../, ~/)` |

- `<c>` is written under § 2.3.
- The character rule runs before the local-path check (FR-002), so no existence check ever runs on
  a refused value.
- An existing entry that is not accepted gets the § 2.1 line and is written back unchanged.

### 2.3 Values in messages (FR-005)

Applies to every line any of the five commands prints that quotes a configuration value, a label
or a fetched file name: refusals, status lines, the symbolic-link line, conflict lines, verbose
lists and search results.

| Character | Shown as |
| --- | --- |
| Line feed | `\n` |
| Tab | `\t` |
| Carriage return | `\r` |
| Escape, U+001B | `\e` |
| Any other character below U+0020, and U+007F to U+009F | `\xHH`, two hexadecimal digits |
| Backslash | `\\` |
| Double quote, inside a quoted value | `\"` |

Every other character is shown as it is. A refused value therefore stays on one line (SC-003), and
nothing it carries can rewrite the terminal.

---

## 3. Values reaching the shell (FR-006)

### 3.1 The quoting rule

Stated inside § Configuration Validation Rules, beside the leading-`-` rule it extends, so
configure, sync and status carry it and remove and search reach it by reference
([research § 2](../research.md#2-the-quoting-rule-lives-inside-the-validation-block)).

1. **Configuration values.** Every configuration placeholder in a shell command sits inside single
   quotes. The agent writes the value as configured, or for `<expanded-path>` as expanded, with
   each `'` in it written `'\''`. This holds for the ```` ```bash ```` blocks and for any command
   the agent composes itself.
2. **`--`** still precedes every git operand
   ([006 contracts/commands.md § 5](../../006-catalog-readiness/contracts/commands.md#5-every-configuration-derived-git-operand-sc-006)).
3. **Fetched file names** reach a command only as `"$file"`, a shell variable in double quotes,
   never written into its text. They are read through redirection: `wc -c < "$file"`,
   `sha256sum < "$file"`, or `shasum -a 256 < "$file"` on macOS.
4. **`with_timeout`** hands its arguments on through `"$@"` and reads none of them.

Inside single quotes the shell expands nothing and splits nothing, so a value reaches git, `find`
or `[` as one literal argument. Validation refuses `'`, so on the normal path the `'\''` rule never
fires; it is what holds when validation is bypassed (SC-004).

### 3.2 Placeholders

The spelling is exact: `test-sync-git.sh` matches it letter for letter, and static check 12 reads
it ([ci.md § 1](./ci.md#1-static-check-12)).

| Placeholder | Stands for | Written in a block as |
| --- | --- | --- |
| `<url>` | `url` as configured | `'<url>'` |
| `<expanded-path>` | A local-path `url` with a leading `~/` replaced by the home directory and `/`; any other local path unchanged | `'<expanded-path>'`; in status, `'<expanded-path>/.git'` |
| `<revision>` | `revision` as configured; empty when none is pinned | `'<revision>'`; the optional argument `[--branch '<revision>']` |
| `<pattern1> [<pattern2> ...]` | Each `path_filter` entry, with a trailing `/` | `'<pattern1>' ['<pattern2>' ...]` |
| `<path_filter>` | The `path_filter` entries joined by spaces, tested only for emptiness | `'<path_filter>'` |
| `<dir1> [<dir2> ...]` | Each `path_filter` entry without its trailing `/`, or `.` when there is none | `'<dir1>' ['<dir2>' ...]` after `ls-files … --`; `'./<dir1>' ['./<dir2>' ...]` as `find` starting points |
| `<slug>` | The source's slug, checked to be 12 lowercase hex characters (§ 4.5) | `<slug>`, unquoted: the only exemption |

- Square brackets mark an optional or repeated argument, as today.
- `find` takes no `--`. The `./` keeps a filter that bypassed validation from reading as an option.
  With no filter, `find` receives `'./.'` and prints `././<path>`, so every leading `./` is removed
  from an item path.
- The slug procedure's `url` and `revision` are assigned from `<url>` and `<revision>` (§ 4.1),
  never inherited from the calling shell.

### 3.3 Fetched file names

A file name comes from whoever controls the source, and no configuration rule checks it
([research § 7](../research.md#7-fetched-file-names)).

- `$items` is newline-separated text from `find`. Any line with a `..` path segment, or beginning
  with `/`, is dropped, so a directory whose name holds a line break cannot forge a path outside
  the cache.
- Each item is measured and hashed through `"$file"` (§ 3.1). A name beginning with `-` never
  reaches `wc` or `sha256sum` as an option.
- `.manifest.json` and `knowledge-index.md` are written with the agent's file-writing tool, never
  through a shell. Manifest strings are escaped as JSON requires. Both formats are unchanged.
- search reads an item's content, for the excerpt and for `--verbose`, with the agent's
  file-reading tool.
- The agent may read file names from a command's output. It never writes one into a command.

### 3.4 What never reaches a shell

- Any value of a source that is not accepted (§ 2).
- A `label`. No command hands one to the shell.
- A message. Every message is the agent's own output (§ 2.1).

---

## 4. The slug procedure

§ Source Slug Generation in `speckit.knowledge.sync.md`. status, remove and search use it by
reference.

### 4.1 Interface

| Aspect | Contract |
| --- | --- |
| Inputs | Its first two statements, `url='<url>'` and `revision='<revision>'`, filled under § 3.1; `revision=''` when none is pinned. `url` is the value as configured, so a local path keeps its `~` |
| Output | One line on stdout: the slug, 12 lowercase hex characters. Nothing on stderr. Exit 0 |
| Shells | Runs as written in `sh`, `bash` and `zsh` (FR-008). On macOS `sh` is bash in POSIX mode; on `ubuntu:20.04` it is dash |
| Location | The first ```` ```bash ```` block after the line `### Source Slug Generation`, which is how `test-sync-git.sh` finds it |

Changes to the block ([research § 9](../research.md#9-the-slug-procedure)):

- The two assignments come first, so a long-lived shell cannot carry one source's `revision` into
  the next.
- Normalization starts from `printf '%s\n' "$url"`, not `echo "$url"`.
- No line that ends in `\` carries a comment. The explanations stay, on lines of their own.
- The last statement prints the slug: `printf '%s\n' "$slug"`.
- The worked example names the real slug: `https://GitHub.com/org/payment-service.git` gives
  `18dbb51ec4eb` and the cache directory `.specify/extensions/knowledge/cache/18dbb51ec4eb/`.

### 4.2 Algorithm, unchanged (FR-009)

1. Normalize `url`: strip a trailing `.git`, then a trailing `/`, then lowercase. The order
   matters: `…/repo.git/` keeps its `.git`.
2. Hash input: the normalized address alone when no revision is pinned; otherwise the normalized
   address, a line feed, and the revision.
3. Slug: the first 12 hex characters of the input's SHA-256, by `sha256sum`, else
   `shasum -a 256`.

### 4.3 Reference values

SC-007's reference set. Each row must hold in `sh`, `bash` and `zsh`. Computed with the algorithm
above and cross-checked with Python's `hashlib`. LF is a line feed.

| # | `url` | `revision` | Hashed | Slug |
| --- | --- | --- | --- | --- |
| 1 | `https://GitHub.com/org/payment-service.git` | none | `https://github.com/org/payment-service` | `18dbb51ec4eb` |
| 2 | `https://github.com/org/payment-service/` | none | `https://github.com/org/payment-service` | `18dbb51ec4eb` |
| 3 | `https://github.com/org/payment-service.git/` | none | `https://github.com/org/payment-service.git` | `e60fc46dba69` |
| 4 | `https://github.com/org/payment-service` | `v2.4.1` | `https://github.com/org/payment-service` LF `v2.4.1` | `5e8b13c49fbe` |
| 5 | `https://github.com/org/payment-service` | `0123456789abcdef0123456789abcdef01234567` | `https://github.com/org/payment-service` LF the revision | `93b864df69a3` |
| 6 | `git@github.com:org/payment-service.git` | none | `git@github.com:org/payment-service` | `c9511374b688` |
| 7 | `git@github.com:org/payment-service` | `main` | `git@github.com:org/payment-service` LF `main` | `b916698aa6c1` |
| 8 | `ssh://git@GitHub.com/Org/Payment-Service/` | none | `ssh://git@github.com/org/payment-service` | `0b93c9b8c26b` |
| 9 | `~/My Repos/kb` | none | `~/my repos/kb` | `d3ae9616ac00` |

- Rows 1 and 2 share a slug: one repository, written two ways.
- Rows 1, 4 and 5 differ: one address at three revisions (US3 AS3).
- Row 9 hashes the path as configured: `~` unexpanded, and lowercased like any address.

### 4.4 What the broken procedure produced

Run as written today, the block reads `url` and `revision` from the calling shell and breaks at
its first comment. Measured on `b9ffaee` (v1.6.0), macOS:

| Shell | Unpinned source | Source pinned to `v2.4.1` |
| --- | --- | --- |
| `sh`, `bash` | `e3b0c44298fc`, the SHA-256 of nothing | `28deeb5df3c5`, the SHA-256 of LF `v2.4.1` |
| `zsh` | empty, after a parse error | empty, after a parse error |

Run that way, every unpinned source got `e3b0c44298fc`, and sources pinned to one revision shared
a directory. After the fix no source resolves to those names: the next sync clones each source into
its documented slug, and step 8a prunes the shared directory (US3 AS4). A cache already named by the
documented algorithm is updated in place, never cloned again (SC-007).

### 4.5 Using a slug

Before any step uses `<slug>`, the agent confirms the procedure printed exactly 12 lowercase hex
characters. An empty slug turns `cache/<slug>/` into the cache root, which lies inside the
consumer's own repository: the warm path would run its sparse-checkout, fetch and forced checkout
on that repository. This extends the deletion guards of
[research § 6](../research.md#6-data-loss-guards-on-deletion) to every use of a slug.

| Command | A slug of any other form |
| --- | --- |
| sync | Skips its source: `⚠️  <source>: skipped — the slug procedure returned "<value>", not 12 lowercase hex characters`. Step 8a prunes nothing that run |
| status, search | Read no manifest through it: status shows `not synced`, search leaves the source out |
| remove | Purges nothing: `⚠️  Cache not purged: the slug procedure returned "<value>", not 12 lowercase hex characters.` |

The check is what makes `<slug>` safe to write unquoted (§ 3.2).

---

## 5. Per-command behaviour

### 5.1 status

Every source is checked before step 2 (FR-002). A source that is not accepted gets no slug, no
manifest read and no reachability check. Its § 2.1 line prints before the header, and its row
reads:

```text
│ notes                │ ⚠️ invalid   │ —            │ —        │ —          │ —                 │ —          │
```

- `⚠️ invalid` takes precedence over `— disabled`
  ([research § 5](../research.md#5-a-refused-value-never-reaches-a-shell)).
- The `Total` line counts it: `(3 reachable, 1 cached, 1 disabled, 1 invalid)`.
- The reachability checks, for accepted sources only:

```bash
with_timeout 5 git ls-remote --exit-code -- '<url>' HEAD
```

```bash
[ -d '<expanded-path>/.git' ] || git -C '<expanded-path>' rev-parse --git-dir 2>/dev/null
```

Their results are unchanged: `✅ reachable`, `❌ timeout`, `✅ reachable (local)`, `❌ not found`. A
local path containing a space reports `✅ reachable (local)` (SC-005).

### 5.2 sync: pruning

Step 8a deletes a directory only when all three hold:

1. Every configured source, enabled or disabled, was accepted this run.
2. Every expected slug is 12 lowercase hex characters.
3. The directory's own name is 12 lowercase hex characters. No other directory under `cache/` is
   ever deleted.

Otherwise it deletes nothing, and prints nothing beyond the lines § 2.1 and § 4.5 already printed.
A refused source's cache therefore survives until its value is edited.

### 5.3 remove

- The target is resolved as today: exact `label`, then the raw `url` string. Both are string
  comparisons; neither reaches a shell.
- **A target that is accepted** is purged as today, after the § 4.5 check.
- **A target that is not accepted** has its entry deleted, or `enabled` toggled, as requested. Its
  slug is not computed and its cache is not purged; step 8a removes the cache on the next sync in
  which every source is accepted:

```text
✅ Removed source "notes" from knowledge-config.yml
ℹ️  Its cache was left in place: the source fails validation, so its cache directory is not computed.
   The next __SPECKIT_COMMAND_KNOWLEDGE_SYNC__ in which every source is accepted prunes it.
```

### 5.4 search

- The corpus is the manifests of accepted, enabled sources. A source that is not accepted gets its
  § 2.1 line before the results and contributes nothing.
- A file named `$(touch pwned).md` is found, shown and read without anything running (US2 AS2).

### 5.5 configure: arguments

`$ARGUMENTS` splits on whitespace, except inside a matching pair of `'…'` or `"…"`, which stays one
argument with its quotes removed
([research § 13](../research.md#13-configure-keeps-a-quoted-argument-whole)). Nothing else in the
text is interpreted: no `$`, no backslash escape.

| Typed after the command | URL or path | `path_filter` |
| --- | --- | --- |
| `'~/My Repos/kb' specs/` | `~/My Repos/kb` | `specs/` |
| `"~/My Repos/kb"` | `~/My Repos/kb` | none |
| `~/My Repos/kb` | `~/My`, which does not exist | `Repos/kb` |

- An unmatched quote stays in its argument as a character, which the character rule refuses.
- A local path starts with `/`, `./`, `../` or `~/`. Its `~/` is expanded for the existence check
  only; the entry keeps the path as typed, so its slug is the one § 4 computes.

---

## 6. Error contract

| Condition | Behaviour | Exit |
| --- | --- | --- |
| Missing, legacy `"1.0"` or unknown configuration schema version | § 1.1 diagnostic; no source use, configuration write or cache change | 0 |
| A `url` or `path_filter` value fails the character rule on read | § 2.1 line; source skipped; every other source continues | 0 |
| The same value given to configure | § 2.2 error; nothing written | 0 |
| A local-path `url` holds a space followed by `-` | As above, with its own reason | 0 |
| A `path_filter` entry begins with `~` | As above, with its own reason | 0 |
| A `url` written `~user/…` | Refused: no accepted form | 0 |
| A message would quote a control character | Shown escaped (§ 2.3) | 0 |
| Any source not accepted in a sync run | Step 8a deletes nothing | 0 |
| The slug procedure prints anything but 12 lowercase hex characters | § 4.5 | 0 |
| remove targets a source that is not accepted | Entry deleted or toggled; cache left for step 8a | 0 |
| A hook-driven sync meets a refused value | Source skipped; the hook finishes; the spec-kit command continues | 0 |
| A fetched file name carries shell syntax | Indexed and searchable as data; nothing runs | 0 |
| A fetched directory name holds a line break | No item is read from outside the cache | 0 |

---

## 7. Compatibility

| Contract | Status |
| --- | --- |
| Commands (5), flags, hooks (4, no arguments) | Unchanged |
| Exit codes | `0` on every path |
| `extension.yml` `version` | Unchanged. This feature tags nothing; its changes wait under `[Unreleased]` |
| Configuration `schema_version` | `"1.1"`; explicit manual migration from `"1.0"`, no automatic rewriting ([knowledge-config.schema.md](./knowledge-config.schema.md#5-compatibility)) |
| Slug algorithm | Unchanged: caches named by it are reused (§ 4.4) |
| Caches named by the broken procedure | Replaced on the next sync, then pruned (§ 4.4) |
| `.manifest.json`, `knowledge-index.md` | Formats and schema versions unchanged |
| § Configuration Validation Rules, three copies | Three rows replaced (`schema_version`, `url`, `path_filter`), the quoting rule, schema gate and an `On failure` example added; still byte-identical (Quality Gate 11) |
| status table | New `⚠️ invalid` cell; `invalid` count in the `Total` line |
