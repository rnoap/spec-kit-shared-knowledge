# Quickstart: verifying shell-recorded manifests

The automated checks prove the procedures. This walkthrough proves the behavior an agent shows, which no harness can (constitution, § Quality Gates). Run it before tagging 1.10.0 and record the results in the pull request.

## 1. The sync checks, on every setup (SC-005, SC-006)

On this Mac:

```bash
bash .github/scripts/test-sync-git.sh            # the full run, new groups included
bash .github/scripts/test-sync-git.sh --records  # the spike group alone
```

In Ubuntu 20.04 (git 2.25, mawk) and a current Ubuntu (gawk), run the same command inside the container's own file system, never a bind mount from macOS. The recipe is in `specs/007-shell-safe-config/contracts/ci.md` §3. Add `gawk` to its package list for the gawk row. The non-UTF-8 checks run on these rows only.

Record per setup: pass and fail counts, the awk, the shells, and the git version.

## 2. Baseline, before upgrading (assumption in the spec)

In `lookapp`, with 1.9.1 installed, empty `.specify/extensions/knowledge/cache/` and run `/speckit-knowledge-sync` once on each model, GPT-6 Luna and Claude Opus 5.5, in Copilot in VS Code. Keep each full transcript. Record steps, wall time, whether the run finished in one turn, and any departure from the procedure the agent reports. The transcripts answer where the failed run's 23 steps went.

## 3. Cold sync with 1.10.0 (SC-001 to SC-004)

Install 1.10.0 in `lookapp`, which wipes the cache, and repeat step 2 on both models. Each run must:

- finish in one turn, with fewer than 23 steps and under 3m59s;
- write `.manifest.json` for each of the three sources through the record run, with no file-tool write to any manifest;
- write `knowledge-index.md`;
- end with no departure from the procedure reported by the agent.

Then run `/speckit-knowledge-status`: every source shows its item count and no `corrupted` row (SC-005).

## 4. Integrity and recovery (US3, US4)

1. Append one byte to any cached item and run status: that source shows `corrupted`. Run sync: it records the source again and status is clean.
2. Stop a sync after its first source, for example by interrupting the turn, then run sync again: it completes and status is clean (US4 scenario 2).
3. Point one source at a URL that cannot be reached, run sync, then fix the URL and run sync again. The source is cloned afresh. `git -C . status` in `lookapp` shows nothing new, and its HEAD has not moved (US4 scenario 3, FR-020).
4. With `max_cache_age` set, empty the cache and run sync: every source is cloned, none reported `current` (FR-021).

## 5. Documentation (US4 scenario 1)

The README's Troubleshooting section and sync's text both say that the first sync after an upgrade rebuilds every source, and that running sync again completes a sync that stopped part-way.
