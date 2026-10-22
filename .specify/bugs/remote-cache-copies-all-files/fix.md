# Bug Fix: A source without `path_filter` caches the whole repository, including `.specify/` and other tool directories

- **Slug**: remote-cache-copies-all-files
- **Fixed**: 2026-10-22
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

Every source now uses a no-cone sparse checkout whose patterns match only `.md` files.

- **No `path_filter`:** the cache gets default patterns that leave out root-level dot-directories and `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` (D1, D2).
- **With a `path_filter`:** each entry becomes `<dir>/**/*.md` and is honored as written (D3, D4).
- **Warm path:** it always re-applies the patterns, so existing full caches self-heal on their next sync.
- **§ Indexable Items:** the item list applies the same no-filter exclusions.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `commands/speckit.knowledge.sync.md` | modified | Cold path: a **Sparse patterns** table, `<dir>/**/*.md` normalization, and the "If no `path_filter`" block now runs the default sparse set instead of `git checkout HEAD -- .`. A "Why these exclusions" note. Warm path: `init --no-cone` always runs, then `set` with the filter or default patterns. § Indexable Items: no-filter exclusions on `$items`. Index header: `all .md files (default exclusions)`. Step 5 and the "Move HEAD" note reworded. |
| `.github/scripts/test-sync-git.sh` | modified | `SPARSE` anchor moved to the new "With a `path_filter`:" line. Filtered scenarios pass the normalized `'docs/**/*.md'`. New hostile-value case `indexable / FILTER` (8 checks). New section "Markdown-only caches" (15 checks). |
| `commands/speckit.knowledge.configure.md` | modified | No-filter wording names the default exclusions. |
| `config-template.yml` | modified | Header comment and Example 2 describe the exclusions, filters honored as written, and `.md`-only caching. |
| `README.md` | modified | Configure examples and the `path_filter` reference describe D1–D4. |
| `specs/004-source-lifecycle-cache/contracts/knowledge-config.schema.md` | modified | Meaning of an absent or present `path_filter` amended, with a date and bug reference. |
| `specs/004-source-lifecycle-cache/data-model.md` | modified | Same amendment. |
| `CHANGELOG.md` | modified | `[Unreleased]`: a `Fixed` entry and a `Changed` entry for the behavior change. |

## Diff Highlights

The cold no-filter block, `commands/speckit.knowledge.sync.md`:

```diff
 If no `path_filter`:
 cd .specify/extensions/knowledge/cache/<slug>
-git checkout HEAD -- .
+git sparse-checkout init --no-cone
+git sparse-checkout set -- '*.md' '!/.*/**' '!AGENTS.md' '!CLAUDE.md' '!GEMINI.md'
+git checkout
```

The warm path now always runs; the `if` only picks the patterns:

```bash
git sparse-checkout init --no-cone
if [ -n '<path_filter>' ]; then
  git sparse-checkout set -- '<pattern1>' ['<pattern2>' ...]
else
  git sparse-checkout set -- '*.md' '!/.*/**' '!AGENTS.md' '!CLAUDE.md' '!GEMINI.md'
fi
```

§ Indexable Items:

```bash
if [ -z '<path_filter>' ]; then
  items=$(printf '%s\n' "$items" | grep -vE '^\.[^/]*/|(^|/)(AGENTS|CLAUDE|GEMINI)\.md$')
fi
```

## Tests Added or Updated

All tests are in `.github/scripts/test-sync-git.sh`, section "Markdown-only caches". The fixture holds `.specify/`, `.github/docs/`, `.wibey/`, root `AGENTS.md`, `CLAUDE.md` and `GEMINI.md`, `docs/AGENTS.md`, `docs/a.md`, `docs/diagram.png`, `specs/.drafts/d.md`, `README.md`, `.notes.md`, `package.json`, and `src/app.ts`.

**No `path_filter` (D1, D2):**
- Remote (Tier 1): the cold sparse step exits 0.
- The cache holds exactly `.notes.md README.md docs/a.md specs/.drafts/d.md`.
- `core.sparseCheckout` is `true`.
- The items equal the cached files.
- A local source gets the same default patterns.

**With a `path_filter` (D3, D4):**
- `docs/**/*.md`: only `docs/AGENTS.md` and `docs/a.md` are cached; the `.png` is not.
- `docs/AGENTS.md` is indexed under an explicit filter.
- `.github/docs/**/*.md`: the dot-directory filter is honored as written, in both the cache and the items.

**Self-heal:**
- A full-checkout cache (the old no-filter behavior) starts with `package.json` and `.specify/`.
- Its items already leave out the excluded paths.
- The warm sparse step exits 0.
- The next warm sync prunes it to the default patterns and keeps `.manifest.json`.
- A filtered cache with the old `docs/` pattern loses `docs/diagram.png` on its next warm sync.

**Hostile values:** `indexable / FILTER`, seeds 1–8. No marker is executed, and `[` receives the value byte-exact.

**Updated:** the Tier 2, Tier 3, warm, cone, and symbolic-link scenarios now use `FILTER='docs/**/*.md'` (the normalized pattern). The `tier2` and `legacy` `items_of` calls set `FILTER` explicitly.

## Local Verification

**Commands run:**

- `bash .github/scripts/test-sync-git.sh` on macOS (git 2.54.0): **229/229 pass**. The baseline before the fix was 206/206.
- The same script in `ubuntu:20.04` under Podman (git 2.25.1, the declared minimum): **229/229 pass**.

  ```bash
  podman run --rm -v "$PWD":/w -w /w docker.io/library/ubuntu:20.04 sh -c \
    'apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -yqq git perl procps zsh >/dev/null 2>&1 && bash .github/scripts/test-sync-git.sh'
  ```

- Mutation check: I temporarily restored `git checkout HEAD -- .` in the no-filter block and re-ran. **3 checks fail**: the default-pattern cache contents, sparse mode, and the local source. I then restored the file.
- `bash .github/scripts/validate-extension.sh`: **17/17 pass**. The run needed PyYAML in a temporary venv, because the system `python3` has none. Without it, the script reports "extension.yml is not valid YAML", an environment issue unrelated to this change.

**Manual checks** (assessment phase):

- I confirmed the symptom in the reporter's `lookapp` cache: 396 files, 85 items, 34 of them from `.specify/` and `.wibey/`.
- I confirmed that `!/.*/` and `!/.specify/` exclude nothing in no-cone mode, while `!/.*/**` works.

## Deviations from Assessment

- The test harness's `SPARSE` anchor had to change, because the paragraph it matched was rewritten. This is a test-infrastructure consequence, not a scope change.
- I added a hostile-value case for the new `'<path_filter>'` placeholder in § Indexable Items. The assessment did not list it, but every configuration placeholder in a shell block is already covered this way (007 FR-006).
- In § Indexable Items, the exclusions are applied to `$items` after `find`, as a filter that runs only with no `path_filter`. The assessment suggested a `find -prune`. A prune on the dot-directory could not tell the no-filter start point `./.` apart from an explicit filter such as `.github/docs`, which D3 requires to be honored.
- Configure's example listing output, `(path: all .md files)`, was left unchanged as a short display label. The descriptive text around it was updated.

## Follow-ups

- `test-sync-git.sh` is still not run in CI, an open follow-up from `knowledge-sync-defects`. A workflow with `ubuntu-latest`, `macos-latest`, and an `ubuntu:20.04` container would lock this fix in.
- The reporter's `lookapp` project runs an installed copy of the extension. It needs updating to this version; then the next `/speckit-knowledge-sync` prunes `cache/2adeb1e07c4f` to the default patterns. Expected items for that source: 85 → 50.
  - That first sync rewrites the manifest.
  - If the source is unreachable during that sync, the Cache Integrity Check fails once (the item count changes) and the cache is rebuilt on the next reachable sync. This is the same precedent as the symlink fix.
- Release: bump `extension.yml` `version` and move the `[Unreleased]` entries when publishing.
