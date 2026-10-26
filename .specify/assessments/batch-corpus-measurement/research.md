# Idea Research: Measure and hash a source's whole corpus in one command

- **Slug**: batch-corpus-measurement
- **Created**: 2026-10-26
- **Evidence confidence (overall)**: medium. The measurements are direct and repeatable. The behavioral evidence rests on four sync runs, one per model and condition.

## Users & Demand

- **Failed run.** One cold sync of 224 items in `lookapp`, run by GPT-6 Luna on 2026-10-26 at 10:58, stopped after **23 steps / 4m 11s**.
  - It had already cloned all 3 sources and reported "224 Markdown items totaling 508,199 bytes". Sizes were therefore measured.
  - It stopped before writing any `.manifest.json` or `knowledge-index.md`: "the required per-file manifests and complete knowledge-index.md were not created".
  - [source: developer screenshot 11.04.43; cache mtimes, no manifests at 11:05] (confidence: high)
- **Successful run that bypassed the manifest rule.** A warm sync of the same 224 items, run by Claude Opus 5.5 (high) at about 11:09, completed in **28 steps / 3m 59s**.
  - The agent stated: "I generated them [manifests] with a script from the hash data instead of typing 224 SHA-256 hashes by hand. The skill asks for its file-writing tool here."
  - All three manifests have mtimes within one second (11:09:57–58).
  - [source: developer screenshot 11.12.07; `ls -lT cache/*/.manifest.json`] (confidence: high)
- **Earlier successful runs.**
  - About 09:00 on 2026-10-26: a 224-item sync completed, with `store-procs` going from 0 to 144 new items. [source: developer screenshot 9.02.06] (confidence: medium; model and step count not shown)
  - 2026-10-22: a 115-item sync by GPT-6 Luna completed in **38 steps / 14m 25s**. The same model therefore ran well past 23 steps in one turn. [source: developer screenshot 12.01.57, first report of this session] (confidence: high)
- **Who is affected.** The only observed affected party is one developer in one consumer project. No other reports exist. [ASSUMPTION: other consumers with corpora of 200+ items hit the same cost] (confidence: low)
- **When it hurts most.** The cost lands on the first sync after every upgrade. `specify extension add` recreates `.specify/extensions/knowledge/`, keeping only `knowledge-config.yml`, so the cache and the index are wiped. [source: `lookapp` mtimes — everything 10:58:18 except `knowledge-config.yml`] (confidence: high)

## Prior Art

- **A batch loop over all items already exists in the test harness.**
  - `.github/scripts/test-sync-git.sh:368` measures and hashes every item in one script: `while IFS= read -r file; do … done <<< "$items"`.
  - It is exercised by the hostile-file checks: literal `$(touch pwned).md`, a leading `-`, and directory names with line breaks.
  - [source: `test-sync-git.sh`, 229/229 passing] (confidence: high)
- **The command does not batch today.**
  - `commands/speckit.knowledge.sync.md` step 5 is worded per item: "For each item … measure with `wc -c < "$file"` and compute SHA-256".
  - § Corpus Measurement shows only the single-file form.
  - The intake's claim that the loop lives in § Corpus Measurement was wrong.
  - [source: sync.md lines 165–185, 998–1004] (confidence: high)
- **The reason manifests are written with the file tool.**
  - 007 research § 7: "The manifest and the index are written with the agent's file-writing tool, strings escaped as JSON requires", because "a file name comes from whoever controls the source. Pasted into a command, its `$(…)` runs."
  - The same section rejected NUL-separated lists because "Not POSIX, and dash has no `read -d ''`".
  - [source: `specs/007-shell-safe-config/research.md` § 7] (confidence: high)
- **Precedent for agents deviating when the prose is costly.** The `remove-disable-flag-ignored` bug (1.9.1) is another case of model behavior diverging from command prose. [source: `.specify/bugs/remove-disable-flag-ignored/assessment.md`] (confidence: medium)

## Market & Context

- **Workarounds available today:**
  - Re-run the sync: the second run completed.
  - Use a stronger model.
  - Accept agents that silently script the manifests.

  [source: the runs above] (confidence: medium)
- **Cost of doing nothing:**
  - A sync can stop half-done after every upgrade. In that window the knowledge section in `AGENTS.md` points at a missing index.
  - Capable agents may keep bypassing the file-tool rule ad hoc, with no shared, reviewed safe procedure. The bypass in the successful run passed names "as data only", by the agent's own account, but nothing in the extension guarantees that.

  [source: screenshots 11.04.43 and 11.12.07] (confidence: medium)

## Data & Constraints

- **Measuring is cheap.** One loop per source computing size and SHA-256 for every item took:
  - **1.18 s** for 30 items
  - **1.58 s** for 50 items
  - **5.24 s** for 144 items

  Output totals about 24 KB. [source: measured in `lookapp` cache, 2026-10-26] (confidence: high)
- **Writing is costly.** The agent must write about **43.7 KB** through its file tool:
  - manifests: 4.1 + 6.5 + 19.9 KB
  - index: 13.3 KB

  Of that, **224 × 64 = 14.3 KB** are SHA-256 hex digests. That is high-entropy text a model must reproduce exactly. [source: `wc -c` on the artifacts] (confidence: high)
- **A mistyped hash costs a re-sync.** A single wrong hash fails the Cache Integrity Check on the next fallback, and the cache is discarded and re-synced. [source: sync.md § Cache Integrity Check, step 3] (confidence: high)
- **The context budget does not shrink this work.**
  - With `store-procs` set to `max_items: 50`, the index dropped to 130 items.
  - The `store-procs` manifest still lists all **144** items.

  [source: 11:12 screenshot; manifest `item_count` 144] (confidence: high)
- **The host step limit was not the cause.**
  - The developer's VS Code sets `chat.agent.maxRequests: 100`.
  - The shipped default in VS Code 1.142.0 appears to be 50.
  - The failed run stopped at 23.

  [source: `~/Library/Application Support/Code/User/settings.json:16`; VS Code app bundle] (confidence: high for the user setting, medium for the default)
- **Runtime constraints.**
  - Constitution §III: "No compiled code. Bash + YAML + Markdown only".
  - The extension declares no Python or `jq` dependency.
  - Generating JSON from attacker-controlled file names in POSIX sh/awk requires escaping control characters by hand.

  [source: `.specify/memory/constitution.md`; `extension.yml` requires] (confidence: high)

## Evidence Against the Idea

- **The idea targets the wrong step.**
  - The failed run had finished measuring: it reported exact totals.
  - It stopped at writing the manifests and the index.
  - Measuring takes seconds and few steps.
  - The expensive part is the agent hand-writing about 44 KB of JSON and Markdown, including 14 KB of hashes.
  - Batching the measurement alone would likely not have prevented the failure.

  (confidence: high)
- **Capable models already batch.** The successful run collected sizes and hashes in one phase on its own. (confidence: medium, one run)
- **The failure correlates with the model, not with a hard limit.**
  - GPT-6 Luna stopped at 23 steps with 77 steps of host headroom left.
  - The same model completed a 38-step sync four days earlier.
  - Claude Opus 5.5 finished in 28.

  With n=1 per condition, cold versus warm is confounded with model choice. (confidence: low–medium)
- **The real fix conflicts with a security decision.** The cheaper fix, generating manifests by script, reopens 007 § 7. Any script must keep fetched names as data and escape JSON correctly without a non-declared runtime. (confidence: high)
- **The problem appears only in rare full rebuilds.** Warm syncs reuse caches, and the cost peaks only on cold syncs after upgrades. (confidence: medium)

## Gaps & Open Questions

- [NEEDS CLARIFICATION: Does GPT-6 Luna stop consistently on a cold 224-item sync, or was 10:58 a one-off? A second cold run with the same model would separate model from size.]
- [NEEDS CLARIFICATION: What did the 23 steps of the failed run consist of: clone, measure, budget, or attempting the manifest? The transcript, not just the summary, would show where it gave up.]
- [NEEDS CLARIFICATION: Can a POSIX-only procedure produce correct, injection-safe JSON for arbitrary file names, including control characters and quotes, without Python or `jq`? `test-sync-git.sh` hostile names give a ready test corpus.]
- [NEEDS CLARIFICATION: Do hand-written manifests contain hash errors in practice? No hand-written manifest survives to check. The 10:58 run wrote none, and the 11:09 run used a script.]
- [NEEDS CLARIFICATION: Should `specify extension add` preserving the cache across upgrades be pursued upstream? It would remove most cold syncs entirely.]

## Sources

No URLs fetched. All evidence is local:

- `commands/speckit.knowledge.sync.md`: § Corpus Measurement, steps 5–6, § Cache Integrity Check
- `.github/scripts/test-sync-git.sh:368`
- `specs/007-shell-safe-config/research.md` § 7
- `.specify/memory/constitution.md` §III
- `lookapp/.specify/extensions/knowledge/`: cache mtimes, `.manifest.json` files, `knowledge-index.md`, `knowledge-config.yml`
- `~/Library/Application Support/Code/User/settings.json` and the VS Code 1.142.0 app bundle
- Developer screenshots: 12.01.57 (2026-10-22), 9.02.06, 11.04.43, 11.12.07 and 11.12.29 (2026-10-26)
