# Implementation Plan: Source Lifecycle & Cache Policy

**Branch**: `004-source-lifecycle-cache` | **Date**: 2026-09-04 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from [specs/004-source-lifecycle-cache/spec.md](spec.md)

## Summary

Three capabilities that ship together, because each one makes the others safe or affordable:

- **Source lifecycle** — a new fifth command, `speckit.knowledge.remove`, owns the whole
  activation lifecycle of a configured source: purge it, disable it, or re-enable it. Today
  the only way to stop consuming a source is to hand-edit YAML. Removal also purges the
  source's cache directory; disabling retains it. Label uniqueness becomes an invariant
  enforced at `configure` time, because revision pinning makes a URL a non-unique key.
- **Per-source revision pinning** — an optional `revision` key (branch, tag, or commit) per
  source. The cache slug absorbs the revision so two revisions of one repository cannot
  contaminate each other, and a source with no `revision` keeps byte-identical cache identity
  to today, so no existing project re-downloads on upgrade.
- **Cache freshness policy** — an optional `max_cache_age` duration, global with per-source
  override. When a cache is younger than its policy, sync skips the network entirely. This is
  what makes the four automatic hooks added in 1.3.0 affordable: without it, a single feature
  cycle refetches every source four times.

**Technical approach:** Markdown and YAML only, per Constitution §III. The deliverable is
agent-prompt prose plus a config schema; no Bash script is added and no compiled code exists.
The freshness gate is expressed with POSIX `find -mmin` rather than `date` arithmetic, because
`date -d` (GNU) and `date -j -f` (BSD/macOS) are mutually incompatible and the extension
declares no interpreter dependency beyond `git`. Validation moves from the write path
(`configure` only) to the read path (`configure`, `sync`, `status`, `search`), which is both
what FR-029 asks for and the only place that can defend against argument injection into `git`.

## Technical Context

**Language/Version**: Markdown (CommonMark) for command prompts and documentation; YAML 1.2
for `extension.yml` and `config-template.yml`. Embedded POSIX shell is illustrative pseudocode
inside the prompts — it documents intent for the executing agent, it is not a shipped script.
No compiled code.

**Primary Dependencies**: spec-kit `>= 0.10.0` and `git >= 2.25`, both already declared in
`extension.yml#requires`. **Nothing new is added.** The freshness gate is deliberately built on
POSIX `find` and the already-used `sha256sum`-or-`shasum` pair, rather than on `python3` or GNU
coreutils.

**Storage**: No new storage locations. Two new optional keys in the existing
`knowledge-config.yml` (`revision` per source; `max_cache_age` global and per source) and one
new optional field in the existing per-source `.manifest.json` (`revision`). The cache root
`.specify/extensions/knowledge/cache/<slug>/` is unchanged in shape; only slug derivation gains
a revision component, and only for sources that pin one.

**Testing**: Manual smoke test in a real spec-kit consumer project — the same approach used by
001, 002, and 003. Constitution §III explicitly waives an automated framework for agent
prompts. The verification walkthrough lives in [quickstart.md](quickstart.md) and covers all
ten Success Criteria.

**Target Platform**: Any POSIX environment with spec-kit `>= 0.10.0` and git `>= 2.25`.
macOS/BSD and Linux/GNU must behave identically — this is an active constraint on the design,
not an assumption (see [research.md](research.md) § R4).

**Project Type**: spec-kit extension package. Agent-prompt Markdown files are the deliverable.
No `src/`, no `tests/`, no build step.

**Performance Goals**: The point of the feature. With `max_cache_age` set above the length of a
working session, one full SDD cycle (specify → clarify → plan → tasks) performs **at most one
network fetch per source** instead of four (SC-004). A freshness-skipped source costs a single
`find` invocation — no `git`, no network.

**Constraints**:
- Exit code 0 on every path, including every path introduced here (FR-023, and the
  extension-wide invariant inherited from 003).
- A project that upgrades and changes nothing must observe byte-identical behavior (FR-024).
  This forbids changing slug derivation for unpinned sources and forbids a non-`off` default
  for `max_cache_age`.
- `config-template.yml` `schema_version` stays `"1.0"` (FR-025) — every new key is optional and
  additive, so no consumer config becomes invalid.
- Automatically triggered syncs must not be able to force a fetch (FR-022). Enforced
  structurally: the four `hooks.*` entries in `extension.yml` declare no arguments, so
  `--force` is unreachable from a hook. This is the same mechanism 003 used for
  `--no-context-output` (FR-016 of that spec) and must not be broken.
- Values read from configuration are interpolated into `git` command lines. Any value that can
  begin with `-` is an argument-injection vector; validation and `--` separators are mandatory,
  not stylistic (see [research.md](research.md) § R5).

**Scale/Scope**: 1 new command file; 3 command files modified; `config-template.yml`,
`extension.yml`, `README.md`, and `CHANGELOG.md` updated. No file is deleted. Command count
goes 4 → 5, which touches Constitution Quality Gate §2 and §5.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

| Principle / Gate | Pre-Design | Post-Design | Notes |
|------------------|:----------:|:-----------:|-------|
| **I. Extension-Package Discipline** — `extension.yml` is the single source of truth | ✅ | ✅ | Adds one `provides.commands` entry and bumps `extension.version`. Hooks unchanged. |
| **I.** — `config-template.yml` `schema_version` bumped on breaking change | ✅ | ✅ | Two new keys, both optional with backward-compatible defaults. Not breaking, so `schema_version` correctly stays `"1.0"` (FR-025). |
| **I.** — Commands are self-contained Markdown with no hidden runtime dependencies | ✅ | ✅ | The new command is one Markdown file. The freshness gate deliberately avoids `python3` and GNU-only tools so nothing undeclared is required. |
| **I.** — Installation delegated entirely to the spec-kit CLI | ✅ | ✅ | No install logic touched. The new command is registered by spec-kit from `extension.yml`. |
| **II. Source-of-Truth Hierarchy** | ✅ | ✅ | Authoring order respected: `extension.yml` → `config-template.yml` → `commands/*.md` → `README.md`. Task ordering in Phase 2 must follow it. |
| **III. Simplicity (YAGNI)** — Markdown-only when expressible as Markdown | ✅ | ✅ | Zero scripts added. The one real temptation — a duration-parsing helper — is avoided by `find -mmin` ([research.md](research.md) § R4). |
| **III.** — No CI / no test framework required | ✅ | ✅ | Verification is the manual walkthrough in [quickstart.md](quickstart.md). |
| **IV. Conventional Commits (NON-NEGOTIABLE)** | ✅ | ✅ | `feat(remove):`, `feat(sync):`, `feat(config):`, `docs(readme):`, `chore(release):`. No `!` — nothing here is breaking. |
| **Naming** — command IDs are `speckit.<ext-id>.<verb>` | ✅ | ✅ | `speckit.knowledge.remove` conforms; the file name matches the ID. |
| **Quality Gate §1** — `extension add --dev` runs clean, config scaffolds | ✅ | ✅ | Regression risk only: `config-template.yml` must stay valid YAML and `provides.config[].name` must keep its `-config.yml` suffix. Covered in [quickstart.md](quickstart.md) step 1. |
| **Quality Gate §2** — all commands registered post-install | ⚙️ changes | ✅ | The gate's literal wording ("all four commands") goes stale. The constitution needs a `docs:` amendment to say **five**; flagged as a task. |
| **Quality Gate §3** — `extension.yml` version matches the release tag | ⚙️ pending bump | ✅ | `1.3.0` → `1.4.0` (minor: additive, backward-compatible). |
| **Quality Gate §4** — CHANGELOG entry exists for the new version | ⚙️ pending entry | ✅ | New `## [1.4.0]` section. |
| **Quality Gate §5** — README command table matches `provides.commands` | ⚙️ pending row | ✅ | README gains a fifth row plus documentation for `revision` and `max_cache_age`. |
| **Extension-wide invariant** — exit-0 on every path | ✅ | ✅ | FR-023 restates it; every new failure mode (unknown label, ambiguous URL, unresolvable revision, invalid field) is a message, not a non-zero exit. |
| **003 contract** — hooks pass no arguments, so flags are hook-unreachable | ✅ | ✅ | `--force` inherits this protection; FR-022 is satisfied structurally rather than by a runtime check. |
| **003 contract** — Context Output Block emission gate | ✅ | ✅ | Two new interactions, both resolved in [data-model.md](data-model.md): a freshness-skipped source counts as usable (FR-020, emit); zero enabled sources emits nothing and deletes the index (FR-031). |

**Gate result**: No violations. Two gates (§2 and §5) require the constitution and README to be
amended as part of implementation rather than indicating a design problem — the Complexity
Tracking section is therefore empty.

## Project Structure

### Documentation (this feature)

```text
specs/004-source-lifecycle-cache/
├── spec.md                          # Feature specification (clarified 2026-09-04)
├── plan.md                          # This file
├── research.md                      # Phase 0 — six resolved decisions
├── data-model.md                    # Phase 1 — config, manifest, and derived entities
├── quickstart.md                    # Phase 1 — manual verification of all ten SC
├── contracts/
│   ├── knowledge-config.schema.md   # Phase 1 — user-facing config contract
│   └── commands.md                  # Phase 1 — CLI surface contract
├── checklists/
│   └── requirements.md              # Authored at specify time; updated post-clarify
└── tasks.md                         # Phase 2 — generated by /speckit.tasks, NOT this command
```

Unlike 003, this feature **does** ship a `contracts/` directory. 003 added only internal stdout;
004 changes the two interfaces consumers actually depend on — the schema of the
`knowledge-config.yml` they commit to their repository, and the set of commands spec-kit
registers on their behalf.

### Source Code (repository root — files this feature touches)

```text
commands/
├── speckit.knowledge.remove.md      # NEW — purge / disable / re-enable a source
├── speckit.knowledge.configure.md   # MODIFIED — accept `revision`; enforce label uniqueness;
│                                    #   adopt the shared read-time validation rules
├── speckit.knowledge.sync.md        # MODIFIED — revision-aware slug; freshness gate; `--force`;
│                                    #   read-time validation; conflict scoping by repository
│                                    #   identity; empty-state index deletion; orphan pruning
└── speckit.knowledge.status.md      # MODIFIED — show effective revision; report freshness-skip
                                     #   distinctly; reconcile the legacy 24h heuristic

config-template.yml                  # MODIFIED — document `revision` and `max_cache_age`
                                     #   (schema_version stays "1.0")
extension.yml                        # MODIFIED — register the fifth command; 1.3.0 → 1.4.0
README.md                            # MODIFIED — fifth command row; lifecycle, pinning,
                                     #   and freshness sections
CHANGELOG.md                         # MODIFIED — new [1.4.0] section
.specify/memory/constitution.md      # MODIFIED — Quality Gate §2 says "four commands"
```

`speckit.knowledge.search.md` is modified **only** if it reads `knowledge-config.yml` directly;
it reads `knowledge-index.md`, so it inherits validation transitively and is expected to stay
untouched. Confirm during `/speckit.tasks`.

**Structure Decision**: The repository has no `src/` or `tests/` tree and will not grow one.
The `commands/` directory *is* the source tree, `config-template.yml` *is* the schema, and
`extension.yml` *is* the build manifest. This mirrors 001–003 and is mandated by
Constitution §III.

## Complexity Tracking

> No Constitution Check violations. Table intentionally empty.

## Phase 0 — Research

Six unknowns were extracted from Technical Context and resolved in
[research.md](research.md):

| # | Question | Decision |
|---|----------|----------|
| R1 | Where does the lifecycle live — new command or a mode of `configure`? | New command `speckit.knowledge.remove` owning purge, disable, and re-enable |
| R2 | How does the cache slug absorb a revision without invalidating existing caches? | Newline-separated hash input, applied **only** when a revision is pinned |
| R3 | What counts as "the same repository" for conflict scoping (FR-026)? | Scheme- and credential-stripped `host/org/repo`; local paths identify by real path |
| R4 | How is cache age compared portably across GNU and BSD? | POSIX `find -mmin` for the gate; existing prose rendering for display |
| R5 | What is the validation rule per field, and where does it run? | Six rules, duplicated verbatim into each reading command; the leading-`-` ban is a security control |
| R6 | How is a pinned commit SHA fetched under `--depth=1`? | Attempt shallow SHA fetch, one deepening retry, then FR-015 cache fallback |

**Two gaps were discovered during research** and are recorded there for `/speckit.tasks` and
`/speckit.analyze` to act on — neither is covered by an existing FR:

1. **Orphaned caches from a revision change.** FR-003 purges the cache on *removal*, but FR-012
   changes the slug when a *revision* changes, stranding the previous directory. Sync must prune
   cache directories that match no configured source (enabled **or** disabled).
2. **The legacy 24-hour heuristic in `status` collides with `max_cache_age`.** `status` today
   hard-codes "fresh = synced within 24h". Once a policy exists the policy must win; the
   heuristic survives only as the no-policy default, for FR-024.

**Output**: [research.md](research.md) — all NEEDS CLARIFICATION resolved.

## Phase 1 — Design & Contracts

**Prerequisites:** [research.md](research.md) complete.

- **[data-model.md](data-model.md)** — the configuration entity and its two new fields, the
  manifest entity and its new field, and three derived (non-persisted) entities: cache slug,
  repository identity, and freshness verdict. Includes the source state machine
  (configured → enabled ⇄ disabled → removed) and the emission-gate decision table that
  reconciles FR-020 and FR-031 with the 003 contract.
- **[contracts/knowledge-config.schema.md](contracts/knowledge-config.schema.md)** — the
  user-facing config contract: every key, its rule, its default, and its
  backward-compatibility guarantee.
- **[contracts/commands.md](contracts/commands.md)** — the CLI surface contract: all five
  commands, their arguments, their flags, and the exit-code invariant.
- **[quickstart.md](quickstart.md)** — a manual walkthrough mapping one verification step to
  each of SC-001 … SC-010.
- **Agent context** — the managed block in [AGENTS.md](../../AGENTS.md) is repointed at this
  plan.

## Next Command

`/speckit.tasks` — generate the dependency-ordered task list. Task ordering must follow
Constitution §II: `extension.yml` and `config-template.yml` first, then `commands/*.md`, then
`README.md`, `CHANGELOG.md`, and the constitution amendment last.
