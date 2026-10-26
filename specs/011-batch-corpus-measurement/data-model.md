# Data Model: Shell-recorded manifests

**Spec**: [batch-corpus-measurement.spec.md](./batch-corpus-measurement.spec.md) · **Plan**: [plan.md](./plan.md) · **Research**: [research.md](./research.md)

No persisted format changes.
`.manifest.json` keeps its path, its keys and schema version `"1.0"` (FR-010).
`knowledge-index.md` keeps its format and stays agent-written (FR-014).
`knowledge-config.yml` keeps schema `"1.1"` and gains no key.
What changes is who writes the manifest and how, which bytes count as a valid manifest, which files count as items, what the agent receives in place of hashes, and how a cache directory moves between states.

```text
knowledge-config.yml ─▶ Source (Entity 1) ─▶ slug ─▶ cache/<slug>/, in one of five states

record run (Entity 5), sync step 5:
  § Indexable Items ─▶ § Item Records ─▶ step 6 block
                                           ├─▶ .manifest.json.tmp ─ mv -f ─▶ .manifest.json (Entity 4)
                                           └─▶ run report (Entity 6) ─▶ agent ─▶ index (Entity 8)

check run (Entity 5), for status, search, sync's fallbacks and the policy-fresh path:
  § Indexable Items ─▶ § Item Records ─▶ § Cache Integrity Check block
                                           └─▶ integrity verdict (Entity 7) + run report ─▶ the caller acts

The first two blocks yield the items (Entity 2) and skipped items (Entity 3), the same in both runs (FR-007).
```

## Entity 1: Source

A configured knowledge repository, cached as a git checkout under its slug.
No field is added, removed or retyped, and § Configuration Validation Rules stays byte-identical in its three copies (quality gate 11).

| Field | What the runs take from it |
| --- | --- |
| `url` | `source_url`, copied as configured: a local path keeps its `~` and is not expanded (D6). |
| `revision` | `revision`, or `null` when none is pinned. |
| `path_filter` | The starting points of § Indexable Items, or `.` when absent. |
| `max_cache_age` | The policy of the freshness gate (State transitions). |
| slug (derived) | `source_slug` and the cache directory name. Used only after it matches `^[0-9a-f]{12}$` (007 FR-002). |
| `label` | Names the source in step 9's lines. Never reaches a shell. |

### Validation rules

- Every configuration value enters a block as a single-quoted placeholder assigned at the top of that block, before any `$(` (quality gate 12).
- An accepted `url` or `revision` holds no character JSON must escape (007 FR-001).
  Source values are still escaped by the same JSON rules as names, so the guarantee does not rest on validation alone (FR-004, edge case).

## Entity 2: Item

An indexable Markdown file of a source.

| Field | Value |
| --- | --- |
| Path | The file's path in bytes, relative to `cache/<slug>/`, with no leading `./`. |
| Size | Bytes of content from `wc -c < "$file"`, as digits only with no padding (finding 6). |
| Hash | SHA-256 of the content, 64 lowercase hex characters, from `sha256sum` or `shasum -a 256` reading through redirection. |
| Order | Byte order of the path under `LC_ALL=C` (D2). |
| Stored | Path and hash in the manifest. Path and size in the run report. The size never enters the manifest. |

### Item rules

Record and check runs apply the same rules, in the same two blocks (FR-007, D1).
A path is an item when all of these hold:

1. It ends in `.md`, is a regular file on disk, and lies under a `path_filter` directory; with no filter, it lies outside every root-level dot-directory and is not named `AGENTS.md`, `CLAUDE.md` or `GEMINI.md` (unchanged).
2. git does not record it as a symbolic link, mode `120000`. Links are listed with `ls-files -s -z`, so a link whose name holds `"`, `\` or a control character still matches its file byte for byte (D4, finding 4).
3. It holds no line feed. Such a path is left out at `find` time and is not reported, so no fragment can name a path outside the source, a phantom item or a duplicate (D3, finding 5).
4. Once its leading `./` is stripped, it has no `..` segment and does not begin with `/` (unchanged, 007 FR-006).
5. It is valid UTF-8: no overlong form, no surrogate, nothing above U+10FFFF, no stray or truncated sequence (D5). A path that fails only this rule is a skipped item (Entity 3).

Each text tool in the blocks (`sed`, `grep`, `sort`, `awk`, `od`, `tr`) runs under `LC_ALL=C`, set per command and never exported (D2).
No locale can stop the list at an invalid byte or write "Binary file (standard input) matches" into it (finding 3).

### Name forms

A name travels in five forms, each with one use.

| Form | Where | Rule |
| --- | --- | --- |
| Raw bytes | On disk and in `"$file"`. | Never pasted into command text. Read only through redirection or `printf '%s' "$file"`, which the file-name rule of § Configuration Validation Rules already admits. |
| Hex | The encoder's input in § Item Records, one `<hex> <size> <hash>` line per item. | The path's bytes as hex pairs from `od`. awk reads only hex digits and numbers, so no awk variant can misread a hostile byte (D5). |
| JSON string | `items[].path` in the manifest. | `\"`, `\\`, `\b`, `\f`, `\n`, `\r`, `\t`, and `\u00XX` for any other byte below 0x20. Every other byte is written raw, valid UTF-8 included (D5, FR-004). |
| Display | Run report lines and the sync summary. | § Values in messages (007 FR-005): `\n`, `\t`, `\r`, `\e`, `\xHH` for any other character below U+0020 or from U+007F to U+009F, and `\\` for a backslash. |
| Skipped display | `skipped-utf8:` lines and the summary line that names them. | The display form, with each byte that is not valid UTF-8 shown as `\xHH`, as in `specs/caf\xE9.md` (FR-006). |

### Validation rules

- A name never runs as a command, acts as an option or creates a file (FR-005).
- `guía.md`, like every valid non-ASCII name, is recorded and displayed as is, not skipped (edge case).
- The same source yields the same records under sh, bash and zsh, on macOS and on Linux back to Ubuntu 20.04 with git 2.25, and under BSD awk, gawk and mawk (FR-016, US2 scenario 4, spike).
- APFS refuses names that are not valid UTF-8, so only Linux file systems produce rule 5's skips (finding 7).

## Entity 3: Skipped item

A path left out of recording and named in the sync report under its source (FR-006).
A path with a line feed is not a skipped item: it is left out without a report line, as today (item rule 3).

| Field | Value |
| --- | --- |
| Kind | `link`: git records the path as a symbolic link. `skipped-utf8`: the path is not valid UTF-8. |
| Name | The display form; for `skipped-utf8`, the skipped display form. |
| Source | The source whose run found it. |
| Report line | `link: <name>` or `skipped-utf8: <name>` (Entity 6). |

### Validation rules

- It is never listed in the manifest or the index, and never counted in `item_count`, `items=` or `bytes=` (FR-006).
- A link is never read and never followed (unchanged).
- The check applies the same skip rules, so a skipped item never makes its source fail (FR-007, US2 scenario 3).
- Record and check runs both report skips, so their lines can follow a `fresh`, `cached` or `current` source.

### Sync summary lines

Under a source's status line, step 9 prints at most two more lines, each only when the run found at least one name of its kind:

```text
                     🔗 2 symbolic links not followed: specs/notes.md, specs/shared
                     ⚠️ 1 file skipped, name not valid UTF-8: specs/caf\xE9.md
```

The links line is unchanged.
The `⚠️` line is new, always follows the links line, and names every such item on that one line (FR-006, plan screen `sync-report`).
The status word is not part of this change: it stays `fresh`, although the plan's `sync-report` screen shows `synced`.

## Entity 4: Manifest

The per-source record of a cache, at `.specify/extensions/knowledge/cache/<slug>/.manifest.json`.
Its presence and validity mark a usable cache.
The format is unchanged (FR-010, Verbatim Constraints); its writer, its write and its canonical bytes are new.

| Key | Type | Value | Req |
| --- | --- | --- | --- |
| `schema_version` | string | `"1.0"`, unchanged. | FR-010 |
| `source_url` | string | The configured `url`, unexpanded (Entity 1). | FR-004, D6 |
| `source_slug` | string | The directory name: 12 lowercase hex characters. | 007 FR-002 |
| `revision` | string or `null` | The pinned revision, or `null` when none is pinned. | edge case |
| `synced_at` | string | UTC time of the record run as `YYYY-MM-DDTHH:MM:SSZ`, from `date -u +%Y-%m-%dT%H:%M:%SZ`. | D6 |
| `item_count` | integer | The number of records in `items`. | FR-003 |
| `items` | array | One record per item, in byte order of the path; `[]` when the source has none. | FR-003 |
| `items[].path` | string | The item's path in JSON string form (Entity 2). | FR-004 |
| `items[].sha256` | string | The item's hash. | none |

### Canonical text

The layout of today's step 6 example becomes exact (D6):

- the top-level keys in the order above, indented two spaces;
- one record per line, indented four spaces, as `{"path": "…", "sha256": "…"}`, with a comma after every record but the last;
- `"items": []` on one line when the source has no item;
- `revision` written as a bare `null` when none is pinned.

One renderer, defined in § Item Records, produces this text for the record run and again for the check.
A manifest is therefore valid exactly when its bytes equal that renderer's output (Entity 7, D1).

### Write

The step 6 block, the record run's tail, writes the manifest:

1. after the clone or fetch has put every item in place, and after every item is measured and hashed (FR-009);
2. `date -u` gives `synced_at`;
3. the renderer writes `.manifest.json.tmp`;
4. `mv -f` renames it to `.manifest.json`, replacing any earlier one (FR-008).

The agent's file tool no longer writes the manifest (FR-001).
This revises 007 research § 7 for the manifest only; the index stays agent-written (FR-019).

`.manifest.json.tmp` exists only between steps 3 and 4.
Its name does not end in `.md`, so it is never an item (D6).
No reader opens it, and the next record run writes over one that an interrupted run left behind.

### Validation rules

- Whole or absent: no reader ever sees a partly written `.manifest.json` (FR-008).
- Its mtime still marks the moment the cache became valid, and the freshness gate still reads it (FR-009).
- It lists every item, whatever the context budget (FR-003, US1 scenario 3).
- Every name and source value reads back byte for byte through a standard JSON reader; the spike uses Perl's core JSON::PP (FR-004, Assumptions).
- It never holds a size, a skipped item or a key outside the Verbatim Constraints (FR-010).
- A manifest the record run has just written passes the check (FR-007, SC-005).
- A source with no item gets `"item_count": 0` and `"items": []`, and passes (edge case).
- A manifest written by 1.9.1 or earlier passes only if its bytes equal the render; otherwise it fails once and the next successful sync records it again (FR-013, SC-007).
- A 1.3.0 manifest has no `revision` key, so it always takes that one rebuild; the note at sync.md 1028–1032 that it needs no re-sync is rewritten (D7).

### Readers

Readers keep reading it as today (FR-010).
Search takes `items[]` as its corpus, and status shows `synced_at` and `item_count`, each only after the check passes.
The freshness gate reads its mtime.

## Entity 5: Record run and check run

One shell invocation for one source, composed of three blocks of the sync command (D1).
The first two blocks are shared, so both runs see the same items, the same skips and the same renderer.

| | Record run | Check run |
| --- | --- | --- |
| Caller | Sync step 5, after step 4's clone or fetch. | Status step 2, search step 1, sync's two fallbacks and sync step 4's policy-fresh path (D8). |
| Blocks | § Indexable Items → § Item Records → step 6 block. | § Indexable Items → § Item Records → § Cache Integrity Check block. |
| Working directory | `cache/<slug>/`. | `cache/<slug>/`. |
| Inputs | The `url`, `revision`, slug and `path_filter` placeholders. | The same, plus the manifest's `synced_at` line. |
| Writes | `.manifest.json.tmp`, renamed to `.manifest.json`. | No manifest. It deletes nothing. |
| Prints | The run report (Entity 6). | The run report and the integrity verdict (Entity 7). |

### Validation rules

- One invocation per source, whatever the item count: a larger source lengthens the report, not the agent's steps (FR-001, FR-011, edge case).
- No hash passes through the agent (FR-011, US1).
- The runs need git and what a standard macOS or Linux install provides, and no Python, jq or Perl (FR-015, D5).
- `LC_ALL=C` prefixes each text tool and is never exported: the blocks `cd` without a subshell, so an export would reach the agent's later commands (D2).
- A run starts only after the slug matched `^[0-9a-f]{12}$` (007 FR-002).
- No run executes git in a directory without its own `.git`, where git would resolve to the project's own repository (FR-020).

## Entity 6: Run report

The machine-readable lines a run prints for the agent (D10).

| Output | Printed by | Meaning |
| --- | --- | --- |
| `records: <slug> items=<N> bytes=<B> synced_at=<ts>` | Both runs, once. | `N` is the number of `item:` lines and equals `item_count`. `B` is the sum of their sizes. `ts` is the timestamp the record run wrote, or the one the check read. |
| `integrity=pass` or `integrity=fail` | Check run only. | The verdict (Entity 7). |
| `item: <size> <name>` | Both runs, once per item, in byte order. | The size in bytes, then the display form. |
| `link: <name>` | Both runs, once per skipped link. | The display form. |
| `skipped-utf8: <name>` | Both runs, once per name that is not valid UTF-8. | The skipped display form. |

### Validation rules

- Every name is in display form, so no name can break a line, forge another line, or put a raw control byte before the agent (D10, 007 FR-005).
- The report lists every item, whatever the budget (FR-002, FR-003).
- Paths and sizes come only from here: conflict detection, budgeting, the index and the step 9a advisory use them as reported, with no second measurement (FR-002).
- The report is data, not a message: the agent turns it into step 9's lines, and messages stay agent output (D10).

## Entity 7: Integrity verdict

The result of the shared Cache Integrity Check, now a block that ends the check run (FR-011, D7).

| Field | Value |
| --- | --- |
| Values | `pass` or `fail`, printed as `integrity=pass` or `integrity=fail`. |
| Pass when | The manifest exists, its `synced_at` line matches `^  "synced_at": "[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z",$`, and its bytes equal the text the record run would write now, rendered with that timestamp and the current `url`, `revision` and slug. |
| Fail otherwise | For example: an item changed, added or removed; a manifest edited, torn, or written in another layout, as an agent under 1.9.1 or earlier may have written it; a 1.3.0 manifest without `revision`; a `synced_at` in any other form. |
| Comparison | `cmp` of the rendered text with `.manifest.json`. JSON is never parsed: byte equality with the writer's own output proves it valid. |

The render uses the current configuration.
An edit to `path_filter`, or a `url` edit that keeps the slug (letter case, a trailing `.git` or `/`), therefore fails the check until the next sync records the source again.

### What each caller does with it

The check prescribes no action; each caller decides (D7, finding 8).

| Caller | On `pass` | On `fail` |
| --- | --- | --- |
| Sync's two fallbacks: timeout or failure, and all revision tiers failed | The cache is served, as today. | `unreachable`; the source is skipped. |
| Sync step 4, policy-fresh path | `current`: no network, with items and sizes from the report (D8). | Stale: the source is refreshed. |
| Status step 2 | `fresh` or `cached` by policy, as today. | `corrupted`. |
| Search step 1 | The source's `items[]` join the corpus. | The source is set aside for this search. |

### Validation rules

- One run per source gives the verdict; the agent compares no hash (FR-011, US3 scenario 1).
- A manifest the record run has just written passes by construction, so recording and checking cannot loop (FR-007, US3 scenario 3).
- It never passes with records that do not match their files (FR-013).
- All four callers reach the one block by reference; none holds a copy (FR-012).
- The check deletes and rewrites nothing, so status stays read-only (finding 8).

## Entity 8: Knowledge index

`knowledge-index.md` keeps its format, path and writer (FR-014, Verbatim Constraints).
The agent writes it with its file tool from the run reports, never through a shell (FR-019).

### Relationships

- Per source, the index lists the report's `item:` lines within budget, or all of them when no budget is in effect.
- Withheld items are the report's items minus the indexed ones, with names written the same way in both (D10).
- A policy-fresh source contributes the items and sizes of its check run's report (D8).
- A skipped item is never listed (FR-006).
- Budget allocation, conflict handling and messages are unchanged (FR-014).

## Entity 9: Hostile-name set

The fixture recorded by the new `--records` group of `.github/scripts/test-sync-git.sh`, which the spike runs as its own test (FR-017, research Spike).

| Member | Expected record |
| --- | --- |
| `$(touch pwned).md` | Recorded literally; no marker file. |
| `-option.md` | Recorded literally; never read as an option. |
| Today's directory names that hold a line feed | Left out; no path outside the source, no phantom, no duplicate. |
| A name holding `"` | Recorded as `\"`; reads back unchanged. |
| A name holding `\` | Recorded as `\\`; reads back unchanged. |
| Names holding, between them, every control character from U+0001 to U+001F except line feed | Recorded with `\b`, `\f`, `\r`, `\t` or `\u00XX`; each reads back unchanged. A file name cannot hold U+0000. |
| A name that is not valid UTF-8 | Left out, with a `skipped-utf8:` line showing each invalid byte as `\xHH`. Linux setups only (finding 7). |
| `guía.md` | Recorded as is (edge case, beyond FR-017). |

Every setup confirms that JSON::PP reads the manifest, that every name reads back byte for byte, that no marker file exists, that the manifest passes the check, and that the records match across shells and platforms (US2, SC-005, SC-006).
The new `--recovery` group covers FR-020 and FR-021.

## State transitions

### Freshness gate, sync step 4

| Effective policy | Manifest | `--force` | Verdict |
| --- | --- | --- | --- |
| None | Any | Any | Stale, as today. |
| Set | Missing | Any | Stale. Before this feature it read fresh (FR-021, finding 2). |
| Set | Older than the policy | Any | Stale. |
| Set | Within the policy | Passed | Stale. |
| Set | Within the policy | Not passed | Policy-fresh, pending the check run: `pass` keeps it `current`, `fail` makes it stale (FR-012, D8). |

### Path choice, sync step 4

| `cache/<slug>/` | Holds `.git` and `.manifest.json` | Path |
| --- | --- | --- |
| Absent | none | Cold. |
| Present | Both | Warm. |
| Present | Not both | Interrupted: remove the directory, then cold (FR-020, D9). |

### Cache directory states

The states of one source's cache directory, from plan.md "States".

| State | Definition | Status shows | Search |
| --- | --- | --- | --- |
| Absent | No `cache/<slug>/`. | `not synced` | No usable manifest. |
| Interrupted | `cache/<slug>/` without `.git` or without `.manifest.json`. | `not synced`; `corrupted` when a manifest exists without `.git`. | No usable manifest. |
| Recorded | The record run wrote `.manifest.json`, and the check passes. | `fresh` or `cached`, by policy. | In the corpus. |
| Policy-fresh | Recorded, with the manifest younger than the effective `max_cache_age`. | As Recorded. | As Recorded. |
| Corrupted | `.git` and `.manifest.json` present, and the check fails. | `corrupted` | Set aside. |

| From | Event | To | Sync reports |
| --- | --- | --- | --- |
| Absent | Sync: the clone and the record run succeed. | Recorded | `fresh` |
| Absent | Sync: the clone fails. | Interrupted if a directory remains, else Absent | `unreachable` |
| Absent | Sync stops after the clone, before the rename. | Interrupted | none |
| Interrupted | Any sync: the gate reads stale and step 4 removes the directory. | Absent, then as the rows above | as above |
| Recorded | Sync, gate stale: the fetch and the record run succeed. | Recorded, with a new manifest | `fresh` |
| Recorded | Sync, gate stale: the fetch fails and the check passes. | Recorded, unchanged | `cached` |
| Recorded | Sync, gate stale: the fetch fails and the check fails. | Corrupted | `unreachable` |
| Recorded | Sync stops after the checkout, before the rename. | Corrupted if any item changed; otherwise Recorded, since the old manifest still matches | none |
| Recorded or Policy-fresh | An item is changed, added or removed, or the manifest is edited. | Corrupted, seen at the next check | none |
| Policy-fresh | Sync without `--force`: the check passes. | Policy-fresh, untouched | `current` |
| Policy-fresh | Sync without `--force`: the check fails. | Treated as stale: the Recorded rows apply | as above |
| Policy-fresh | The manifest ages past the policy. | Recorded | none |
| Corrupted | Sync: the fetch and the record run succeed. | Recorded | `fresh` |
| Corrupted | Sync: the fetch fails. | Corrupted | `unreachable` |
| Any, with a manifest from 1.9.1 or earlier | The first check. | Recorded if its bytes equal the render, else Corrupted | none |

### Guards

- A missing manifest is stale, never fresh (FR-021).
- Step 4 removes a directory only through a slug that matched `^[0-9a-f]{12}$` (D9, 007 FR-002).
- No git command runs in a directory without its own `.git`; there the check never passes, and no command reaches the project's own repository (FR-020, edge case).
- `current` requires a passing check, so a policy-fresh source whose files no longer match is refreshed (FR-012, finding 9).
- Only sync moves a directory between states; status and the check only read (finding 8).
- An older manifest costs at most one rebuild: once recorded again, it passes (SC-007).
- Running sync again completes a sync that stopped part-way: recorded sources pass or are refreshed, and the rest are Absent or Interrupted and take the cold path (FR-018, US4 scenario 2).

## Records outside the runtime

| Record | Change | Req |
| --- | --- | --- |
| `extension.yml` | `version` moves from `1.9.1` to `1.10.0`; it still declares only git. | D11, FR-015 |
| `README.md` | Version badge and install URL at `v1.10.0`. Troubleshooting states that the first sync after an upgrade rebuilds every source, and that running sync again completes one that stopped. | D11, FR-018 |
| `commands/speckit.knowledge.sync.md` | States the same two facts. | FR-018 |
| `CHANGELOG.md` | A `[1.10.0]` entry. | D11 |
| `specs/007-shell-safe-config/research.md` § 7 | Notes the revision by 011: the record run writes the manifest, and the agent still writes the index. | FR-019 |
