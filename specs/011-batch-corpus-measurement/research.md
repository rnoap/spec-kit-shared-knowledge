# Research: Shell-recorded manifests

Phase 0 for [plan.md](./plan.md). The spec carries no open `NEEDS CLARIFICATION` marker. The entries below settle the design choices the codebase leaves open.

## Findings that changed the plan

Each was checked against the code. The first two and the APFS behavior were reproduced on 2026-10-26 in a scratch repository under `/tmp`.

1. **A failed clone exposes the project's own repository.** The cold path runs `mkdir -p cache/<slug>` before `git clone`. A failed clone leaves that empty directory behind, and from inside it git resolves to the consuming project. The next sync sees the directory and takes the warm path. That path runs `git sparse-checkout init/set`, `git fetch --depth=1` and `git checkout --force --detach` against the user's project. Fixed by FR-020.
2. **The freshness gate treats a missing manifest as fresh.** `find "$manifest" -mmin +N` prints nothing for a missing file, so the `else` branch says `fresh`. The comment in the code claims the opposite. With `max_cache_age` set, the first sync after an upgrade skips every source. Fixed by FR-021.
3. **The item pipeline depends on the locale.** In a UTF-8 locale, macOS `sed` stops at the first name with an invalid byte ("illegal byte sequence"). Every later item silently disappears, from step 5 and from the check's count alike. GNU grep 3.4 prints "Binary file (standard input) matches" into the item list.
4. **Some symbolic links are not excluded.** `ls-files` C-quotes names holding `"`, `\` or a control character even with `core.quotePath=false`. Such a link never matches its raw `find` line, so the link's text file is indexed.
5. **Line feeds split paths.** The newline-separated list breaks a path that contains a line feed into fragments. A fragment that names a real item duplicates it. Only the test harness has a `[ -f ]` guard; the command has none.
6. **BSD `wc -c` pads its count with spaces**, contrary to § Corpus Measurement.
7. **APFS refuses names that are not valid UTF-8** (`illegal byte sequence`). They occur only on Linux file systems.
8. **The check prescribes an action.** Its step 5 says to discard the directory and sync again. That is wrong for status, which is read-only, and circular in sync's fallback, which marks the source `unreachable`. Status step 2 never runs the full check at all.
9. **The policy-fresh path trusts the manifest unchecked** and has no item sizes for step 7a.

## Decisions

### D1. Three composed blocks, one shell run per source

- **Decision**: § Indexable Items (revised), a new § Item Records, and a tail: the step 6 block for recording, or the § Cache Integrity Check block for checking. The agent runs the three as one shell command.
- **Rationale**: the item rules and the encoder each live in one place, so record and check cannot drift (FR-007), and each run costs the agent one step per source (FR-001, FR-011). The harness already extracts blocks by heading and can concatenate them the same way.
- **Alternatives considered**: one self-contained block per caller, rejected because it duplicates the item rules. A script file under `commands/` was rejected by constitution §I and §III.

### D2. Byte semantics: `LC_ALL=C` on each text tool

- **Decision**: prefix `sed`, `grep`, `sort`, `awk`, `od` and `tr` with `LC_ALL=C` inside the blocks. Do not export it.
- **Rationale**: this fixes finding 3 and gives one byte order on every machine. Exporting it would leak into the agent's later commands, because the blocks already `cd` without a subshell.
- **Alternatives considered**: keeping the user's locale (the bug), or exporting `LC_ALL` (it leaks).

### D3. Paths with a line feed are left out at `find` time

- **Decision**: `find … ! -path "*$nl*"`, with `nl` holding a literal line feed.
- **Rationale**: no fragment ever enters the list (finding 5). A line feed is the one byte a newline-separated list cannot carry, and 007 rejected NUL-separated lists because dash has no `read -d ''`. Leaving such files out matches today's outcome without the phantom and duplicate items.
- **Alternatives considered**: a `[ -f ]` guard plus de-duplication. It still lets a fragment shadow a real item.

### D4. Links come from `ls-files -s -z`, converted with `tr`

- **Decision**: `git -c core.quotePath=false ls-files -s -z -- <dirs> | LC_ALL=C tr '\0' '\n' | awk …`.
- **Rationale**: with `-z` git writes names verbatim, so they match `find`'s output byte for byte (finding 4). `tr` with an octal escape is POSIX. A link name that contains a line feed can only leave a fragment that matches no item, because D3 keeps such paths out of the list.
- **Alternatives considered**: decoding git's C-quoting in awk (complex), or one `ls-files` call per item (N extra git processes).

### D5. The encoder reads hex, not text

- **Decision**: per item, `printf '%s' "$file" | LC_ALL=C od -An -tx1 -v | tr -d ' \n'` yields the name as hex. One awk program turns each `hex size hash` line into three outputs:
  - the manifest's JSON string: `\"`, `\\`, `\b \f \n \r \t`, `\u00XX` for other bytes below 0x20, and everything else raw, including valid UTF-8;
  - the display form of § Values in messages;
  - or, for invalid UTF-8, a skipped entry with each invalid byte shown as `\xHH`.
  It validates UTF-8 strictly: no overlong forms, no surrogates, nothing above U+10FFFF.
- **Rationale**: awk only ever sees hex digits and numbers, so no awk variant can misread a hostile byte. The one portability bet is `printf "%c"` writing bytes 128 to 255 unchanged under `LC_ALL=C`. That holds for BSD awk 20200816, and the spike checks mawk and gawk.
- **Alternatives considered**: an ASCII-only manifest with `\uXXXX` escapes for every non-ASCII character. It is the fallback if a `%c` cell fails, at the cost of agents reading `guía.md`. Python, `jq` and Perl were rejected because the extension declares none of them, and a minimal Ubuntu image lacks JSON::PP.

### D6. Canonical manifest, written atomically

- **Decision**: the layout of today's step 6 example is fixed exactly: two-space indent, one item per line, `"items": []` when empty, items in byte order. `source_url` is the configured `url`, not the expanded local path. `revision` is `null` when empty. `synced_at` comes from `date -u +%Y-%m-%dT%H:%M:%SZ`. The text goes to `.manifest.json.tmp`, then `mv -f` replaces `.manifest.json`.
- **Rationale**: the rename makes the manifest whole or absent (FR-008) and keeps its mtime as the moment the cache became valid (FR-009). The temporary name does not end in `.md`, so it is never an item.
- **Alternatives considered**: writing in place, which can leave a torn manifest that a later run must decode.

### D7. The check renders and compares; callers act

- **Decision**: the check reads only the `synced_at` line of the manifest and requires `^  "synced_at": "[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z",$`. It renders the full text the record run would write with that timestamp and the current `url`, `revision` and slug, then runs `cmp`. It prints `integrity=pass` or `integrity=fail` with the report. Callers decide what failure means:
  - sync's fallbacks mark the source `unreachable`;
  - the policy-fresh path treats it as stale;
  - status shows `corrupted`;
  - search sets the source aside.
- **Rationale**: byte equality with the writer's own output proves valid JSON without a parser, and it cannot loop, because a manifest the record run just wrote passes by construction (FR-007). Each verdict comes from one run (FR-011).
- **Alternatives considered**: parsing JSON in awk, which is a rabbit hole for no gain because only canonical manifests need reading. Matching header lines with patterns is looser than rendering them.
- **Consequence**: a manifest written by an agent under 1.9.1 or earlier fails once and is recorded again at the next successful sync (FR-013). The note at sync.md 1028–1032 that a 1.3.0 manifest needs no re-sync becomes false and is rewritten.

### D8. Every reader of a cache runs the check

- **Decision**: the check runs in status step 2, in search's existing reference, in sync's two fallbacks (the revision fallback and the timeout fallback), and in the policy-fresh path, which also needs the report's sizes for step 7a.
- **Rationale**: findings 8 and 9. The same run gives the verdict and the sizes, so a policy-fresh source costs one step instead of one per item.
- **Alternatives considered**: status keeping its JSON-only test. That contradicts its own definition of `corrupted` and US3.

### D9. Recovery

- **Decision**:
  - The freshness gate reads `stale` when the manifest is missing.
  - Step 4 takes the warm path only when `cache/<slug>/.git` and `cache/<slug>/.manifest.json` both exist. Otherwise it removes the directory, whose slug has already passed `^[0-9a-f]{12}$`, and takes the cold path.
- **Rationale**: findings 1 and 2. A directory with no manifest is by definition an interrupted sync (sync.md 1034–1036), so cloning again is the honest recovery, and it is what makes FR-018's re-run promise true.
- **Alternatives considered**: setting `GIT_CEILING_DIRECTORIES`. It would stop git reaching the project, but an interrupted directory would still never recover.

### D10. Report lines for the agent

- **Decision**: each run prints machine-readable lines:
  - `records: <slug> items=<N> bytes=<B> synced_at=<ts>`, plus `integrity=pass|fail` for a check run;
  - one `item: <size> <display path>` per item;
  - `link: <display path>` for each skipped link;
  - `skipped-utf8: <display path>` for each name that is not valid UTF-8.
  The agent turns them into step 9's lines. Messages stay agent output.
- **Rationale**: FR-002 and FR-006. Display paths are escaped already, so the agent never sees a raw control byte. Withheld items become report items minus indexed items, with names written the same way in both.

### D11. Version 1.10.0

- **Decision**: a minor release.
- **Rationale**: new behavior, the same manifest format, and old manifests fail once and are recorded again, which breaks no consumer.

## Spike

The first task of the work. It runs the new `--records` harness group, so the spike's code is the feature's test.

| Setup | Where |
|---|---|
| BSD awk 20200816; `sh` (bash 3.2 in POSIX mode), `dash`, `bash`, `zsh`; git 2.54 | this Mac |
| mawk (Ubuntu's default), gawk; `dash`, `bash`, `zsh`; git 2.25; GNU grep and sed; ext4 | Ubuntu 20.04 in podman, following 007 `contracts/ci.md` §3, inside the container's own file system |
| gawk; current git | a current Ubuntu image in podman |

- **Pass criteria**: the spec's criteria. Hostile names produce manifests that JSON::PP reads, names round-trip byte for byte, no marker file appears, and names that are not valid UTF-8 are skipped and shown as `\xHH`. That last check runs on the Linux rows only (finding 7).
- **If a cell fails**:
  - A local cell: stop and return to shape.
  - A container cell that cannot run here, for want of an image or a registry: record it as pending for the maintainer's run by hand before release (SC-006).
