# Problem Definition: A full knowledge sync does not reliably finish in one agent turn

- **Slug**: batch-corpus-measurement
- **Created**: 2026-10-26
- **Inputs used**: intake.md, research.md

## Problem Statement

A developer whose knowledge corpus holds a few hundred items cannot count on a full rebuild of the cache completing in one agent turn. This is the first sync after every extension upgrade. The agent may stop after cloning and measuring, before the manifests and the index exist. Even when it finishes, it may do so by departing from the written procedure.

The intake framed the cost as per-item measurement. Research shows measurement is cheap: 1–5 s per source. The observed failure came later, at the step where every item's path, size and hash must be recorded exactly (research § Evidence Against the Idea).

## Affected Users & Stakeholders

- **Users**:
  - **A developer in a consumer project.** After an upgrade, the developer is left with no index, and the `AGENTS.md` knowledge section points at nothing until a sync completes.
    - Observed in `lookapp` (224 items, GPT-6 Luna, stopped at step 23).
    - The developer has to notice, re-run, or switch models.
    - [research § Users & Demand]
  - **The coding agent executing the command.** It must produce about 44 KB of exact output, including 14 KB of SHA-256 digests. It either gives up, or bypasses the file-tool rule ad hoc, as the successful Claude Opus 5.5 run did and stated. [research § Data & Constraints]
  - [NEEDS CLARIFICATION: other consumer projects with corpora of 200+ items. None is known; only one project is observed.]
- **Stakeholders**:
  - **Extension maintainer (Raúl Noa).** Owns the command prose and the 007 safety guarantees that any change must keep. Decides the release.
  - **Teammates who share `AGENTS.md` through git.** They rely on each person's sync producing an index the committed section can point to.

## Goals

- A full sync of a corpus the size observed in `lookapp` (224 items, about 500 KB) completes in a single agent turn, on more than one supported model.
- A completed sync records every item's size and hash correctly. A later Cache Integrity Check never discards a cache because of a recording error.
- An agent can complete the sync by following the written procedure. Finishing does not require the agent to deviate from it.
- Fetched file names stay data, never commands, with the same guarantees 007 established. The hostile-name checks in `test-sync-git.sh` keep passing.

## Non-Goals

- **Keeping the cache across `specify extension add`.** That is spec-kit's install behavior, not this extension's. It is worth raising upstream separately (research gap 5).
- **Limiting what the agent reads.** That is the context budget's job (`max_items` / `max_bytes`), and it already works: 130 of 224 items indexed with `store-procs` capped.
- **Speeding up the network part of a sync,** meaning clone and fetch.
- **Changing `search`, `status`, `configure` or `remove`,** except where they share a recording rule with sync.
- **Reworking incremental warm syncs** that leave the corpus unchanged.

## Success Metrics

- **Completion rate.** The share of full (cold) syncs of the `lookapp` corpus that finish in one turn, across at least two models.
  - Baseline: 0 of 1 cold runs observed (GPT-6 Luna, 10:58).
  - The one success (Claude Opus 5.5) ran over existing clones.
- **Agent steps per full sync.** Baseline: 23 (stopped), 28 (completed, warm, scripted manifests) and 38 (completed, 115 items, 2026-10-22).
- **Wall time per full sync.** Baseline: 3m59s–14m25s across the completed runs.
- **Procedure adherence.** The share of completed syncs in which the agent reports no departure from the written procedure. Baseline: 0 of 1 (the 11:09 run scripted the manifests against the stated rule). This metric is qualitative and comes from the agent's own report.
- **Recording correctness.** The share of manifest entries whose hash matches the file on the next integrity check. Baseline: unknown, because no hand-written manifest survives to check.
- **Safety regression.** Baseline: `test-sync-git.sh` 229/229, including the hostile file names. It must not drop.

## Cost of Inaction

- **Every upgrade risks a half-built cache.** The extension shipped 1.8.0 to 1.9.1 within four days, so upgrades are frequent. Until a sync completes:
  - there is no index;
  - the spec-kit hooks have nothing to inject;
  - the `AGENTS.md` section tells the agent to suggest a sync.
- **The safety rule erodes.** Capable agents keep replacing the file-tool step with their own scripts. Each script is unreviewed, and only the agent's own account says file names were kept as data.
- **The problem grows with the corpus.** In `lookapp` it went from 115 to 224 items in four days, and the work in the costly step grows linearly with item count.

Users can live with it today by re-running the sync or switching models (research § Market & Context). That is why the cost is moderate rather than blocking.

## Open Questions

- [NEEDS CLARIFICATION: Does GPT-6 Luna stop consistently on a cold 224-item sync, or was the 10:58 run a one-off? Without a second run, model and corpus size cannot be separated.]
- [NEEDS CLARIFICATION: Where did the failed run's 23 steps go: clone, measure, budget, or a started manifest? Only the full transcript can answer.]
- [NEEDS CLARIFICATION: Can exact item records be produced without a runtime the extension does not declare, such as Python or `jq`, while keeping hostile file names inert? This constrains any shape, but it is a constraint, not a choice made here.]
- [NEEDS CLARIFICATION: Do hand-recorded hashes contain errors in practice? No evidence exists either way.]
- [NEEDS CLARIFICATION: Are there other consumer projects with corpora of 200+ items, or is `lookapp` the only one?]
- [NEEDS CLARIFICATION: Should the maintainer ask spec-kit to preserve extension caches across `extension add`? It is out of scope here, but it would remove most cold syncs.]
