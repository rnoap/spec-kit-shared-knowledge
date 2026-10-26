# Contract: Command surface

**Feature**: [../batch-corpus-measurement.spec.md](../batch-corpus-measurement.spec.md) · **Plan**: [../plan.md](../plan.md) · **Research**: [../research.md](../research.md) · **Data model**: [../data-model.md](../data-model.md)

The five commands keep their names, arguments, flags and hooks. **Exit code is `0` on every path, including every path added here.**
What changes is how a source is recorded and checked.
Sync records each source with one shell run, so the agent never handles a hash.
The Cache Integrity Check becomes one shell run per source, and every reader of a cache uses it.
The sync report names files skipped because their name is not valid UTF-8, and two recovery bugs are fixed.
Command prose cites this feature's requirements as `011 FR-001`.
The manifest's bytes are in [manifest.schema.md](./manifest.schema.md), the checks in [sync-checks.md](./sync-checks.md), and the states of a cache directory in [data-model.md](../data-model.md#state-transitions).

---

## 1. Commands

| Command | Change |
| --- | --- |
| `speckit.knowledge.sync` | § Indexable Items revised; new § Item Records; § Cache Integrity Check becomes a block; § Cache Freshness Gate reads a missing manifest as `stale`; § Corpus Measurement corrected for BSD `wc -c`; step 4 gains the path-choice block and runs the check on its policy-fresh path; step 5 is the record run and step 6 its tail; step 9 gains one line; the command states the upgrade and re-run facts |
| `speckit.knowledge.status` | Step 2 runs the check. A failing source shows `corrupted`, and nothing is deleted |
| `speckit.knowledge.search` | Step 1 runs the check. A failing source is set aside for this search, and nothing is deleted |
| `speckit.knowledge.configure` | Unchanged |
| `speckit.knowledge.remove` | Unchanged |

No flag is added.
§ Configuration Validation Rules stays byte-identical in its three copies (Quality Gate 11): its file-name rule already admits `printf '%s' "$file"`.

---

## 2. The blocks

Each procedure is the first ```` ```bash ```` block after its anchor line in `commands/speckit.knowledge.sync.md`.
`test-sync-git.sh` extracts it by that anchor, matched as a line prefix, and status and search reach it by reference (FR-012).

| Anchor | Block | Does |
| --- | --- | --- |
| `### Indexable Items` | Revised | `cd` into the cache root; sets `$items` and `$links` |
| `### Item Records` | New | Measures, hashes and encodes each item; builds the report; defines the manifest renderer |
| ``### 6. Write `.manifest.json` (last step)`` | New block | The record tail (§ 2.3) |
| `### Cache Integrity Check` | New block, replacing the five numbered steps | The check tail (§ 2.4) |
| `**Determine sync path**` | New block in step 4 | The path choice (§ 5.2) |

Two compositions use them ([research D1](../research.md#d1-three-composed-blocks-one-shell-run-per-source)):

| Run | Blocks, in order | Callers |
| --- | --- | --- |
| Record run | § Indexable Items → § Item Records → step 6 block | Sync step 5 |
| Check run | § Indexable Items → § Item Records → § Cache Integrity Check block | Status step 2; search step 1; sync's two fallbacks; sync step 4's policy-fresh path |

The agent runs a composition as one shell command, so a source costs one step whatever its item count (FR-001, FR-011).
Because both runs share their first two blocks, they apply the same item rules and the same renderer (FR-007).

Rules for every block:

1. A placeholder new to a block is assigned single-quoted at the top of that block, before any `$(`: `url='<url>'` and `revision='<revision>'` in § Item Records. Every other placeholder keeps its quoted form ([007 contracts/commands.md § 3.2](../../007-shell-safe-config/contracts/commands.md#32-placeholders)), and `<slug>` stays the only unquoted one (Quality Gate 12).
2. A file name enters a command only as `"$file"`: by redirection into `wc -c`, `sha256sum` or `shasum -a 256`, or as `printf '%s' "$file"` piped into `od`. awk sees only hex digits and numbers (FR-005).
3. `LC_ALL=C` prefixes each `sed`, `grep`, `sort`, `awk`, `od` and `tr`, and is never exported ([research D2](../research.md#d2-byte-semantics-lc_allc-on-each-text-tool)).
4. The same text runs under sh, bash and zsh (FR-016). Nothing relies on word splitting or globbing of an unquoted variable, and no variable is named `path` or `status`, which zsh reserves.
5. The blocks use git, the tools the commands already rely on (`awk`, `sed`, `grep`, `find`, `tr`, `cut`, `wc`, and `sha256sum` or `shasum`), and POSIX `sort`, `od`, `cmp`, `date`, `mv` and `rm`, present on every macOS and Linux install. No Python, `jq` or Perl. `extension.yml` keeps declaring only git (FR-015).

### 2.1 Indexable Items, revised

Today's item rules stand: regular files only; git mode `120000` excluded; every leading `./` stripped; any line with a `..` segment or a leading `/` dropped; and, with no filter, root-level dot-directories and `AGENTS.md`, `CLAUDE.md` and `GEMINI.md` left out.
Three changes:

- **Line feeds** ([research D3](../research.md#d3-paths-with-a-line-feed-are-left-out-at-find-time)). `find … ! -path "*$nl*"`, with `nl` holding a literal line feed. Such a path never enters `$items`, so no fragment, phantom or duplicate item exists (finding 5). It gets no report line.
- **Links** ([research D4](../research.md#d4-links-come-from-ls-files--s--z-converted-with-tr)). `git -c core.quotePath=false ls-files -s -z -- '<dir1>' ['<dir2>' ...] | LC_ALL=C tr '\0' '\n' | LC_ALL=C awk …`. Names arrive verbatim and match `find`'s output byte for byte, so a link named with `"`, `\` or a control character is excluded like any other (finding 4).
- **Bytes.** Every text tool runs under `LC_ALL=C` (finding 3), and `$items` is in byte order.

Outputs: `$items` and `$links`, newline-separated, as today. The working directory is the cache root.

### 2.2 Item Records, new

For each line of `$items`, held in `file`:

- **Size**: `wc -c < "$file"`, as digits only, with BSD's padding stripped (finding 6).
- **Hash**: `sha256sum < "$file"` or `shasum -a 256 < "$file"`, as 64 lowercase hex characters.
- **Name**: `printf '%s' "$file" | LC_ALL=C od -An -tx1 -v | LC_ALL=C tr -d ' \n'`, the path's bytes as hex.

One awk program reads a `hex size hash` line per item ([research D5](../research.md#d5-the-encoder-reads-hex-not-text)).
A path that is valid UTF-8 yields a manifest item line ([manifest.schema.md § 3](./manifest.schema.md#3-strings)) and an `item:` line.
Any other path yields only a `skipped-utf8:` line: it is in neither the manifest nor the `item:` lines, so it never reaches the index (FR-006).
Every line of `$items` yields exactly one of the two.
The block also encodes `url` and `revision`, and defines the renderer both tails call: given a `synced_at`, it writes the canonical text of [manifest.schema.md § 2](./manifest.schema.md#2-canonical-text).

**Valid UTF-8** is strict: no overlong form, no surrogate, nothing above U+10FFFF.
A path, every component included, is valid when its bytes split entirely into these sequences:

| Code points | Byte 1 | Byte 2 | Byte 3 | Byte 4 |
| --- | --- | --- | --- | --- |
| U+0000 to U+007F | 00–7F | | | |
| U+0080 to U+07FF | C2–DF | 80–BF | | |
| U+0800 to U+0FFF | E0 | A0–BF | 80–BF | |
| U+1000 to U+CFFF | E1–EC | 80–BF | 80–BF | |
| U+D000 to U+D7FF | ED | 80–9F | 80–BF | |
| U+E000 to U+FFFF | EE–EF | 80–BF | 80–BF | |
| U+10000 to U+3FFFF | F0 | 90–BF | 80–BF | 80–BF |
| U+40000 to U+FFFFF | F1–F3 | 80–BF | 80–BF | 80–BF |
| U+100000 to U+10FFFF | F4 | 80–8F | 80–BF | 80–BF |

C0, C1 and F5 to FF never occur.
APFS refuses names that fail this test, so they come only from Linux file systems (finding 7).

### 2.3 The record tail: step 6

1. Takes `synced_at` from `date -u +%Y-%m-%dT%H:%M:%SZ`.
2. Renders the manifest into `.manifest.json.tmp`, then `mv -f` onto `.manifest.json` (FR-008).
3. Prints the report (§ 3), and only after the rename succeeded. A record run that printed no `records:` line wrote no manifest.

It runs once every item is in place, as the source's last write (FR-009).

### 2.4 The check tail: Cache Integrity Check

1. Reads only the `synced_at` line of `.manifest.json`, which must match `^  "synced_at": "[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z",$`.
2. Renders the canonical text with that timestamp and the current `url`, `revision` and slug.
3. Compares it with `.manifest.json` using `cmp`. Identical bytes give `integrity=pass`. A difference, a missing or malformed `synced_at` line, or a missing manifest gives `integrity=fail`.
4. Prints the verdict and the report (§ 3).

The agent compares no hash (FR-011).
The check prescribes no action: it never deletes, clones or sets a status, and each caller acts on the verdict (§ 4, finding 8).
It renders with the current configuration, so editing `path_filter`, or editing `url` in a way that keeps the slug (letter case, a trailing `.git` or `/`), fails the check until the next sync records the source again.

---

## 3. Report lines

Both runs print machine-readable lines for the agent, in this order ([research D10](../research.md#d10-report-lines-for-the-agent)):

| Line | Printed | Meaning |
| --- | --- | --- |
| `records: <slug> items=<N> bytes=<B> synced_at=<ts>` | Once, first | `<N>` recorded items, `<B>` the sum of their sizes, `<ts>` the timestamp written (record run) or read (check run) |
| `integrity=pass` or `integrity=fail` | Check run only, second | The verdict |
| `item: <size> <display path>` | Once per recorded item, in manifest order | `<size>` in bytes, digits only |
| `link: <display path>` | Once per skipped symbolic link, in byte order | A link from `$links`, never read |
| `skipped-utf8: <display path>` | Once per name that is not valid UTF-8, in byte order | A name left out of the manifest and the index |

- `<display path>` follows § Values in messages ([007 contracts/commands.md § 2.3](../../007-shell-safe-config/contracts/commands.md#23-values-in-messages-fr-005)): `\t`, `\r`, `\e`, `\xHH` for any other character below U+0020 or from U+007F to U+009F, and `\\` for a backslash. A double quote stays as it is, since no report line quotes a path.
- In a `skipped-utf8:` line, reading left to right, every byte outside a valid sequence is shown as `\xHH`: `caf`, byte E9, `.md` is `caf\xE9.md`. Hex digits are upper case in every `\xHH`.
- `<N>` and `<B>` count recorded items only. Links and skipped names count in neither, nor in `item_count`.
- When a check fails, `<ts>` is the manifest's timestamp if its line matched and empty otherwise, and the `item:` lines describe the files on disk. Callers use none of them.
- The report is tool output for the agent, not a message. It carries no raw control byte, and the agent turns it into the index and step 9's lines. Messages stay agent output, never `echo` or `printf` (FR-014).

The record run of the source in [manifest.schema.md § 4](./manifest.schema.md#4-examples):

```text
records: 18dbb51ec4eb items=6 bytes=50 synced_at=2026-10-26T14:00:00Z
item: 8 $(touch pwned).md
item: 9 -option.md
item: 10 specs/a"b\\c\td.md
item: 6 specs/api.md
item: 9 specs/esc\eape.md
item: 8 specs/guía.md
link: specs/notes.md
link: specs/shared
skipped-utf8: specs/caf\xE9.md
```

A check run on the same, unchanged cache prints the same lines with `integrity=pass` second.
After one byte of `specs/api.md` changes, the counts stay the same and the verdict does not:

```text
records: 18dbb51ec4eb items=6 bytes=50 synced_at=2026-10-26T14:00:00Z
integrity=fail
```

The item lines follow, as above.

---

## 4. Callers and verdicts

The check runs only on a cache directory that holds both `.git` and `.manifest.json`, so no git command ever runs where it would resolve to the project's own repository.
Each caller handles the case where it does not run, and acts on the verdict ([research D7](../research.md#d7-the-check-renders-and-compares-callers-act), [D8](../research.md#d8-every-reader-of-a-cache-runs-the-check)):

| Caller | Check not run | `integrity=pass` | `integrity=fail` |
| --- | --- | --- | --- |
| Sync step 4, policy-fresh path: `verdict=fresh`, no `--force` | No `.git`: as `fail` | `current`. Items and sizes from the report feed steps 7 and 7a. No network is touched; only the local `git ls-files` runs | Treated as `stale`: on to the path choice (FR-012, finding 9) |
| Sync, § On timeout or failure | No manifest or no `.git`: `unreachable` | `cached`; items from the report; `last_synced_at` from `synced_at` | `unreachable`; the source is skipped and its cache left as it is |
| Sync, all three tiers failed (FR-015) | As above | The cache is served, as today | Nothing is served |
| Status step 2 | No manifest: `not synced`. A manifest without `.git`: `corrupted` | `synced_at` and the item count from the `records:` line; `fresh` or `cached` by policy, as today | `corrupted`. Nothing is deleted: status stays read-only |
| Search step 1 | No manifest, or no `.git`: no usable manifest | The manifest's `items[]` join the corpus | Set aside for this search; nothing is deleted |

When eligible sources remain but none has a usable manifest, search runs sync first, as today.

---

## 5. Recovery

### 5.1 Cache Freshness Gate

A missing manifest is stale, never fresh (FR-021):

| Effective policy | Manifest | Verdict |
| --- | --- | --- |
| None | Any | `stale`, as today |
| Set | Missing | `stale`. Before this feature it read `fresh` (finding 2) |
| Set | Older than the policy | `stale` |
| Set | Within the policy | `fresh`, then the check (§ 4) |

`--force` still sends every source on to the path choice, as today.

### 5.2 Path choice

A cache directory without its own `.git` or without a manifest is an interrupted sync: sync removes it and clones again (FR-020).
The rule is a ```` ```bash ```` block under **Determine sync path** in step 4, so the checks run it as written.
It runs after the gate and prints `warm` or `cold`:

| `cache/<slug>/` | Prints | Then |
| --- | --- | --- |
| Absent | `cold` | Cold path |
| Holds `.git` and `.manifest.json` | `warm` | Warm path |
| Lacks either: a failed clone, or a sync that stopped before its manifest | `cold` | The block has removed the directory; cold path |

- It runs only after the slug matched `^[0-9a-f]{12}$` ([007 contracts/commands.md § 4.5](../../007-shell-safe-config/contracts/commands.md#45-using-a-slug)), and removes nothing but `cache/<slug>/`.
- The warm path's git commands therefore run only in a directory with its own `.git`, never against the project's own repository (finding 1).
- A clone that fails leaves at most an interrupted directory, which the next sync removes before cloning again.

### 5.3 Upgrade and re-run

The README's `## 🩺 Troubleshooting` section gains an entry, and the sync command's text states the same two facts (FR-018):

1. The first sync after an extension upgrade rebuilds every source.
2. Running sync again completes a sync that stopped part-way.

The `💥 Corrupted cache` entry is brought in line with § 4, since the check no longer discards a directory.
README troubleshooting mirrors the command text (constitution II).

---

## 6. Sync report

Step 9 gains one line under a source whose run reported a name that is not valid UTF-8 (FR-006).
It follows the links line, or the status line when no link was skipped.
Both lines can follow a `fresh` source, from its record run, or a `current` or `cached` one, from its check run.

```text
  payment-service    ✅ fresh    6 items   (synced 2026-10-26T14:00:00Z)
                     🔗 2 symbolic links not followed: specs/notes.md, specs/shared
                     ⚠️ 1 file skipped, name not valid UTF-8: specs/caf\xE9.md
```

| Names | Line |
| --- | --- |
| 1 | `⚠️ 1 file skipped, name not valid UTF-8: <path>` |
| 2 or more | `⚠️ <n> files skipped, names not valid UTF-8: <path>, <path>` |

- `<path>` is the `skipped-utf8:` display path as printed. Every name is listed, joined by `, `, as on the links line.
- The line is agent output, never `echo` or `printf` (007 FR-005).
- The status line and the links line are today's (FR-014). The plan's `sync-report` screen shows `✅ synced`; the status word stays `fresh`.

---

## 7. Rules revised

| Rule | Before | After |
| --- | --- | --- |
| Who writes `.manifest.json` | The agent's file-writing tool, never a shell ([007 contracts/commands.md § 3.3](../../007-shell-safe-config/contracts/commands.md#33-fetched-file-names)) | The record run's step 6 block. Names reach it only as hex from `od` |
| Who writes `knowledge-index.md` | The agent's file-writing tool | Unchanged |
| How a file name reaches a command | `"$file"`, through redirection | Also `printf '%s' "$file"`, piped into `od` |
| The Cache Integrity Check | Five steps; the agent re-hashes every item; a failure discards the directory | One check run; a verdict only; callers act (§ 4) |
| Sync step 4, policy-fresh path | Items read from the manifest; "No `git` runs" | The check runs first; no network is touched |
| A 1.3.0 manifest | Needs no re-sync | Fails the check once and is recorded again |

`specs/007-shell-safe-config/research.md` § 7 records the revision, limited to the manifest (FR-019).

---

## 8. Error contract

| Condition | Behaviour | Exit |
| --- | --- | --- |
| A path is not valid UTF-8 | Left out of the manifest and the index; `skipped-utf8:` line; step 9 line; the source still passes the check | 0 |
| A path holds a line feed | Left out at `find` time, with no report line; no fragment, phantom or duplicate item | 0 |
| A symbolic link's name holds `"`, `\` or a control character | Skipped and named like any other link | 0 |
| A file name carries shell syntax or begins with `-` | Recorded as data; nothing runs; no option is read | 0 |
| A source has no item | `"items": []` and `item_count` `0`; the check passes | 0 |
| The record run stops before the rename: interrupted, disk full, permission denied | `.manifest.json` is neither created nor replaced, and no `records:` line is printed; handled as § On timeout or failure | 0 |
| A `.manifest.json.tmp` was left behind | Never read; the next record run writes over it | 0 |
| The check fails | § 4, by caller | 0 |
| Sync finds `cache/<slug>/` without `.git` or without `.manifest.json` | Removed and cloned again (FR-020) | 0 |
| `max_cache_age` is set and the manifest is missing | `stale`: the source is fetched (FR-021) | 0 |
| `path_filter` edited, or `url` edited in a way that keeps the slug | The check fails until the next sync records the source again | 0 |
| A manifest from 1.9.1 or earlier | Fails once unless byte-identical; recorded again at the next successful sync (FR-013) | 0 |

---

## 9. Compatibility

| Contract | Status |
| --- | --- |
| Commands (5), flags, hooks | Unchanged |
| Exit codes | `0` on every path |
| `extension.yml` `version` | `1.10.0`, a minor release ([research D11](../research.md#d11-version-1100)). The README badge and install URL, and a `CHANGELOG.md` `[1.10.0]` entry, move with it. It still declares only git |
| `.manifest.json` | Path, keys and `schema_version` `"1.0"` unchanged; one canonical text ([manifest.schema.md](./manifest.schema.md)) |
| `knowledge-index.md` | Format unchanged; stays agent-written |
| Configuration `schema_version` | `"1.1"`, unchanged |
| Status values | `fresh`, `cached`, `not synced` and `corrupted`, unchanged |
| Sync status lines | Unchanged; one new line (§ 6) |
| § Configuration Validation Rules | Unchanged, and byte-identical in its three copies (Quality Gate 11) |
| Caches written by 1.9.1 | Rebuilt at most once after the upgrade (SC-007) |
| CI | Unchanged ([clarifications](../batch-corpus-measurement.spec.md#session-2026-10-26)) |
