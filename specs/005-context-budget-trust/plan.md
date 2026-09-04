# Implementation Plan: Context Budget & Trust Model

**Branch**: `005-context-budget-trust` | **Date**: 2026-09-04 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from [specs/005-context-budget-trust/spec.md](spec.md)

## Summary

Two capabilities that are the same concern seen from two sides — what an uncontrolled corpus does
to the agent, and what an uncontrolled configuration grants to whoever edits it.

- **Context budget** — two optional keys, `max_items` and `max_bytes`, project-wide and
  overridable per source. When the corpus exceeds them the index carries only what fits, chosen by
  a fixed rule the user can reproduce on paper, and the extension states exactly what it left out
  across four surfaces. Opt-in, so an upgrading project observes nothing new; an advisory warning
  above 200 items / 2 mb reaches the projects that would never enable it.
- **Trust model** — a README section stating what a committed `knowledge-config.yml` grants. No new
  mechanism: the exposures already exist and the defenses are already implemented. The section
  stops the posture from being something a reader must reconstruct from the source.

**Technical approach**: Markdown and YAML only, per Constitution §III. No script is added. The two
portability traps are avoided deliberately — byte counts use `wc -c < file` rather than `du`
(blocks, and a differing default unit between GNU and BSD) or `stat` (incompatible format flags),
for the same reason feature 004 chose `find -mmin` over `date`. The allocation rule is progressive
fill, which terminates in at most one pass per source and is simple enough to execute by hand,
which FR-007b requires.

**One structural change falls out of the budget**: `speckit.knowledge.search` currently iterates
the items *in the index*. Bounding the index would have made a withheld item unfindable — breaking
FR-017 and collapsing the "un-injected, not unavailable" distinction the whole feature rests on.
Search moves to reading the per-source manifests, which already hold the complete inventory. This
was found in Phase 0 and promoted to **FR-035**.

## Technical Context

**Language/Version**: Markdown (CommonMark) for command prompts and documentation; YAML 1.2 for
`extension.yml` and `config-template.yml`. Embedded POSIX shell inside the prompts is illustrative
pseudocode documenting intent for the executing agent — it is not a shipped script. No compiled
code.

**Primary Dependencies**: spec-kit `>= 0.10.0` and `git >= 2.25`, both already declared in
`extension.yml#requires`. **Nothing new is added.** Byte measurement uses POSIX `wc`, which is
already assumed present alongside `find`, `sha256sum`/`shasum`, and `timeout`.

**Storage**: No new file. Two optional keys in the existing `knowledge-config.yml`; the existing
`.manifest.json` is unchanged in shape but changes in role — it becomes the complete inventory
against which the budgeted index is the subset. `knowledge-index.md` gains four header fields,
omitted entirely when nothing is withheld.

**Testing**: Manual walkthrough in a real consumer project, as with 001–004. Constitution §III
waives an automated framework for agent prompts. [quickstart.md](quickstart.md) covers all twenty
Success Criteria across fourteen steps.

**Target Platform**: Any POSIX environment with spec-kit `>= 0.10.0` and git `>= 2.25`. GNU and BSD
must behave identically — an active design constraint, not an assumption (see
[research.md](research.md) § R1).

**Project Type**: spec-kit extension package. Agent-prompt Markdown is the deliverable. No `src/`,
no `tests/`, no build step.

**Performance Goals**: Not a throughput feature. The only new per-sync cost is one `wc -c` per
cached `.md` file, on files already being read and hashed. Corpus measurement runs even when no
budget is configured, because FR-032's advisory warning needs the same numbers — an accepted cost,
bounded by a corpus the user already chose to cache.

**Constraints**:

- Exit code 0 on every path (FR-022, and the extension-wide invariant from 003).
- A project that upgrades and changes nothing must observe identical behaviour (FR-004, FR-023).
  This forbids any default budget value.
- `schema_version` stays `"1.0"` (FR-005) — both keys are optional and additive.
- No flag may raise or bypass the budget (FR-012). Unlike `--force`, this needs no structural
  protection because the flag does not exist; the risk is a future release adding one.
- The Configuration Validation Rules block is duplicated verbatim across three command files, and
  Constitution Quality Gate §11 asserts byte-identity on every pull request. Both new rows must
  land in all three copies in the same change.
- Determinism is a hard requirement, not a quality goal (FR-007). It rules out `du`, `stat`, and
  any rule sensitive to filesystem enumeration order.

**Scale/Scope**: 0 new command files; 4 command files modified; `config-template.yml`,
`extension.yml`, `README.md`, and `CHANGELOG.md` updated. No file deleted. **Command count stays
5**, so Quality Gates §2 and §5 are untouched — unlike 004, this release amends no constitution
text.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

| Principle / Gate | Pre-Design | Post-Design | Notes |
|------------------|:----------:|:-----------:|-------|
| **I. Extension-Package Discipline** — `extension.yml` is the single source of truth | ✅ | ✅ | Version bump only. No command added, no hook changed. |
| **I.** — `config-template.yml` `schema_version` bumped on breaking change | ✅ | ✅ | Two optional keys with backward-compatible defaults. Not breaking, so `"1.0"` correctly stands (FR-005). |
| **I.** — Commands are self-contained Markdown, no hidden runtime dependencies | ✅ | ✅ | `wc` is POSIX and already implied by the existing toolchain. No interpreter added. |
| **I.** — Installation delegated entirely to the spec-kit CLI | ✅ | ✅ | Untouched. |
| **II. Source-of-Truth Hierarchy** | ✅ | ✅ | No artifact here conflicts with a higher one. §II governs conflict resolution, not authoring order. |
| **III. Simplicity (YAGNI)** — Markdown-only when expressible as Markdown | ✅ | ✅ | Zero scripts. The temptation — a size-parsing and allocation helper — is met by progressive fill stated as prose ([research.md](research.md) § R3). |
| **III.** — No test framework required for agent prompts | ✅ | ✅ | Verification is [quickstart.md](quickstart.md). |
| **IV. Conventional Commits (NON-NEGOTIABLE)** | ✅ | ✅ | `feat(config):`, `feat(sync):`, `fix(search):`, `docs(readme):`, `chore(release):`. No `!` — nothing breaking. |
| **Naming** — command IDs `speckit.<ext-id>.<verb>` | ✅ | ✅ | No command added; existing IDs untouched. |
| **Quality Gate §1** — install runs clean, config scaffolds | ✅ | ✅ | Regression risk only: `config-template.yml` must stay valid YAML. [quickstart.md](quickstart.md) step 13. |
| **Quality Gate §2** — all five commands registered | ✅ | ✅ | Count unchanged at 5. **No constitution amendment needed this release**, unlike 004. |
| **Quality Gate §3** — manifest version matches the release tag | ⚙️ pending bump | ✅ | `1.4.0` → `1.5.0` (minor: additive). |
| **Quality Gate §4** — CHANGELOG entry for the new version | ⚙️ pending entry | ✅ | New `## [1.5.0]` section. |
| **Quality Gate §5** — README command table matches `provides.commands` | ✅ | ✅ | No command added, so the table is unchanged. README still gains budget and trust-model sections. |
| **Quality Gate §6** — README badge matches manifest version | ⚙️ pending bump | ✅ | Badge `1.4.0` → `1.5.0`. |
| **Quality Gate §10** — no hook declares arguments | ✅ | ✅ | Hooks untouched. Note this gate protects `--force`; it would **not** protect a future budget-bypass flag. |
| **Quality Gate §11** — Validation Rules block byte-identical across 3 files | ⚠️ **active risk** | ✅ | Two rows added. Landing them in fewer than all three copies fails CI. Called out in [data-model.md](data-model.md) § 4 and scheduled as a single task. |
| **Extension-wide invariant** — exit-0 on every path | ✅ | ✅ | Every new failure mode (malformed ceiling, oversized item, starved source, clamp) is a message. |
| **003 contract** — Context Output block emission gate | ✅ | ✅ | Unchanged. A budgeted corpus is still usable content; it gains one line saying it is partial (FR-015). |
| **004 contract** — cache freshness and orphan pruning | ✅ | ✅ | Untouched. The budget bounds no cache (FR-012a), so pruning is unaffected. |
| **004 contract** — conflict scoping by repository identity | ✅ | ✅ | Consumed, not changed. FR-033 makes conflict pairs atomic under the budget. |

**Gate result**: No violations. Complexity Tracking is therefore empty.

Quality Gate §11 is the one live hazard — a mechanical check that fails loudly if the three copies
of the rules block drift. It is scheduled as a single task rather than three, so the copies cannot
be updated separately.

## Project Structure

### Documentation (this feature)

```text
specs/005-context-budget-trust/
├── spec.md                          # Specification (clarified 2026-09-04)
├── plan.md                          # This file
├── research.md                      # Phase 0 — eight resolved decisions
├── data-model.md                    # Phase 1 — config keys, derived entities, pipeline position
├── quickstart.md                    # Phase 1 — manual verification of all twenty SC
├── contracts/
│   ├── knowledge-config.schema.md   # Phase 1 — user-facing config contract
│   └── commands.md                  # Phase 1 — CLI surface and output contract
├── checklists/
│   └── requirements.md              # Authored at specify time; updated post-clarify
└── tasks.md                         # Phase 2 — /speckit.tasks, NOT this command
```

A `contracts/` directory ships for the same reason it did in 004: this feature changes both
interfaces consumers actually depend on — the schema of the configuration they commit, and the
observable output of the commands spec-kit registers for them.

### Source Code (repository root — files this feature touches)

```text
commands/
├── speckit.knowledge.sync.md        # MODIFIED — new step 7a applies the budget; withholding
│                                    #   report; advisory warning; index header fields;
│                                    #   partial-corpus line in the Context Output block;
│                                    #   `--verbose` withheld list; +2 validation rows
├── speckit.knowledge.search.md      # MODIFIED — read manifests, not the index (FR-035).
│                                    #   The load-bearing change: without it FR-017 is false
├── speckit.knowledge.status.md      # MODIFIED — Budget column; name the limit applied;
│                                    #   +2 validation rows
├── speckit.knowledge.configure.md   # MODIFIED — accept and validate the two keys; report a
│                                    #   clamp; +2 validation rows
└── speckit.knowledge.remove.md      # UNCHANGED

config-template.yml                  # MODIFIED — document both keys; point at the trust model
                                     #   (FR-030). schema_version stays "1.0"
extension.yml                        # MODIFIED — 1.4.0 → 1.5.0. No command or hook change
README.md                            # MODIFIED — badge; context budget section; Trust Model
                                     #   section (FR-024 … FR-031)
CHANGELOG.md                         # MODIFIED — new [1.5.0] section
```

`speckit.knowledge.remove.md` is the only command untouched — it neither reads a budget value nor
produces an index.

**Structure Decision**: The repository has no `src/` or `tests/` tree and will not grow one. The
`commands/` directory *is* the source tree, `config-template.yml` *is* the schema, and
`extension.yml` *is* the build manifest. This mirrors 001–004 and is mandated by Constitution §III.

## Complexity Tracking

> No Constitution Check violations. Table intentionally empty.

## Phase 0 — Research

Eight unknowns resolved in [research.md](research.md):

| # | Question | Decision |
|---|----------|----------|
| R1 | Portable byte measurement | `wc -c < file`; never `du` (blocks) or `stat` (incompatible flags) |
| R2 | Size value format | `^[0-9]+(kb\|mb)$`, binary units, matching the `max_cache_age` shape |
| R3 | Allocation algorithm | Progressive fill per dimension, intersected; label-order tiebreak |
| R4 | Config keys and validation | `max_items`, `max_bytes` at both levels; `0` rejected; three rule copies must stay identical |
| R5 | Pipeline position | After conflict detection, before index write |
| R6 | Advisory thresholds | 200 items / 2 mb — calibration, not contract |
| R7 | Reporting surfaces | Four surfaces, deliberately different content |
| R8 | Trust model audit | Seven defenses verified present; three exposures undefended |

**Two findings were promoted to requirements**, following the precedent of 004, because both
described behaviour that would otherwise have shipped with nothing authorising it:

1. **Search reads the index** → now **FR-035**. Bounding the index would have made a withheld item
   unfindable, contradicting FR-017 and SC-006 and collapsing the "un-injected, not unavailable"
   distinction the Q3 clarification rests on. Search moves to the manifests, which already hold the
   complete inventory and are written before the budget runs. This also supplies FR-034's verbose
   withheld list for free: *manifest items − indexed items*.
2. **Symlink following** → now enumerated in **FR-026**. Indexing enumerates `.md` files after
   checkout, and `git checkout` recreates symlinks faithfully. A source containing
   `notes.md -> ~/.ssh/id_rsa` yields an index entry the agent is instructed to read into its
   context, and from there potentially into a committed spec. Nothing in the pipeline resolves or
   rejects it. Fixing it is a behavioural change with its own edge cases and is out of scope here;
   naming it as undefended is exactly what FR-031 demands, and omitting it because it is
   inconvenient is the failure FR-031 exists to prevent.

**Output**: [research.md](research.md) — all NEEDS CLARIFICATION resolved.

## Phase 1 — Design & Contracts

**Prerequisites**: [research.md](research.md) complete.

- **[data-model.md](data-model.md)** — the two configuration keys; the manifest's changed role as
  the complete inventory; the index header fields; four derived entities (effective limit,
  allocation, selection, withholding report); the sync pipeline position; a nine-row budget
  decision table; and the interaction matrix against every contract inherited from 002, 003, and
  004.
- **[contracts/knowledge-config.schema.md](contracts/knowledge-config.schema.md)** — every key, its
  rule, its default, and its compatibility guarantee. States plainly why the two scoping
  conventions differ: `max_cache_age` *replaces*, a budget *sub-ceilings*.
- **[contracts/commands.md](contracts/commands.md)** — the CLI surface and the exact output
  contract for all eight affected surfaces, plus the error table and the exit-0 invariant.
- **[quickstart.md](quickstart.md)** — fourteen steps mapping to all twenty Success Criteria, built
  on three deliberately asymmetric source repositories so allocation is observable. Step 10 is the
  check that FR-035 actually landed.
- **Agent context** — the managed block in [.github/copilot-instructions.md](../../.github/copilot-instructions.md)
  is repointed at this plan.

## Next Command

`/speckit.tasks` — generate the dependency-ordered task list. Phases should declare the contract
before implementing it: `extension.yml` and `config-template.yml` first, then `commands/*.md`, then
`README.md` and `CHANGELOG.md`. This is a design choice, not a Constitution §II requirement — §II
governs conflict resolution, not authoring sequence.

Two constraints for task generation:

- **The three copies of the Validation Rules block must be one task, not three.** Splitting them
  across tasks lets an incomplete change land and fail Quality Gate §11.
- **The search change (FR-035) is not optional polish.** Without it FR-017 and SC-006 are false, so
  it belongs in the same phase as the budget itself, not in a documentation cleanup at the end.
