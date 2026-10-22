# Bug Verification: A source without `path_filter` caches the whole repository, including `.specify/` and other tool directories

- **Slug**: remote-cache-copies-all-files
- **Tested**: 2026-10-22
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified

## Summary

The symptom no longer reproduces on the reporter's real repository content (`ending-inventory-ui`, 395 tracked files):

- **Before the fix:** the cache got 395 files, 310 of them not `.md`, including `.specify/`.
- **After the fix:** it gets 50 files, all `.md`, with no dot-directories or agent files.

A copy of the reporter's existing full cache self-heals to the same 50 files on a warm sync. A filtered source caches only its `.md` files. No regressions: the sync suite, the validator, and the install smoke test all pass.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction, **pre-fix** (control) | `HEAD:commands/speckit.knowledge.sync.md` blocks, local-path cold clone + "If no `path_filter`" | pass (bug reproduces) | 395 files, 310 not `.md`, `.specify/` present. Confirms the scenario triggers the bug. |
| Reproduction, **post-fix** | Same blocks from the working-tree `sync.md`, run verbatim | pass | 50 files, 0 not `.md`, `core.sparseCheckout=true`. Top level is `README.md docs specs`. |
| Indexable Items, post-fix | § Indexable Items block on the new cache | pass | 50 items: `README.md`, 1 under `docs/`, 48 under `specs/`. 0 dot-directory or `AGENTS`/`CLAUDE`/`GEMINI` items. The reporter had 85. |
| Self-heal, reporter cache with an up-to-date index | Copy of `lookapp/.../cache/2adeb1e07c4f`, `update-index --refresh`, warm sparse block, then `checkout --force --detach` | pass | 396 → 50 files. `.specify/` and `.wibey/` gone. `.manifest.json` kept. No warnings. |
| Self-heal, stale index (copied or restored cache) | Copy without refresh, warm sparse block, then `checkout --force --detach` | pass | The sparse step leaves the files with a "not up to date" warning. The same sync's `checkout --force --detach` prunes to 50. |
| Indexing an un-healed full cache (unreachable fallback) | § Indexable Items on an untouched copy of the reporter's cache | pass | 50 items: the exclusions hold even before pruning. |
| Filtered source (D4) | Reporter's local `LOOKAPP-api-store-visibility` with `specs/` → `'specs/**/*.md'` | pass | 30 files, all `.md`, top level `specs` only. |
| New and updated tests | `bash .github/scripts/test-sync-git.sh` (git 2.54.0, macOS) | pass | 229/229, including the 15 "Markdown-only caches" checks and 8 `indexable / FILTER` hostile-value checks. |
| Regression on the minimum git | Same script in `ubuntu:20.04` (git 2.25.1) under Podman | pass (fix phase) | 229/229, recorded in fix.md. Not re-run here because nothing changed since. |
| Mutation check | Old `git checkout HEAD -- .` restored in the no-filter block | pass (fix phase) | 3 new checks fail as expected, recorded in fix.md. |
| Manifest validation | `bash .github/scripts/validate-extension.sh` | pass | 17/17. Needs PyYAML on PATH; I used a temporary venv because the system `python3` lacks it. |
| Install smoke test (CI `smoke` job) | `specify init` + `specify extension add <repo> --dev` + `assert-install.sh` | pass | "Smoke test passed." The installed `sync.md` and `SKILL.md` carry the new default patterns. Same PyYAML note. |
| Agent-driven `/speckit-knowledge-sync` against the real remote | — | skipped | Needs the internal network (`gecgithub01.walmart.com`) and would change the reporter's `lookapp` project. The automated equivalent above runs the same command blocks on the same content. |

## Output Excerpts

```
PRE-FIX cold:  files=395 non-md=310 .specify=yes
POST-FIX cold: files=50  non-md=0   sparse=true   top-level: README.md docs specs
items: 50  (README.md 1, docs/ 1, specs/ 48)   excluded present? 0
A refreshed index: sparse exit=0 files=50 .specify=no warnings=0
B stale index: sparse exit=0 files=395 → after checkout --force --detach: files=50
filtered specs/: files=30 md=30 top=specs
229 checks passed.          (test-sync-git.sh)
17 checks passed.           (validate-extension.sh)
Smoke test passed.          (assert-install.sh)
```

## Residual Risks

- **No agent-driven end-to-end run.** The command is a prompt that an agent executes, and the agent itself must turn `specs/` into `'specs/**/*.md'`. The table and examples in `sync.md` spell this out, but an agent misreading it would cache nothing under the filter (the pattern `specs/` alone still works, so the risk is limited to non-`.md` files). Confirm with a real `/speckit-knowledge-sync` in `lookapp` after updating the installed extension.
- **A stale index produces noisy warnings.** If a cache's index stat data is stale (the cache directory was copied or restored), the warm sparse step prints a long "not up to date … run `git sparse-checkout reapply`" warning. The same sync still converges via `checkout --force --detach`. An agent might be tempted to run `reapply`, which the command forbids because it doesn't exist on git 2.25. Optional hardening: `git update-index -q --refresh` before `sparse-checkout set`.
- **Offline first sync after upgrading.** If the source is unreachable, the Cache Integrity Check fails once, because the item count drops from 85 to 50, and the cache is rebuilt on the next reachable sync. This is a known precedent, noted in fix.md.
- **No CI coverage.** `test-sync-git.sh` still doesn't run in CI, so this coverage is local-only until a workflow runs it.

## Recommendation

Close the bug. The fix is verified on the reporter's real repository content through the exact command blocks, the self-heal of an existing full cache is confirmed, and all suites pass on current git and on git 2.25.

Before closing it out in the field, update the installed extension in `lookapp` and run `/speckit-knowledge-sync` once. Expect `ending-inventory-ui` to drop from 85 to 50 items, and `cache/2adeb1e07c4f` to hold only `README.md`, `docs/`, and `specs/`.
