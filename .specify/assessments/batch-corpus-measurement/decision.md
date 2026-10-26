# Decision: Shell-recorded manifests, so a full knowledge sync fits in one turn

- **Slug**: batch-corpus-measurement
- **Decided**: 2026-10-26
- **Verdict**: go, with a feasibility spike first
- **Artifacts reviewed**: intake.md, research.md, problem.md, concept.md

## Scorecard

| Criterion | Rating | Justification |
|-----------|--------|---------------|
| Problem validity | adequate | Observed in a real consumer project: a cold 224-item sync stopped at step 23 with no manifests and no index. It recurs on every upgrade, and there were five releases in four days. A workaround exists, so the problem is real but not blocking. |
| Evidence strength | adequate | The cost split rests on direct measurements: 5 s to hash everything versus about 14 KB of digests for an agent to transcribe. Two runs agree with it. The failed run stopped after measuring, and the successful run said it scripted the manifests to avoid typing hashes. Behavioral evidence is still one run per model, and where the 23 steps went is unverified. |
| Value vs. inaction | adequate | Without a change, every upgrade risks a half-built cache, the corpus grows by item count, and agents keep bypassing a 007 safety rule with unreviewed scripts. The cost is moderate, because a re-run recovers. |
| Feasibility / appetite | adequate | Option C fits a small-to-medium appetite, and the loop it builds on already runs in `test-sync-git.sh`. The rabbit hole is real: injection-safe JSON from hostile names in POSIX `sh` and `awk`, across awk variants, shells and git 2.25. A spike can retire it before the rest of the work starts. |
| Strategic fit | adequate | It stays inside the extension's model: a bash block in command Markdown, like § Indexable Items, not a separate script file, consistent with §III. It revises 007 § 7 for the manifest only, and it keeps the manifest format and every reader unchanged. |
| Risk posture | adequate | The risks are named: JSON escaping, non-UTF-8 names, awk portability, old manifests. The hostile-name corpus gates them. A malformed manifest fails the integrity check loudly instead of serving wrong data. The open risk is a rebuild loop if the block itself is wrong, which the spike must exclude. |

## Verdict & Rationale

**Go, for Option C, behind a feasibility spike.**

The evidence clears the bar:
- **Where the cost is:** recording, not measuring, is the expensive and error-prone step.
- **Why C:** it is the only small option that removes that step. It makes item records exact by construction and turns the script capable agents already improvise into a reviewed procedure.
- **Why not the others:**
  - Option B, the original idea, targets the step that already works.
  - Option A meets no goal.
  - Option D costs a manifest-schema migration the problem does not justify.

The go is conditional because two scorecard items rest on assumptions, not evidence:
- **Feasibility of safe JSON without new dependencies.** It is retired by a spike that must pass before any other work. If the spike fails, fall back to Option B plus A's documentation, and reopen Option D.
- **Where the failed run's 23 steps went.** It stays open. If the stop came from cloning rather than recording, C still meets the correctness and adherence goals. The completion goal would then need its own look.

## If go — Handoff to `/speckit-specify`

- **Problem**: A full rebuild of the knowledge cache, the first sync after every extension upgrade, does not reliably finish in one agent turn for a corpus of a few hundred items. The agent must transcribe every item's path, size and SHA-256 into the manifests. Some models stop there, and others finish only by departing from the written procedure.
- **Chosen approach**: Option C. The shell block that collects and measures a source's items also writes its `.manifest.json`. The shared Cache Integrity Check re-derives the same records in one block. The agent never transcribes a hash, and it still writes `knowledge-index.md`. Also include Option A's documentation: the first sync after an upgrade is a full rebuild, and a stopped sync resumes on re-run.
- **In scope**:
  - sync step 5 and step 6, plus § Corpus Measurement as needed;
  - the shared § Cache Integrity Check, which status and search reuse by reference;
  - `test-sync-git.sh` coverage;
  - the README note;
  - a recorded revision of 007 § 7 for the manifest only.
- **Out of scope**:
  - generating `knowledge-index.md` from the shell;
  - budget and conflict logic;
  - any change to the manifest format or its `schema_version`;
  - keeping caches across `specify extension add` (spec-kit; a separate upstream request);
  - network cost;
  - `configure` and `remove`.
- **Success metrics**:
  - **Completion**: a cold full sync of the `lookapp` corpus completes in one turn, across at least two models. Baseline: 0/1 cold.
  - **Fewer agent steps**: baseline 23 (stopped), 28 and 38 (completed).
  - **Shorter wall time**: baseline 3m59s–14m25s.
  - **Adherence**: the agent reports no departure from the procedure. Baseline: 0/1.
  - **Integrity**: 0 integrity-check failures caused by recording.
  - **No regression**: `test-sync-git.sh` stays green, including the hostile-name checks. Baseline: 229/229.
- **Spike, the first task in plan**:
  - **Matrix**: BSD awk on macOS, gawk, mawk; `sh`, `bash` and `zsh`; git 2.25 on Ubuntu 20.04 and current git.
  - **Pass criteria**:
    - The `test-sync-git.sh` hostile names produce valid JSON that parses with Perl's core `JSON::PP`, which the harness can use.
    - Names round-trip literally.
    - No marker file is ever created.
    - Non-UTF-8 names are skipped and reported.
  - **If it fails**: stop and return to shape.
- **Carried-forward open questions**:
  - [NEEDS CLARIFICATION: Where did the failed GPT-6 Luna run's 23 steps go? A full transcript, or a repeat cold run, would tell.]
  - [NEEDS CLARIFICATION: Does GPT-6 Luna stop consistently on a cold 224-item sync?]
  - [NEEDS CLARIFICATION: How should a name that is not valid UTF-8 be reported: by escaped bytes, like control characters today, or by count only?]
  - [NEEDS CLARIFICATION: Should the maintainer raise cache preservation across `extension add` with spec-kit? It is out of scope here.]
