# Bug Assessment: A source without `path_filter` caches the whole repository, including `.specify/` and other tool directories

- **Slug**: remote-cache-copies-all-files
- **Created**: 2026-10-22
- **Source**: pasted text + 4 screenshots
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

> porque cuando agregue como source un repo remoto y no le pase que carpetas indexar, en la cache me hizo una copia de otros archivos y carpetas que no son .md. por ejemplo la carpeta ".specify" debería haberla omitido por completo. la otra fuente que es un repo local y tiene como filtro la carpeta specs si hizo bien la cache

The screenshots show:

- `knowledge-config.yml` with two sources. The local `LOOKAPP-api-store-visibility` has `path_filter: specs/`. The remote `https://gecgithub01.walmart.com/Walmart-Tech-Chile/ending-inventory-ui.git` has no `path_filter`.
- The sync reported success: 30 Markdown files for the local source and 85 for the remote one.
- The remote's cache, `cache/2adeb1e07c4f/`, holds the whole repository: `.specify/`, `.wibey/`, `docs/`, `public/`, `specs/`, `src/`, `tests/`, `Dockerfile`, `package.json`, `nginx.conf`, `tsconfig.json`, and more.
- The local source's cache, `cache/237dddd0c79b/`, holds only `specs/`.

## Symptom

**Observed:** for a source with no `path_filter`, sync checks out the whole working tree into the cache. That includes every non-Markdown file and tool directories such as `.specify/` and `.wibey/`. The Markdown files inside those tool directories are also indexed as shared knowledge.

**Expected:** the cache holds only the Markdown knowledge the index can use. Tool directories like `.specify/` are left out completely.

## Reproduction

Confirmed on the reporter's project, `~/Walmart/repos/LookApp repos/lookapp/.specify/extensions/knowledge/`:

1. Add a source with no `path_filter` (remote or local; the transport doesn't matter).
2. Run `/speckit-knowledge-sync`.
3. Inspect `cache/<slug>/`.

Results:

| Cache | `core.sparseCheckout` | Files on disk | `.md` files | Where the `.md` files are |
| --- | --- | --- | --- | --- |
| `237dddd0c79b` (local, `path_filter: specs/`) | `true` (`specs/`) | 31 | 30 | `specs/` 30 |
| `2adeb1e07c4f` (remote, no filter) | unset (`fatal: this worktree is not sparse`) | 396 | 85 | `.specify/` 20, `.wibey/` 14, `specs/` 48, `docs/` 1, `AGENTS.md`, `README.md` |

`knowledge-index.md` (line 42 onward) lists the foreign repo's `.specify/extensions/*/commands/*.md`, `.specify/templates/*.md`, and `.specify/memory/constitution.md` as shared-knowledge items.

The difference isn't remote vs. local. It comes from whether the source has a `path_filter`. A local source without a filter behaves the same way, because it uses the same "If no `path_filter`" block.

## Suspected Code Paths

- `commands/speckit.knowledge.sync.md:747-751`, the cold-path "If no `path_filter`" block. It runs `git checkout HEAD -- .` with no sparse-checkout, so every blob in the tree is downloaded (the `--filter=blob:none` clone fetches them lazily on checkout) and written to disk. This is the direct cause of the non-`.md` files.
- `commands/speckit.knowledge.sync.md:755-765`, the warm path. Sparse-checkout is reapplied only `if [ -n '<path_filter>' ]`. An unfiltered cache therefore stays a full, non-sparse worktree forever, and `checkout --force --detach` (lines 778 and 791) keeps writing the whole tree on every sync.
- `commands/speckit.knowledge.sync.md:286-301`, § Indexable Items. With no filter, the `find` start point is `'./.'`, so every `.md` file anywhere is an item, including `.specify/`, `.wibey/`, `.github/`, `.claude/`, and `.agents/`. This is why foreign tool prompts reach the index.
- `commands/speckit.knowledge.sync.md:347`, the index header's `Path filter: … "all .md files"` wording.
- `specs/004-source-lifecycle-cache/contracts/knowledge-config.schema.md:65` and `specs/004-source-lifecycle-cache/data-model.md:34` define an absent `path_filter` as "every `.md` file in the repository". That makes indexing `.specify/**/*.md` follow the contract, but the contract never asks for non-`.md` files to be materialized.
- `config-template.yml:108`, `commands/speckit.knowledge.configure.md:174`, and `README.md:161` repeat "all .md files" to the user.

## Root Cause Hypothesis

Confidence is **high**: the code and the reporter's cache both show it.

The command handles "no `path_filter`" by turning sparse-checkout off instead of applying a default, Markdown-only pattern set. The filter is the only thing that limits what git writes to the cache, and the indexer limits only what is *listed*, not what is *stored*. With no filter, git materializes the full tree (396 files, including source code, configs, and `.env.example`). The indexer then treats every `.md` file as knowledge, including another project's spec-kit commands, templates, constitution, and agent prompts under `.specify/` and `.wibey/`.

The warm path's `if [ -n '<path_filter>' ]` guard means an existing unfiltered cache never heals.

Two problems are mixed together:

1. **Bug:** non-`.md` files are cached at all.
2. **Contract gap:** "all `.md` files" includes tool directories that are never shared knowledge.

## Proposed Remediation

**Preferred** (applies decisions D1–D4 below): every source, filtered or not, uses a no-cone sparse checkout whose patterns match only `.md` files. A source with no `path_filter` gets a default pattern set instead of a full checkout:

```bash
git sparse-checkout init --no-cone
git sparse-checkout set -- '*.md' '!/.*/**' '!AGENTS.md' '!CLAUDE.md' '!GEMINI.md'
git checkout          # cold path
```

- `*.md` keeps only Markdown files, at any depth.
- `!/.*/**` drops every root-level dot-directory (`.specify/`, `.wibey/`, `.github/`, `.claude/`, `.agents/`, `.vscode/`, …), per D1. Root dotfiles and nested hidden directories are kept.
- `!AGENTS.md`, `!CLAUDE.md`, and `!GEMINI.md` drop agent instruction files at any depth, per D2.

A source **with** a `path_filter` keeps exactly what the user asked for (D3), restricted to Markdown (D4). Each entry is normalized from `<dir>/` to `<dir>/**/*.md`, so `specs/` becomes `'specs/**/*.md'`. None of the default exclusions are added.

I checked this on git 2.54 with two scratch repos:

- **Dot-directories:** a repo containing `.specify/memory/c.md`, `.wibey/x.md`, `.github/p.md`, `specs/a/s.md`, `specs/a/.hidden/h.md`, `docs/d.md`, `README.md`, `.notes.md`, and `package.json` kept `README.md`, `.notes.md`, `docs/d.md`, `specs/a/s.md`, and `specs/a/.hidden/h.md`. `!/.*/`, `!.*/`, and `!/.specify/` exclude **nothing** in no-cone mode; only the `/**` form works.
- **Agent files:** a repo containing root `AGENTS.md` and `CLAUDE.md`, `specs/AGENTS.md`, `.specify/c.md`, `specs/a/s.md`, `docs/d.md`, `README.md`, and `package.json` kept only `README.md`, `docs/d.md`, and `specs/a/s.md` with the full default set.
- **Filtered sources (D3, D4):** with `set -- 'specs/**/*.md' '.github/docs/**/*.md'`, a repo containing `specs/x.md`, `specs/a/s.md`, `specs/a/diagram.png`, `.github/docs/g.md`, and `README.md` kept `specs/x.md`, `specs/a/s.md`, and `.github/docs/g.md`. A `.md` file directly under the filter directory is matched, the `.png` is dropped, and the dot-directory filter is honored.

Running `set` on an existing full clone removed the non-matching files in place, so the warm path can self-heal.

Apply it in four places:

1. **Cold path:** replace the "If no `path_filter`" block (`git checkout HEAD -- .`) with the default sparse block above. This covers Tier 1, Tier 2/3, and local clones, which all fall through to that block. With sparse patterns in place, the `--filter=blob:none` clone downloads only the `.md` blobs, which also cuts bandwidth.
2. **Filtered sparse step (cold and warm):** change the pattern normalization from "ensure trailing slash" to `<dir>/**/*.md` (D4). Update the "Pattern semantics" note accordingly.
3. **Warm path:** remove the `if [ -n '<path_filter>' ]` guard and always run `init --no-cone` plus `set` with either the normalized user patterns or the default set. Existing full caches are then pruned on the next sync without `--force` or a manual delete.
4. **§ Indexable Items:** when there is no filter, apply the same exclusions in `find`: prune root-level dot-directories (for example `-path './.?*' -prune` at depth 1), and skip files named `AGENTS.md`, `CLAUDE.md`, or `GEMINI.md`. The index, the Cache Integrity Check, and the manifest then agree even if a cache was materialized before the fix. The existing `.git` prune is a precedent. With a filter, the `find` stays as it is (D3).

Update the contract and user-facing text from "every `.md` file in the repository" to "every `.md` file outside root-level dot-directories (e.g. `.specify/`, `.github/`), excluding agent instruction files (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`)". Make this change in `data-model.md`, `knowledge-config.schema.md` (004), `config-template.yml`, `configure.md`, `README.md`, and the index header wording. Also document there that an explicit `path_filter` is honored verbatim (D3) and indexes only `.md` files (D4).

**Alternatives**:

The decisions D1–D4 rejected these options:

- **Fix only the non-`.md` files** (`set -- '*.md'`) and keep indexing tool directories. This is the smallest change and keeps the 004 contract word for word. It doesn't address the reporter's main complaint (".specify debería haberla omitido por completo"), and foreign agent commands still reach the index.
- **Use an explicit denylist** (`!/.specify/**`, `!/.wibey/**`, `!/.github/**`, `!/.claude/**`, `!/.agents/**`, …) instead of every root dot-directory. This is narrower, but it needs maintenance as new agent directories appear, and it lets unknown tool directories through.
- **Make `path_filter` required at configure time.** This avoids the default entirely, but it is a breaking change for existing configs and contradicts FR-010-era behavior.

**Files likely to change**:

- `commands/speckit.knowledge.sync.md`: cold no-filter block, filtered pattern normalization and "Pattern semantics" note, warm sparse guard, § Indexable Items `find`, and index header text
- `commands/speckit.knowledge.configure.md`: the "Zero tokens" wording on line 174
- `config-template.yml`: comment on line 108
- `README.md`: "all .md files" wording
- `specs/004-source-lifecycle-cache/contracts/knowledge-config.schema.md` and `specs/004-source-lifecycle-cache/data-model.md`: amend the meaning of an absent `path_filter`
- `.github/scripts/test-sync-git.sh`: new checks
- `CHANGELOG.md`: a `Fixed` entry under `[Unreleased]`

**Tests to add or update** (in `.github/scripts/test-sync-git.sh`, which already pulls the `$NOFILTER` block out of `sync.md`):

- Cold, no filter: the upstream fixture has `package.json`, `src/app.ts`, `.specify/memory/c.md`, `.github/p.md`, root `AGENTS.md` and `CLAUDE.md`, `docs/AGENTS.md`, `docs/a.md`, and `README.md`. After sync, only `docs/a.md` and `README.md` exist, and `git config core.sparseCheckout` is `true`.
- Cold, with a filter (D4): with `path_filter: docs/`, a non-`.md` file under `docs/` (for example `docs/diagram.png`) is not written, and `docs/a.md` is.
- Filter honored verbatim (D3): with `path_filter: .github/docs/`, `.github/docs/x.md` is written and indexed even though `.github/` is a root dot-directory.
- Cold, no filter, Tier 2 pin (existing `tier2-nofilter` scenario, line 479): still the pin's HEAD and content, and `.specify/` is absent.
- Warm self-heal: a cache cloned with the old full checkout loses its non-`.md` files and `.specify/` on the next warm sync, and the warm sparse step exits 0. Mirror the existing cone-mode self-heal check near line 538.
- Indexable Items with no filter: a `.md` file under a root dot-directory, or named `AGENTS.md`, `CLAUDE.md`, or `GEMINI.md` at any depth, is not listed even if it is on disk. Nested hidden directories (`specs/.hidden/x.md`) and root dotfiles (`.notes.md`) are still listed.
- Run everything on git 2.25 (`ubuntu:20.04`) as well as current git, as tiny spec 003 did, because negation patterns and `--no-cone` must behave the same on the minimum supported version.

## Risks & Considerations

- **Security and context integrity:** this is the strongest reason to fix it. The `before_specify`, `before_clarify`, `before_plan`, and `before_tasks` hooks tell the agent to "Open every `.md` file referenced by that index". Today that loads another repository's spec-kit command prompts (`.specify/extensions/git/commands/speckit.git.commit.md`, …), its constitution, its templates, and its `.wibey` agent instructions into the consuming project's agent context. Those files contain imperative instructions ("EXECUTE_COMMAND", hook rules) that the agent may follow as if they belonged to the current project. Excluding root-level dot-directories (D1) and agent instruction files (D2) closes this for the default case. An explicit `path_filter` that points at such files is the user's deliberate choice (D3).
- **Behavior change for existing users:**
  - Projects that relied on dot-directory Markdown or `AGENTS.md`/`CLAUDE.md`/`GEMINI.md` being indexed without a filter will lose it. They can opt back in with an explicit `path_filter` (for example `path_filter: [.github/docs/]`), because the default set applies only when no filter is set.
  - Filtered sources stop caching non-`.md` files under their filter (D4). Nothing indexed changes, because only `.md` files were ever indexed.
  - Document both changes in the CHANGELOG.
- **Contract amendment:** 004's "every `.md` file in the repository" is a published contract. Changing it should be recorded in the spec or contract docs, not only in the command.
- **Disk and bandwidth:** this improves. `--filter=blob:none` combined with sparse patterns fetches only `.md` blobs. Today the reporter's cache downloaded and wrote 396 files to index 85.
- **Integrity check churn:** the first warm sync after the fix changes `item_count` (85 → 50 for the reporter: the 20 `.specify/`, 14 `.wibey/`, and 1 `AGENTS.md` items drop out). The manifest is rewritten at the end of every successful sync, so this is expected, not a corruption.
- **git 2.25 floor:** the negation pattern must be verified on 2.25 (see Tests). `sparse-checkout init --no-cone` and `set --` are already exercised there.

## Decisions

The reporter agreed to these on 2026-10-22. They replace the earlier open questions.

- **D1 — Exclude every root-level dot-directory with `!/.*/**`, not a fixed denylist.** By convention, root dot-directories hold tool and configuration files (`.specify`, `.wibey`, `.github`, `.claude`, `.agents`, `.vscode`, `.cursor`, …), not shared knowledge. A fixed denylist would need updating for every new agent (`.kiro`, `.windsurf`, …), and each one it missed would let foreign instructions back into the index. Only the root is affected: nested hidden directories and root dotfiles are kept.
- **D2 — Exclude agent instruction files at any depth: `!AGENTS.md`, `!CLAUDE.md`, `!GEMINI.md`.** They are instructions for another repository's agent, not domain knowledge, so they carry the same risk as `.specify/`. They follow no common naming pattern, so they need this short explicit list. `README.md` and other documentation are kept.
- **D3 — An explicit `path_filter` is honored verbatim.** The default exclusions from D1 and D2 apply only when no `path_filter` is set. `path_filter: .github/docs/` caches and indexes `.github/docs/**/*.md`. This also gives users a way to opt back in to excluded content.
- **D4 — Filtered sources cache only `.md` files too.** Each `path_filter` entry `<dir>/` becomes the sparse pattern `<dir>/**/*.md`, so the cache never holds non-Markdown files, with or without a filter. The reporter's filtered cache had 31 files for 30 items. Include this in the same fix and cover it with a test.

## Open Questions

None.
