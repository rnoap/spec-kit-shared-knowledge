# Contract: The automated sync checks

**Feature**: [../batch-corpus-measurement.spec.md](../batch-corpus-measurement.spec.md) · **Plan**: [../plan.md](../plan.md) · **Research**: [../research.md](../research.md) · **Data model**: [../data-model.md](../data-model.md)

`.github/scripts/test-sync-git.sh`: the automated sync checks that carry the hostile-name coverage.
It runs as it does today: offline, writing only to a scratch directory, one `PASS` or `FAIL` line per check, and exit 0 when every check passes.
No CI workflow runs it (clarification 2).
The maintainer runs the matrix of § 4 by hand for the spike and again before release, and records the results in the pull request (SC-006).

---

## 1. Groups

| Invocation | Runs |
| --- | --- |
| `bash .github/scripts/test-sync-git.sh` | Every group, the two new ones included |
| `bash .github/scripts/test-sync-git.sh --records` | Record and check runs over the hostile-name set (§ 2). The spike runs this group |
| `bash .github/scripts/test-sync-git.sh --recovery` | The freshness gate and step 4's path choice (§ 3) |
| `--slugs`, `--hostile-values`, `--hostile-files`, `--local-space` | Unchanged |

- The 229 checks that pass today still pass on every setup, and the new checks join them (SC-006).
- The existing groups read the blocks under `### Indexable Items` and `### Corpus Measurement` by anchor. A change to either block updates those groups in the same commit.

---

## 2. The `--records` group

### 2.1 Running a composition

- The harness fills the blocks of a run ([commands.md § 2](./commands.md#2-the-blocks)) with `render()`, joins them in order into one script, and runs that script in one shell. It does not give each block its own subshell, as `run()` does: `$items`, `$links` and the working directory must carry from block to block.
- Each script runs under `sh`, `bash` and `zsh`, and under `dash` where it is installed. A shell FR-016 names that is missing from `PATH` fails the group, naming it.
- Each script runs once per awk installed among the system `awk`, `mawk` and `gawk`, each put first on `PATH` as `awk`.
- The group runs under a UTF-8 locale where one is installed, since no block may depend on the locale (finding 3).

### 2.2 The hostile-name set

One source, committed to a scratch repository and taken through the local cold path, as today's hostile checks are.
It holds today's hostile names, every character JSON must escape, and names that are not valid UTF-8 (FR-017):

| # | Kind | Names | Expected |
| --- | --- | --- | --- |
| 1 | Command substitution | `$(touch pwned).md` | Recorded literally; no marker file |
| 2 | Leading dash | `-option.md` | Recorded, measured and hashed as content, never read as an option |
| 3 | Line feed | Today's directories named `relative`, a line feed, `..`, and `absolute`, a line feed, each holding `escape.md` | Left out with no report line; no `..` segment, no leading `/`, no content from outside the cache |
| 4 | Double quote | `quote".md` | `\"` in the manifest; `"` in the report |
| 5 | Backslash | `back\slash.md` | `\\` in the manifest and in the report |
| 6 | Control characters | Names holding, between them, every byte from 01 to 1F except 0A | `\b`, `\f`, `\r`, `\t` or `\u00XX` in the manifest; § Values in messages in the report |
| 7 | Other controls (US2 scenario 2) | A name holding byte 7F, and one holding U+0085, bytes C2 85 | As is in the manifest; `\x7F` and `\x85` in the report |
| 8 | Valid non-ASCII | `guía.md` | Recorded as is, not skipped |
| 9 | Not valid UTF-8 | `caf\xE9.md` | Left out; `skipped-utf8: caf\xE9.md` |
| 10 | Strict UTF-8 | Bytes C0 AF, ED A0 80, F4 90 80 80, 80, and E2 82, each followed by `.md` | Left out; shown as `\xC0\xAF.md`, `\xED\xA0\x80.md`, `\xF4\x90\x80\x80.md`, `\x80.md` and `\xE2\x82.md` |
| 11 | Links | Symbolic links whose names hold `"`, `\` and a tab | `link:` lines only; never items (finding 4) |
| 12 | Source values | The record run filled with each of [007's eight seeds](../../007-shell-safe-config/contracts/ci.md#32-seeds) as `<url>` and as `<revision>`, then with an empty `<revision>` | No marker file; `source_url` and `revision` decode to the seed byte for byte; `revision` is `null` when empty |

Rows 9 and 10 run on Linux only, because APFS refuses those names (finding 7).

### 2.3 Assertions

For every composition, under every shell and awk:

| Check | Passes when |
| --- | --- |
| Valid JSON | Perl's core `JSON::PP` decodes the manifest |
| Names unchanged | Every decoded `path`, encoded back to UTF-8, equals a name on disk byte for byte, and every item on disk has exactly one record |
| Hashes and sizes | Each `sha256` matches `sha256sum` or `shasum -a 256` of its file; each `item:` size is the file's byte count; `bytes=` is their sum |
| Canonical text | The manifest has the layout of [manifest.schema.md § 2](./manifest.schema.md#2-canonical-text), with items in byte order |
| No marker | No `pwned` or `MARKER` file exists in the scratch directory, the project or the cache |
| Skipped names | Each name of rows 9 and 10 is in neither the manifest nor the `item:` lines, and has one `skipped-utf8:` line in the expected form |
| Nothing disappears | Every line of `$items` gives exactly one `item:` or `skipped-utf8:` line |
| Passes after recording | A check run right after the record run prints `integrity=pass` (FR-007, SC-005) |
| Fails on change | After one byte of one item changes, after an item is added, and after one is removed, the check prints `integrity=fail` (US3) |
| Fails on another layout | The same records re-serialized by `JSON::PP`, and a `synced_at` line in any other form, give `integrity=fail` (FR-013) |
| Same records | The manifests written under each shell and awk on one setup are identical apart from the `synced_at` line (US2 scenario 4) |
| Whole or absent | No `.manifest.json.tmp` remains after a record run, and one planted beforehand is written over and never recorded (FR-008) |
| Empty source | With no item: `"items": []`, `item_count` `0`, and the check passes |

- Each setup compares every record with the file on disk, so the records of the names two setups share are equal across setups.
- The harness reads manifests with `JSON::PP`; the extension never does. The Linux setups install `perl`, not only `perl-base`, which lacks it ([007 contracts/ci.md § 3.4](../../007-shell-safe-config/contracts/ci.md#34-linux-run)).

---

## 3. The `--recovery` group

The project directory of this group is itself a git repository, so a git command that escaped a cache would act on it (finding 1).
Its slugs are 12 lowercase hex characters.

| Case | Setup | Passes when |
| --- | --- | --- |
| Failed clone | The cold path against an unreachable `url`, leaving `cache/<slug>/` empty; then the path choice, the cold path and the record run against a reachable one | The path choice prints `cold` and removes the directory, and the new manifest passes the check. The project's repository is unchanged: same `HEAD`, no `FETCH_HEAD`, no sparse-checkout setting, same work tree |
| Clone without manifest | A clone whose record run never ran | `cold`; then recorded afresh, and the check passes |
| Manifest without `.git` | A recorded cache with its `.git` removed | `cold`, as above |
| Intact cache | A recorded cache | `warm` |
| Missing manifest under a policy | `max_cache_age` set and no `.manifest.json` | The freshness gate's `verdict` is `stale` (FR-021) |
| Manifest within, then past, the policy | `max_cache_age` set; the manifest's mtime inside it, then outside it | `fresh`, then `stale` |
| Re-run completes | Three sources: one recorded, two interrupted (US4 scenario 2) | After the path choice, the clone or fetch and the record run for each, all three pass the check |

---

## 4. The spike and the release run

The spike is the first task of the work and gates the rest.
It runs `--records` on each setup ([research, Spike](../research.md#spike)), so the spike's code is the feature's test:

| Setup | Where |
| --- | --- |
| BSD awk 20200816; `sh` (bash 3.2 in POSIX mode), `dash`, `bash`, `zsh`; git 2.54 | The maintainer's Mac |
| mawk (Ubuntu's default), gawk; `dash`, `bash`, `zsh`; git 2.25; GNU grep and sed; ext4 | Ubuntu 20.04 in podman, following 007 `contracts/ci.md` §3, inside the container's own file system |
| gawk; current git | A current Ubuntu image in podman |

A container row runs after `podman machine start`, from the repository root, which must lie under `$HOME`:

```bash
podman run --rm -v "$PWD":/w -w /w docker.io/library/ubuntu:20.04 sh -c 'apt-get update -qq && apt-get install -yqq git perl procps zsh gawk && bash .github/scripts/test-sync-git.sh --records'
```

The current-Ubuntu row runs the same command with a current image.
The scratch directory stays in the container's own `/tmp`, so names that are not valid UTF-8 can exist there.

- **Pass**: the hostile names produce manifests that `JSON::PP` reads, names round-trip byte for byte, no marker file appears, and names that are not valid UTF-8 are skipped and shown as `\xHH`. That last check runs on the Linux rows only.
- **A local cell fails**: work stops and returns to shape, where the fallback is Option B plus the documentation of Story 4, with Option D reopened.
- **A container cell cannot run here**, for want of an image or a registry: it is recorded as pending for the maintainer's run by hand before release.
- **A `printf "%c"` cell fails**, writing bytes 128 to 255 altered under `LC_ALL=C`: research D5 names the fallback, an ASCII-only manifest with `\uXXXX` escapes for every non-ASCII character. Taking it changes [manifest.schema.md § 3](./manifest.schema.md#3-strings).

Before release, the full run, `bash .github/scripts/test-sync-git.sh` with no flag, passes on every setup, and the pull request records each setup's result (SC-006).

---

## 5. Not covered here

- The one-turn outcome (SC-001 to SC-004): a cold sync of the reference corpus, `lookapp` as of 2026-10-26, on GPT-6 Luna and Claude Opus 5.5 in Copilot in VS Code, judged from the agent's own report. Each run ends with every source passing the check (SC-005). Before this ships, a cold run of 1.9.1 on each model is recorded with its full transcript.
- That `knowledge-index.md` leaves out a skipped name: the agent writes the index, so the group checks the `item:` lines the index is written from.
- The README and command text of FR-018: checked in review.
