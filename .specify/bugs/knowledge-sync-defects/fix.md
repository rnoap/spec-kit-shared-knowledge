# Bug Fix: Sync serves the wrong revision, keeps deleted files, fails on macOS, and follows symlinks

- **Slug**: knowledge-sync-defects
- **Fixed**: 2026-10-14
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

All four sync defects are fixed in the command files themselves:

- **D1:** a full-SHA pin now moves HEAD with `git update-ref`.
- **D2:** the warm path runs `git checkout --force --detach <ref>`.
- **D3:** every network call goes through one bounded-call function that works on stock macOS.
- **D4:** symbolic links are written as plain files and never indexed.

As requested, the change also stops warm syncs from writing files outside `path_filter`, and adds the missing `--` to `status.md:128`, the line task T011 of 006 targets. A new script runs the commands' own bash blocks against throwaway repositories. It passes on the fixed files and fails 24 checks on the pre-fix files.

## Changes

| File | Change | Notes |
| --- | --- | --- |
| `commands/speckit.knowledge.sync.md` | modified | New § Bounded Network Call (`with_timeout`) and § Indexable Items. The Cache Integrity Check counts items by the same rule. Tier 2 uses `update-ref --no-deref HEAD FETCH_HEAD`, Tier 3 uses `update-ref --no-deref -- HEAD <revision>`. All three clones pass `-c core.symlinks=false`. The warm path runs `git config core.symlinks false` and `checkout --quiet --force --detach`. Step 5 uses the item rule, step 9 names skipped links, and there are two new error-case rows. |
| `commands/speckit.knowledge.status.md` | modified | L16 references Bounded Network Call. L128 is now `with_timeout 5 git ls-remote --exit-code -- <url> HEAD`. |
| `README.md` | modified | Prerequisites name the timeout tools. The trust model has a time-bound row and a new symlink-defense row, and the "Symlink following" exposure is removed. |
| `config-template.yml` | modified | Security block item 3 (symlink following) removed. |
| `CHANGELOG.md` | modified | `[Unreleased]`: three Fixed entries and one Security entry. |
| `.github/scripts/test-sync-git.sh` | added test | Offline regression script that runs the command files' own bash blocks. Not wired into CI (see Deviations, item 4). |

The Configuration Validation Rules blocks are untouched, so the three copies stay byte-identical (Quality Gate §11).

## Diff Highlights

Tiers 2 and 3:

```bash
with_timeout 10 git fetch --depth=1 origin -- <revision>
git update-ref --no-deref HEAD FETCH_HEAD          # Tier 2
with_timeout 30 git fetch --unshallow origin
git update-ref --no-deref -- HEAD <revision>       # Tier 3: here FETCH_HEAD is the default tip
```

The warm path, remote and local alike:

```bash
git config core.symlinks false
git checkout --quiet --force --detach origin/HEAD   # or FETCH_HEAD when a revision is pinned
```

The `perl` fallback in `with_timeout`. It runs the command in its own process group. When the bound expires it sends TERM, then KILL one second later, and exits 124:

```perl
if (!$pid) { setpgrp(0, 0); exec { $ARGV[0] } @ARGV or exit 127 }
$SIG{ALRM} = sub { kill "TERM", -$pid; sleep 1; kill "KILL", -$pid; waitpid $pid, 0; exit 124 };
```

Indexable items: regular files that git does not record as links (mode `120000`):

```bash
links=$(git -c core.quotePath=false ls-files -s -- <dirs> | awk -F '\t' '$1 ~ /^120000 / { print $2 }')
items=$(find <dirs> -name .git -prune -o -type f -name '*.md' -print 2>/dev/null | sed 's|^\./||' | grep -vxF -e "$links")
```

## Tests Added or Updated

All checks below are in `.github/scripts/test-sync-git.sh`. It runs each bash block from the command files with placeholders filled in, so a regression in the prose fails the script.

- **D1:**
  - Tier 1 cannot clone a SHA, so the sync escalates to Tier 2.
  - Tier 2, with and without `path_filter`: HEAD and content are the pin's.
  - Tier 3, against a protocol-v0 server that refuses unadvertised objects: HEAD and content are the pin's.
  - A pin outside the fetched history makes Tier 3 fail, so the source is reported unreachable.
- **D2:**
  - Warm sync with `path_filter`: the deleted file is removed, the changed file is updated, new files outside the filter are not written, `.manifest.json` survives, and HEAD is the new tip.
  - The local-path warm sync works the same way.
  - A cache built by the old Tier 2, which held the default branch, converges to the pin.
- **D3:**
  - No command calls `timeout` directly, and `with_timeout` is defined.
  - `status` reaches a reachable remote.
  - The `perl` fallback, forced through a restricted `PATH`:
    - returns 0 on success;
    - passes exit code 2 through;
    - returns 127 for a command that cannot run;
    - cuts off a TCP tarpit with 124 within the bound plus 1 s;
    - leaves no orphaned transport helper.
  - With no timeout tool at all, the call still runs and one warning says so.
- **D4:**
  - Links are checked out as plain files.
  - Items exclude file links, directory links, and relative links. The relative link targets the project's `.env`.
  - Every link is reported.
  - A cache cloned before the fix still holds real links, and none of them becomes an item.
  - Reading every item reveals no secret from outside the cache.

## Local Verification

Environment: macOS 26.7.1, git 2.54.0 (Apple Git-157), bash 3.2.57. There is no `timeout` on this machine, so the default path is the `perl` fallback.

- `bash .github/scripts/test-sync-git.sh` → 35 checks passed. `/bin/bash` (3.2) gives the same result.
- Mutation check: the same script against `main`'s `sync.md` and `status.md` → 24 failed, 11 passed. Every defect is detected.
- `bash .github/scripts/validate-extension.sh` → 13 checks passed.
- Linux run (2026-10-15), in `ubuntu:20.04` under Podman with git 2.25.1 and GNU `timeout` 8.30: all checks passed, with `with_timeout` taking its `timeout` branch.
  - That run showed `git sparse-checkout reapply` does not exist in git 2.25 (exit 129). The warm path dropped it, and the script gained two checks, bringing it to 38: the warm sparse step exits 0, and a cone-mode cache loses its stray root files.
  - 38/38 pass on both git versions. Against the previous `sync.md` on 2.25, the new step check fails.
- Not run: a real agent-driven `/speckit.knowledge.sync` and `status` run in a consumer project. That is the job of `/speckit-bug-test`.

## Deviations from Assessment

1. **D2 uses the assessment's alternative, `git checkout --force --detach <ref>`, instead of the preferred `--no-overlay`.** The user asked for it. It also fixes the assessment's out-of-scope finding: warm syncs wrote files added upstream outside `path_filter`. This is a scope expansion. Verified: `.manifest.json` and other untracked files survive.
2. **`status.md:128` also gains `--`.** This is 006's FR-012 / T011, included at the user's request so the two branches don't conflict on that line. Scope expansion.
3. **D3 uses the process-group fallback, the assessment's alternative, with three hardening changes:**
   - `exec { $ARGV[0] } @ARGV` never goes through a shell.
   - TERM, then KILL after 1 s, gives `git` a chance to clean up a half-written clone, as GNU `timeout` does.
   - `alarm 0` after `waitpid` stops a late alarm from turning a success into 124.
4. **The tests are a local script, not a CI job.** The constitution (§ Quality Gates, "CI guards the package, not the prose") says CI does not test command behavior, so wiring the script into CI needs an amendment. The recommendation is under Open Questions 6.

## Open Questions — resolved

The six `[NEEDS CLARIFICATION]` items from the assessment, each with the recommended solution and whether it was applied:

1. **None of `timeout`, `gtimeout` and `perl` exists.**
   - **Applied:** the call runs unbounded and sync prints one warning.
   - Failing the source would recreate D3's total loss of knowledge over a missing safeguard, against the FR-027 stance of degrading rather than failing.
   - The case is also nearly unreachable: Linux has coreutils, macOS has `perl`, and Git for Windows ships both.
2. **Which `perl` fallback.**
   - **Applied:** the process-group variant (Deviations, item 3).
   - It matches GNU `timeout` (exit 124, kills the whole process group). The one-liner leaves helpers connected to a hung host, and four automatic hooks per feature cycle would accumulate them.
3. **Fold in the out-of-filter warm write?**
   - **Applied, as the user decided:** `checkout --force --detach` fixes it together with D2.
4. **Where to report skipped links.**
   - **Applied:** only in sync output, as one line under the source's status line.
   - `.manifest.json` and its three readers (status, search, the integrity check) stay unchanged.
   - Revisit if users want links shown in `status --verbose`.
5. **One PR or two.**
   - **Recommended:** one PR from `fix/knowledge-sync-defects` into `main`, merged before 006.
   - The fixes share the same blocks. Each clone line carries both the bounded call and `core.symlinks=false`, and the warm block carries D2, D3 and D4. Splitting them would make the change conflict with itself.
   - 006 already plans a single release for all of it (`catalog-readiness.spec.md:150`).
6. **git 2.25, the declared minimum.**
   - **Run on 2026-10-15:** the script passes in `ubuntu:20.04` (git 2.25.1). This Mac has Podman, not Docker:

     ```bash
     podman run --rm -v "$PWD":/w -w /w docker.io/library/ubuntu:20.04 sh -c \
       'apt-get update -qq && apt-get install -yqq git perl procps >/dev/null && bash .github/scripts/test-sync-git.sh'
     ```

   - **Still recommended:** add the script to CI through a `docs:` amendment to the constitution's § Quality Gates.
     - Jobs: `ubuntu-latest`, `macos-latest` (the runner without GNU `timeout`), and the `ubuntu:20.04` container.
     - Put it in a new workflow file so it cannot conflict with 006's edits to `validate.yml`.
     - It adds no required check name.

## Follow-ups

- **Merge with 006-catalog-readiness (resolved 2026-10-15).** 006 merged first as PR #8, and this branch was rebased onto it.
  - `status.md:128`: 006 had already added the `--` (T011). The merged line keeps it and adds `with_timeout`: `with_timeout 5 git ls-remote --exit-code -- <url> HEAD`.
  - README Prerequisites: 006's floor (`>=0.15.2`) and platform line are kept, with the timeout-tool line added. The platform line's macOS claim is now true.
  - `CHANGELOG.md` `[Unreleased]`: the three Fixed entries join 006's Fixed section, and Security follows it. The D3 entry no longer mentions the `status` separator, because 006's `fix(status): separate the source URL with --` entry records it.
  - 006's `contracts/commands.md:107-112` still describes the wrapper as `timeout 5`. That is a historical spec, so it is left unchanged.
  - The macOS status check that 006 requires before publication (`tasks.md:195`) is now unblocked.
- **git-floor issue (fixed 2026-10-15):** the warm path's `git sparse-checkout reapply` does not exist in git 2.25 and exited 129 there. It was removed, because `sparse-checkout set` already updates the working tree.
- **Upgrade note for users:** run `/speckit.knowledge.sync --force` once after upgrading. It heals SHA-pinned caches that hold default-branch content and prunes files deleted upstream. Manifests that list a link are rebuilt the first time the integrity check runs.
- **Commits:** three, because the four fixes share the same lines and cannot be split per defect:
  - `fix(sync): repair SHA pins, deletions, timeouts and links`
  - `test(sync): run the commands' git blocks against fixtures`
  - `docs(bugs): record the knowledge-sync-defects fix`
