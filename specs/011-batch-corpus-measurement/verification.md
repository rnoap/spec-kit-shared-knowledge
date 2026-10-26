# Verification: shell-recorded manifests

Results against the spec's Success Criteria. Automated runs come first. The live runs and the Linux release rows are the maintainer's ([quickstart.md](./quickstart.md)).

## Automated (T020)

Run on 2026-10-26 on macOS 26.7.1 with BSD awk 20200816, git 2.54.0 and JSON::PP 4.06.

| Check | Command | Result |
|---|---|---|
| Packaging gates | `bash .github/scripts/validate-extension.sh` (PyYAML from a throwaway `uv` environment) | 18 of 18 pass. The badge and the CHANGELOG match 1.10.0, the validation blocks stay byte-identical, and every placeholder is single-quoted. |
| Sync checks, full run | `bash .github/scripts/test-sync-git.sh` | 303 of 303 pass, up from 229. New: 16 hostile-value cases for § Item Records, 11 `--recovery` checks, 47 `--records` checks. |
| Records group against the 1.9.1 command text | `--records` with the old `sync.md` | 37 of 47 fail, as they should: the tests detect the missing behavior. |
| Recovery group against the 1.9.1 command text | `--recovery` with the old `sync.md` | 5 of 11 fail, as they should. |
| Linux encoder row | `bash specs/011-batch-corpus-measurement/spike/encoder-crosscheck.sh` | Pass on Ubuntu 20.04 with mawk, dash, GNU grep 3.4 and ext4. See [spike.md](./spike.md). |

- **SC-005**, recording causes zero integrity-check failures: met in the harness. Every manifest the record run writes passes the check under sh, bash, zsh and dash, for the hostile-name set.
- **SC-006**, all sync checks pass on each setup in the matrix: met on macOS and on the mawk row. The full Ubuntu 20.04 row (git 2.25, gawk, zsh) and the current Ubuntu row are pending (T022).

## Live runs (T021, maintainer)

Quickstart §2 and §3: cold syncs of `lookapp` on GPT-6 Luna and Claude Opus 5.5 in Copilot in VS Code. Run 1.9.1 first, as the baseline, then 1.10.0.

| Version | Model | One turn | Steps | Wall time | Departure reported |
|---|---|---|---|---|---|
| 1.9.1 | GPT-6 Luna | | | | |
| 1.9.1 | Claude Opus 5.5 | | | | |
| 1.10.0 | GPT-6 Luna | | | | |
| 1.10.0 | Claude Opus 5.5 | | | | |

Targets: one turn on both models (SC-001), fewer than 23 steps (SC-002), under 3m59s (SC-003), and no reported departure from the procedure (SC-004).

## Walkthrough and Linux release rows (T022, maintainer)

Quickstart §4 and §5 in `lookapp`: integrity, recovery, freshness policy and documentation. Also the full harness on Ubuntu 20.04 (git 2.25, mawk then gawk, zsh) and a current Ubuntu (gawk).

| Item | Result |
|---|---|
| §4.1 a changed byte shows `corrupted`, and the next sync clears it | |
| §4.2 a stopped sync completes on re-run | |
| §4.3 a failed clone is cloned afresh, and the project's HEAD and status are unchanged | |
| §4.4 with `max_cache_age` set, an empty cache clones every source | |
| §5 README and sync state the upgrade rebuild and the re-run | |
| Ubuntu 20.04, full harness | |
| Current Ubuntu, full harness | |
