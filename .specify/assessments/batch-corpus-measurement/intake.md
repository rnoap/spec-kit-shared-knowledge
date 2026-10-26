# Idea Intake: Measure and hash a source's whole corpus in one command

- **Slug**: batch-corpus-measurement
- **Created**: 2026-10-26
- **Source**: pasted text, plus the repo paths `commands/speckit.knowledge.sync.md` (step 5, § Corpus Measurement) and `.github/scripts/test-sync-git.sh`
- **Type**: improvement

## Idea (as captured)

> El paso 5 de `sync` describe la medición archivo por archivo, y con 224 archivos el agente puede gastar muchos pasos en eso. Se puede indicar que mida y calcule el hash de **todos los archivos de una fuente en un solo comando**, con el bucle que ya existe en `§ Corpus Measurement`. Así un sync completo cabe en unos pocos pasos. Si quieres, lo registro y lo corrijo como 1.9.2.

## Restated

The sync command should tell the agent to measure the byte size and compute the SHA-256 of every indexable item of a source in one shell invocation, rather than one item at a time. The goal is that a full sync of a large corpus finishes in few agent steps.

## Origin & Context

- **Raised by**: the assistant, while explaining an incomplete sync to the developer (Raúl Noa) on 2026-10-26. The developer then opened this intake.
- **Trigger**: in the consumer project `lookapp`, reinstalling the extension as 1.9.1 removed the knowledge cache and index. The next `/speckit-knowledge-sync` ran by GPT-6 Luna in Copilot, VS Code.
  - It cloned all 3 sources: 30, 50 and 144 Markdown items, 224 in total, 508,199 bytes.
  - It stopped after 23 steps (4m 11s) without writing any `.manifest.json` or `knowledge-index.md`, and reported "The sync is incomplete".
- **Code it relates to**:
  - `commands/speckit.knowledge.sync.md` step 5, "Index .md files per source". Its wording runs per item: "For each item … measure with `wc -c < "$file"` and compute SHA-256 with `sha256sum < "$file"` or `shasum -a 256 < "$file"` (macOS)".
  - Step 6 writes `.manifest.json` with each item's size and hash.
  - § Cache Integrity Check re-hashes every item.
  - § Corpus Measurement shows the single-file form `size=$(wc -c < "$file")` and its portability rules: `wc -c` via redirection; `du` and `stat` forbidden.
- **Correction to the captured wording**: § Corpus Measurement holds no loop over all items. The loop the idea refers to exists in the test harness: `.github/scripts/test-sync-git.sh:368`, `while IFS= read -r file; do … done <<< "$items"`. There it measures and hashes every item in one script.

## First-Glance Unknowns

- [NEEDS CLARIFICATION: Was per-item measurement the cause of the stop at step 23? Other possible causes are the host's per-turn request limit (`chat.agent.maxRequests`), cloning 3 sources cold, or the model's own choice to stop.]
- [NEEDS CLARIFICATION: How many agent steps does a full cold sync of the 224-item corpus take today, and how many with one measurement call per source?]
- [NEEDS CLARIFICATION: Writing `.manifest.json` and `knowledge-index.md` with the agent's file-writing tool, for 224 entries, may cost more steps or tokens than measuring. Is that part of the same problem?]
- [NEEDS CLARIFICATION: Does a single-command form preserve the 007 guarantees? Names are held only in a quoted variable and never pasted into command text. Names with line breaks, leading `-` or shell metacharacters stay literal (`test-sync-git.sh` hostile-file checks).]
- [NEEDS CLARIFICATION: Should the Cache Integrity Check's per-item hash verification use the same single-command form?]
- [NEEDS CLARIFICATION: Is `chat.agent.maxRequests` or a model choice a sufficient workaround, so that no extension change is needed?]
