# Bug Assessment: Sync serves the wrong revision, keeps deleted files, fails on macOS, and follows symlinks

- **Slug**: knowledge-sync-defects
- **Created**: 2026-10-14
- **Source**: pasted text
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

```text
Fijar un source a un SHA completo no funciona. speckit.knowledge.sync.md:504 y speckit.knowledge.sync.md:517 usan git checkout -- <revision>. Con el --, git toma el SHA como una ruta, falla, y el git checkout siguiente deja la rama por defecto. Es decir, un source fijado a un SHA sirve contenido de la rama por defecto. Probé esta corrección y funciona: git update-ref --no-deref HEAD FETCH_HEAD.
Un sync con caché existente nunca borra los archivos eliminados upstream. Las líneas speckit.knowledge.sync.md:599-615 usan git checkout <ref> -- ., que nunca elimina archivos. Un ADR borrado sigue en caché e indexado para siempre. Corrección probada: añadir --no-overlay, que funciona con nuestro mínimo de git 2.25.
timeout no viene en macOS (lo confirmé en este Mac). Tal como están escritos los comandos, cada fetch remoto falla con código 127 y el source queda "unreachable"; status marca todo como ❌ timeout. Corrección: probar timeout, luego gtimeout, y si no hay ninguno usar perl -e 'alarm shift; exec @ARGV' 10 git … (comprobado aquí).
El fallo de seguridad con symlinks sigue abierto. El formulario de envío obliga a marcar "No security vulnerabilities identified", pero el README dice lo contrario. Corrección acotada en el speckit.knowledge.sync.md:643:
indexar solo lo que devuelve find … -type f, que no sigue enlaces;
clonar con -c core.symlinks=false;
informar de los enlaces omitidos.
```

Four defects, each with a fix the reporter tested:

| ID | Defect | Reporter's fix |
| --- | --- | --- |
| D1 | A source pinned to a full SHA serves the default branch | `git update-ref --no-deref HEAD FETCH_HEAD` |
| D2 | A warm sync never removes files deleted upstream | `git checkout --no-overlay <ref> -- .` |
| D3 | `timeout` is absent on macOS, so every bounded call exits 127 | `timeout` → `gtimeout` → `perl -e 'alarm shift; exec @ARGV' N …` |
| D4 | A symlinked `.md` is indexed and its target is read | `find … -type f`; clone with `-c core.symlinks=false`; report skipped links |

These are the four sync defects that `specs/006-catalog-readiness` excludes and tracks separately (`catalog-readiness.spec.md:157`). This assessment did not check the submission form's wording. `README.md:442-448` and `CHANGELOG.md:34` do state that the symlink exposure is open.

## Symptom

- **D1**: A source pinned to a full 40- or 64-hex commit is checked out at the remote's default branch, while its slug and manifest name the pinned revision. After the next warm sync, it holds a mix of both trees. Expected: exactly the pinned commit.
- **D2**: After a warm sync, files deleted upstream remain in the cache, the manifest, and the index, with no end date. Expected: the cache matches the fetched tree.
- **D3**: On stock macOS, every bounded `git` call exits 127. Cold syncs end `unreachable`, warm syncs fall back to `cached` indefinitely, and `status` shows every remote as `❌ timeout`. Expected: the same calls work on macOS and Linux.
- **D4**: A `.md` that is a symbolic link is indexed. Measuring, hashing, the search preview, and the agent all read the link's target, which can be any file the user can read. Expected: links are never indexed or read, and each skipped link is reported.

## Reproduction

Reproduced 2026-10-14 on macOS 26.7.1 with git 2.54.0 (Apple Git-157). The commands ran exactly as sync.md writes them, against throwaway repositories served over `file://` (`uploadpack.allowFilter=true`). Tier 2 used protocol v2. Tier 3 used protocol v0, which refuses unadvertised objects. The scripts ran in a `mktemp` directory and were not kept.

[NEEDS CLARIFICATION: nothing here ran on git 2.25, the declared minimum. `--no-overlay` dates from git 2.22. Were the reporter's checks run on 2.25?]

Fixture: on `main`, C1 has `docs/a.md` ("A v1"), `docs/b.md`, `docs/notes.md` (a link to a secret file outside the repository), and `docs/linked` (a link to an outside directory). C2, the default tip, changes `a.md` to "A v2" and deletes `b.md`. The source pins C1.

### D1, Tier 2 (sync.md:499-504)

1. Run `git clone --filter=blob:none --no-checkout --depth=1 -- <url> <cache>`, then `git fetch --depth=1 origin -- <C1>`. Both succeed.
2. `git checkout -- <C1>` fails with `error: pathspec '<C1>' did not match any file(s) known to git` (exit 1).
3. Run the next documented step: `git sparse-checkout init --no-cone; git sparse-checkout set -- docs/; git checkout`, or `git checkout HEAD -- .` when there is no `path_filter`.
4. Result: HEAD is C2, `a.md` reads "A v2", and `b.md` is missing. The cache holds the default branch.
5. With `git update-ref --no-deref HEAD FETCH_HEAD` in place of step 2: HEAD is C1, `a.md` reads "A v1", and `b.md` is present. ✔

### D1, Tier 3 (sync.md:516-517)

1. Against the protocol-v0 server, the Tier 2 fetch fails with `Server does not allow request for unadvertised object` (exit 1).
2. `git fetch --unshallow origin` succeeds, and **FETCH_HEAD is C2, the default tip, not the pin.**
3. `git checkout -- <C1>` fails with exit 1, as in Tier 2.
4. With the reporter's fix, `git update-ref --no-deref HEAD FETCH_HEAD`, HEAD is C2 and `a.md` reads "A v2". ✘ **The reporter's fix does not cover Tier 3.**
5. With `git update-ref --no-deref -- HEAD <C1>`, HEAD is C1. ✔ A pin that is not reachable from the default branch is still absent after `--unshallow`. `update-ref` to an absent object fails (exit 128, "nonexistent object"; checked separately), which correctly leads to "All three tiers failed".

### D1 and D2 together

In this run, C2 also adds `docs/c.md`. A buggy cold sync leaves `a.md` at v2 plus `c.md`. The warm path as written (`git checkout FETCH_HEAD -- .`) then leaves `a.md` at v1 with both `b.md` **and** `c.md`, a mix of the two trees. With `--no-overlay`, only `a.md` (v1) and `b.md` remain, and the untracked `.manifest.json` survives.

### D2, warm path (sync.md:597-616)

1. Cold-sync a source that has `docs/adr-001.md` and `docs/adr-002.md`.
2. Delete `docs/adr-002.md` upstream, then run `git fetch --depth=1 origin; git checkout origin/HEAD -- .`.
3. Result: `docs/adr-002.md` is still there, with or without `path_filter`, and step 5 would index it.
4. With `git checkout --no-overlay origin/HEAD -- .`, the file is removed. ✔

### D3, timeout

1. `command -v timeout gtimeout` finds neither.
2. `timeout 10 git --version` exits 127.
3. `perl -e 'alarm shift; exec @ARGV' 10 git ls-remote --exit-code -- <url> HEAD` exits 0 for a reachable source. Against a local TCP tarpit with a 2 s bound, it exits 142 after 2 s. ✔ Risks describes two gaps in this one-liner.

### D4, symlinks

This uses the cache from Tier 2 step 5, with `path_filter: docs/`.

1. `find docs -name '*.md'`, which has no type rule (as step 5 is written), returns `a.md`, `b.md`, and `notes.md`.
2. `wc -c < docs/notes.md` returns the size of the secret file. `head -c 500 docs/notes.md`, the same read as the search preview, prints `TOP-SECRET-…`. ✘
3. `find docs -type f -name '*.md'` returns only `a.md` and `b.md`. `find docs -type l` returns `docs/linked` and `docs/notes.md`.
4. When the source is cloned with `-c core.symlinks=false`, `notes.md` is a **regular file** that holds the link-target path:
   - `find -type f` **includes** it.
   - `find -type l` finds nothing.
   - `git ls-files -s` lists both links with mode `120000`.

## Suspected Code Paths

- `commands/speckit.knowledge.sync.md:504`: Tier 2 `git checkout -- <revision>`. The `--` turns the SHA into a pathspec, so HEAD never moves.
- `commands/speckit.knowledge.sync.md:516-517`: Tier 3 makes the same call. After `fetch --unshallow origin`, FETCH_HEAD is the default tip, so it cannot replace the revision.
- `commands/speckit.knowledge.sync.md:564` and `:572`: the cold-path checkouts. They materialize whatever HEAD points at.
- `commands/speckit.knowledge.sync.md:599`, `:602`, `:612`, `:615`: the warm-path `git checkout <ref> -- .` calls, which run in overlay mode by default.
- `commands/speckit.knowledge.sync.md:485`, `:499`, `:503`, `:516`, `:598`, `:601`: the six `timeout 10` / `timeout 30` calls.
- `commands/speckit.knowledge.status.md:128`: `timeout 5 git ls-remote --exit-code <url> HEAD`. Task T011 of 006 edits this same line.
- `commands/speckit.knowledge.sync.md:643-645`: step 5 selects `.md` files by name only, then hashes them with `sha256sum <file>`, which follows links.
- `commands/speckit.knowledge.sync.md:151`: `wc -c < "$file"` measures the link's target.
- `commands/speckit.knowledge.sync.md:227`: the Cache Integrity Check compares against the "actual `.md` file count in directory". It must apply the same item rule as step 5.
- `commands/speckit.knowledge.sync.md:485-491`, `:499-500`, `:543-547`: the three clone calls that need `-c core.symlinks=false`.
- `commands/speckit.knowledge.sync.md:951` and `commands/speckit.knowledge.search.md:88`: the reads that make D4 a disclosure. The agent opens every indexed file, and search previews 500 characters of each.
- `README.md:426`, `README.md:442-448`, `config-template.yml:36-37`, and `CHANGELOG.md:32-34`: the docs that name `timeout` or describe the symlink exposure as open.

## Root Cause Hypothesis

**D1** (confidence: high; reproduced): `git checkout -- <x>` restores the paths named `<x>` from the index and never moves HEAD. A `--no-checkout` clone has an empty index, so the call fails and HEAD stays on the default branch the clone created. The next documented checkout then materializes that branch. An agent that instead treats the failed call as a tier failure escalates to Tier 3, which fails the same way, and reports the source `unreachable`. Either way, a full-SHA pin cannot work. The `--` came from FR-034, the 1.4.0 hardening that puts `--` before every operand. That rule is right for real operands, but here it turned a revision into a pathspec. Tier 3 has the same call plus a second trap: its FETCH_HEAD names the default tip.

**D2** (confidence: high; reproduced): `git checkout <tree-ish> -- <pathspec>` defaults to overlay mode. It adds and updates paths but never removes paths that `<tree-ish>` lacks. The warm path never moves HEAD, so nothing else reconciles deletions. Step 5 then enumerates the stale file from disk and step 6 writes it into the manifest, so the integrity check passes and nothing ever flags it.

**D3** (confidence: high; reproduced): GNU `timeout` belongs to coreutils, which is not part of macOS. `gtimeout` exists only after a coreutils install, such as through Homebrew. The commands assume `timeout`, but the README lists only `git >= 2.25` as a prerequisite.

**D4** (confidence: high; reproduced): Git recreates symlinks faithfully, because `core.symlinks` defaults to true on macOS and Linux. Step 5 selects files by name only, and every later reader opens the path, which the OS resolves to the link's target.

Relative links reach predictable targets. The cache sits five directories below the consuming project's root (`.specify/extensions/knowledge/cache/<slug>/`). A root-level `notes.md -> ../../../../../.env` in a source therefore points at that project's `.env`. This follows from the directory layout and was not executed. Whatever the agent reads goes to its model provider and can be quoted into committed specs.

## Proposed Remediation

**Preferred**: keep the reporter's fixes, with the three corrections the reproduction found.

1. **D1**: replace each `git checkout -- <revision>` with a HEAD move that leaves the working tree alone. The existing sparse checkout, or `checkout HEAD -- .`, then materializes the pinned commit.
   - Tier 2 (L504): use the reporter's `git update-ref --no-deref HEAD FETCH_HEAD`. Verified.
   - Tier 3 (L517): use `git update-ref --no-deref -- HEAD <revision>`. **Do not use FETCH_HEAD here.** Verified.
   - Tiers 2 and 3 run only for full-hex revisions, so this operand can never look like an option. `update-ref` also accepts the `--` that FR-034 requires (verified).
2. **D2**: add `--no-overlay` to the four warm-path checkouts (L599, L602, L612, L615), as the reporter proposed.
   - Verified: deleted paths are removed, and the untracked `.manifest.json` is untouched.
   - Existing SHA-pinned caches that D1 already poisoned converge on their next warm sync.
   - `sync --force` triggers that sync at once when a freshness policy holds the cache as `current`.
3. **D3**: define one "bounded network call" rule in sync.md § Algorithm Reference and use it at all seven call sites.
   - Point `status.md:16` at the rule. Status already borrows its algorithms from that section.
   - Resolution order: `timeout N`, then `gtimeout N`, then `perl -e 'alarm shift; exec @ARGV or exit 127' N`.
   - **Add `or exit 127`** to the reporter's one-liner. Without it, perl exits 0 when it cannot run the command (verified), and `status` would then report every source as `✅ reachable`.
4. **D4**: define one "indexable item" rule and use it in both step 5 (L643-645) and the Cache Integrity Check count (L227).
   - A path qualifies only if it is a regular file on disk (`find … -type f`, never `-L`) **and** git does not record it as a link (mode `120000` in `git ls-files -s`).
   - Clone with `-c core.symlinks=false` (L485-491, L499, L543-547).
   - Run `git config core.symlinks false` on the warm path so caches created before the fix get the setting too.
   - List each skipped link by its relative path in that source's sync output.
   - **Both checks are needed** (verified):
     - With `core.symlinks=false`, a link becomes a regular file that holds the target path. `-type f` accepts it, and `-type l` cannot see it.
     - Without that setting, as in caches cloned before the fix, `-type f` is the check that excludes the link.
     - Git's recorded mode is the only signal present in both cases.
   - Update the documentation:
     - README: turn exposure 3 (`README.md:442-448`) into a row of the defenses table.
     - `config-template.yml`: update item 3 of the security block (L36-37).
     - `CHANGELOG.md`: add a Security entry under `[Unreleased]`.

**Alternatives** (optional):

- **D2: `git -c advice.detachedHead=false checkout --force --detach <ref>`** instead of `--no-overlay … -- .`.
  - Verified: deleted files are removed, files outside `path_filter` are no longer written (see Risks), and HEAD then names the cached commit.
  - Trade-off: HEAD moves on every warm sync. That is a larger behavior change, and the reporter did not test it.
- **D3: a process-group perl fallback.**
  - Verified: it exits 124 on timeout (as GNU `timeout` does), passes other exit codes through, exits 127 when the command cannot run, and leaves no orphaned helpers.
  - Trade-off: six lines of perl in a markdown command instead of one. It matches GNU `timeout`, which by default signals the whole process group.

  ```perl
  my $t = shift; my $pid = fork // exit 125;
  if (!$pid) { setpgrp(0, 0); exec @ARGV or exit 127 }
  setpgrp($pid, $pid);
  $SIG{ALRM} = sub { kill "KILL", -$pid; waitpid $pid, 0; exit 124 };
  alarm $t; waitpid $pid, 0;
  exit($? & 127 ? 128 + ($? & 127) : $? >> 8)
  ```

- **D4: enumerate from `git ls-files -s`** (modes 100644 and 100755) instead of `find`.
  - This ignores what is on disk.
  - Trade-off: `path_filter` would have to be re-expressed as pathspecs, which follow different rules from the `--no-cone` patterns. For example, `specs/` matches at any depth as a pattern but only at the root as a pathspec.
  - Not recommended for this fix.

**Files likely to change**:

- `commands/speckit.knowledge.sync.md`:
  - § Algorithm Reference: the new bounded-call and indexable-item rules, and the Cache Integrity Check (L222-230)
  - Tiers 2 and 3 (L494-518)
  - The clone calls (L485-491, L499, L543-547)
  - The warm path (L575-616)
  - Step 5 (L641-645)
  - Step 9 output: a skipped-link line
  - The Error cases summary
- `commands/speckit.knowledge.status.md`: L16 (reference to the new rule) and L128.
- `README.md`: Prerequisites (L28-31) and Trust model (L426, L431-448).
- `config-template.yml`: L36-37.
- `CHANGELOG.md`: `[Unreleased]`.
- Not touched: the Configuration Validation Rules blocks. They must stay byte-identical across three files (Quality Gate §11, enforced by `.github/scripts/validate-extension.sh:174-178`).

**Tests to add or update**: the commands are agent-executed markdown with no behavior tests, and CI checks only static rules and installation. These checks therefore need a script or a CI job built on `file://` fixtures, like the ones used here.

- **D1**: pin a non-tip SHA; the cache's HEAD and content match the pin. Repeat for Tier 3 against a protocol-v0 server. A pin unreachable from the default branch ends `unreachable`.
- **D2**: after an upstream deletion, the file is gone from the cache, the manifest, and the index, and `.manifest.json` survives. A cache already poisoned by D1 converges to the pin.
- **D3**: on macOS without coreutils, `status` shows a reachable remote as `✅ reachable`, and sync reaches `fresh`. A tarpit host fails within the bound. A missing `git` exits non-zero. 006 also requires a real `status` run on macOS before publication (`specs/006-catalog-readiness/tasks.md:195`).
- **D4**: give a source one file link and one directory link, with absolute and `../`-relative targets.
  - Neither link is indexed, measured, or hashed, and both are reported.
  - The next run's Cache Integrity Check passes.
  - A cache cloned before the fix is covered.

## Risks & Considerations

- **The reporter's D1 fix fails on servers that need Tier 3.** These include self-hosted Gitea, Bitbucket Server, and bare SSH, the servers named in `sync.md:507-512`. FETCH_HEAD after `--unshallow` is the default tip (reproduced).
- **The perl one-liner as written reports success when it cannot run the command** (reproduced). `or exit 127` fixes it.
- **Orphaned remote helpers.** On timeout, `alarm` kills only `git`.
  - Its `git-remote-http` children stayed connected to the tarpit after the wrapper returned: two orphans per call (reproduced).
  - GNU `timeout` signals the whole process group.
  - Sync runs from four automatic hooks per feature cycle, so a host that hangs keeps accumulating orphans.
  - The process-group alternative avoids this.
- **Perl availability.** macOS 26.7.1 ships `/usr/bin/perl` 5.34.1, but Apple has deprecated its bundled scripting runtimes since macOS 10.15. The rule must state what happens when none of the three tools exists (see Open Questions).
- **Exit codes change.** GNU `timeout` exits 124 on timeout, and the perl one-liner exits 142. No command branches on the value (checked), so every non-zero code still reads as a failure.
- **The integrity check must share the item rule.** If it does not, a cache with a skipped link fails the count on every run, is discarded as corrupted, and the offline fallback is lost.
- **Existing caches.** Links already on disk stay until git rewrites those paths. Setting `core.symlinks=false` later does not convert them, so the index-time check cannot rely on the clone flag alone.
- **Pre-existing problem, related but out of scope.** With `path_filter` set, the warm checkout also writes files added or changed upstream **outside** the filter (`root.md` and `other/x.md` in the reproduction). Unchanged files outside the filter are not written.
  - `--no-overlay` keeps this behavior. The next sync's `sparse-checkout reapply` removes those files again.
  - Step 5 is scoped to the filter, so these files are never indexed. They are still fetched and written, which undercuts the README's "`path_filter` — Corpus size and blast radius" row (`README.md:427`).
  - The `--detach` alternative fixes it.
- **Interaction with 006-catalog-readiness.**
  - 006 task T011 adds `--` to `status.md:128`, and this fix rewrites the same line. The merged line must be `<bounded 5> git ls-remote --exit-code -- <url> HEAD`.
  - 006's macOS platform claim and its publication check depend on D3 (`catalog-readiness.spec.md:151`, `contracts/commands.md:96-97`, `contracts/ci.md:128`).
  - 006 and these fixes are planned for the same release (`catalog-readiness.spec.md:150`).
- **Catalog submission.** `README.md:442-448` and `CHANGELOG.md:34` say the exfiltration path is open. "No security vulnerabilities identified" cannot honestly be checked until D4 ships and those texts change.

## Open Questions

- [NEEDS CLARIFICATION: when none of `timeout`, `gtimeout`, and `perl` exists, should a call run unbounded with a one-line warning (availability first), or should the source fail as `unreachable` (bound first)?]
- [NEEDS CLARIFICATION: for the D3 fallback, use the process-group variant (GNU-compatible, no orphans) or the one-liner plus `or exit 127`?]
- [NEEDS CLARIFICATION: fold the out-of-filter warm write into this fix (the `--detach` alternative), or track it separately?]
- [NEEDS CLARIFICATION: report skipped links only in sync output, or also record them in `.manifest.json` so `status --verbose` can show them?]
- [NEEDS CLARIFICATION: ship D1–D3 (correctness) and D4 (security) as one PR or two? This worktree branches from `main`, and 006 is not merged yet.]
- [NEEDS CLARIFICATION: before release, run the fixed commands on git 2.25, the declared minimum.]
