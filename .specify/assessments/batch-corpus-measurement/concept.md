# Concept: Let the shell record the corpus, so a full sync fits in one turn

- **Slug**: batch-corpus-measurement
- **Created**: 2026-10-26
- **Recommended option**: C — Shell-recorded manifests

## Options

### Option A — Do nothing, document the workaround
- **Sketch**: The command stays as it is. The README's troubleshooting section and sync's own text say three things:
  - the first sync after an upgrade rebuilds everything;
  - a sync that stops half-done is resumed by running it again;
  - a more capable model helps.
- **Appetite**: small (hours).
- **Trade-offs**:
  - **Wins**: nothing changes, so there is no risk to 007's guarantees.
  - **Sacrifices**: none of the goals is met.
    - Completion stays model-dependent (baseline 0/1 cold).
    - Agents keep scripting manifests against the written rule, so procedure adherence stays at 0/1.
    - The cost grows with the corpus.
- **Rabbit holes**: none.

### Option B — One measurement call per source (the original idea)
- **Sketch**: Step 5 gives the agent one block per source that prints every item's path, size and hash in a single run. It is the loop already proven in `test-sync-git.sh:368`, promoted into the command. The agent still writes `.manifest.json` with its file tool, copying the hashes from that output.
- **Appetite**: small (1–2 days).
- **Trade-offs**:
  - **Wins**: fewer agent steps to measure, and it stays inside 007 § 7 as written.
  - **Sacrifices**: research shows measuring was not where the failed run stopped. The agent still reproduces about 14 KB of SHA-256 hex by hand, the step that failed (10:58) or was bypassed (11:09).
  - Goals 1–3 (completion, correct records, adherence) are at best partly met.
- **Rabbit holes**: none of note. The risk is building it and seeing no change in completion rate.

### Option C — Shell-recorded manifests
- **Sketch**: The manifest is written by the shell block that measures the corpus, not transcribed by the agent.
  - **Sync**: one block per source collects the items (§ Indexable Items), measures and hashes them, and writes `.manifest.json` directly. The agent never handles a hash.
  - **Integrity check**: the Cache Integrity Check, shared by sync, status and search, re-derives the same records in one block and reports pass or fail.
  - **Index**: the agent still writes `knowledge-index.md`, where the budget and conflict reasoning live.
  - **Format**: the manifest format and its `schema_version` stay unchanged.
- **Appetite**: small-to-medium (several days). The block itself is short. The budget goes to proving it safe and portable.
- **Trade-offs**:
  - **Wins**:
    - It addresses the step that failed.
    - The records are exact by construction, which meets goal 2.
    - The written procedure becomes the thing capable agents already improvise, which meets goal 3.
    - Agent steps per sync should drop sharply, toward goal 1 and the step and time metrics.
  - **Sacrifices**:
    - It revises a 007 decision ("the manifest … written with the agent's file-writing tool"). Names must stay data inside a script that now emits JSON.
    - It adds a shell procedure the constitution's §III prefers as Markdown.
  - **Risks**: a JSON-escaping bug would write unreadable manifests. They fail the integrity check and are rebuilt, so the failure is loud, not silent, but it could loop.
- **Rabbit holes**:
  - **JSON from hostile names, with no Python or `jq`.** Escaping quotes, backslashes and every control character in POSIX `sh`/`awk`.
  - **Non-UTF-8 names**: JSON cannot carry them. They need a skip-and-report rule like the one for symbolic links.
  - **`awk` portability**: BSD awk on macOS, gawk, mawk, and git 2.25 on Ubuntu 20.04.
  - **Shells**: the block must behave identically in `sh`, `bash` and `zsh`, the matrix the slug procedure is already tested against.
  - **Old manifests**: manifests written by agents in older versions must still pass or fail the new integrity check sensibly.

### Option D — Let git be the integrity record
- **Sketch**: The cache is already a git checkout, and git already holds a content hash for every file. The manifest would stop listing per-item SHA-256s and would record the checked-out commit and the item paths. Integrity becomes "the checkout is unmodified at that commit".
- **Appetite**: medium (one to two weeks).
- **Trade-offs**:
  - **Wins**: it removes per-item hashing and the 14 KB of hex entirely, for any writer.
  - **Sacrifices**:
    - It changes the manifest schema and every integrity check.
    - Every existing cache is rebuilt once.
    - It leans on `git status` behaving the same under sparse checkout and `core.symlinks=false` back to git 2.25.
- **Rabbit holes**:
  - sparse-checkout status semantics across git versions;
  - files a source deliberately keeps outside git's view;
  - the manifest schema migration across sync, status and search.

## Recommendation

**Option C.** It is the only small option that targets the step the evidence points at. Recording size and hash for 224 items is 5 seconds of shell work and about 14 KB of error-prone transcription for an agent. Option C makes that work the shell's job.

- **Completion**: it should move completion of a cold full sync from 0/1 toward reliable across models.
- **Correctness and adherence**: it makes recording correct by construction, and turns the 11:09 run's improvised script into the reviewed procedure.
- **Format and readers**: it keeps the manifest format, so search and status keep reading what they read today.

The cost is reopening 007 § 7 for the manifest. That is acceptable only if the hostile-name corpus in `test-sync-git.sh` proves the names stay data.

- **Option D** is the cleaner long-term model, but its schema migration and git-semantics risks exceed the appetite this problem justifies. Revisit it if per-item hashing becomes a cost elsewhere.
- **Option A's documentation** (the first sync after an upgrade is a full rebuild, and a stopped sync resumes on re-run) costs almost nothing. It should ship alongside C.

## Out of Scope (for the recommended option)

- Writing `knowledge-index.md` from the shell. Budget allocation, conflict handling and messages stay agent reasoning.
- Changing the manifest format or its `schema_version`.
- Keeping caches across `specify extension add`. That is spec-kit's behavior and belongs in a separate upstream request.
- Network cost: clone and fetch.
- `configure` and `remove`. `status` and `search` change only by reusing the shared Cache Integrity Check.

## Assumptions to Validate

- **The failure is in recording.** The 23 steps of the failed run went to recording, or to the run-up to it, rather than to clone or measure. This needs the full transcript (research gap 2).
- **Safe JSON without new dependencies.** A POSIX `sh` + `awk` block can emit valid JSON for every valid-UTF-8 name, with the hostile names from `test-sync-git.sh` staying literal. It must do so on BSD awk, gawk and mawk, under git 2.25 and current git, in `sh`, `bash` and `zsh`.
- **Agents run the block.** Agents run a provided block when the prose says to, instead of improvising. Two runs, one per model, are needed before and after to compare against the 0/1 adherence baseline.
- **Existing readers are unaffected.** Manifests the shell writes are read without change by `search` and by the existing Cache Integrity Check in its JSON form.
- **The index is not the next bottleneck.** About 13 KB of paths and budget reasoning fit in one turn. Both completed runs wrote it, and the failed run stopped before it.
- **The maintainer accepts revising 007 § 7** for the manifest, with the hostile-name tests as the gate.
- **Non-UTF-8 names are rare in knowledge sources.** Skipping and reporting them is an acceptable outcome.
