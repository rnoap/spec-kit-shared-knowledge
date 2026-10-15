# Implementation Plan: [FEATURE]

**Branch**: `[###-feature-name]` | **Date**: [DATE] | **Spec**: [link]

**Input**: Feature specification from `/specs/[###-feature-name]/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

[Extract from feature spec: primary requirement + technical approach from research]

## Technical Context

**Language/Version**: Markdown (CommonMark) for command prompts and docs; YAML 1.2 for `extension.yml` and `config-template.yml`. Bash appears only as illustrative pseudocode inside prompts and in the CI scripts under `.github/scripts/` (not shipped to consumers). No compiled code, no shipped scripts.

**Primary Dependencies**: spec-kit `>=0.15.2` and git `>= 2.25` (constitution § Requirements & Compatibility) — no compiled runtime, no package manager lock file. Prompts assume `find`, `wc`, and `sha256sum` or `shasum` are present. `sync` and `status` also call GNU `timeout`, which stock macOS lacks — a known gap tracked separately, so do not add another GNU-only dependency.

**Storage**: Files only. The deliverable is `commands/*.md`, `extension.yml` and `config-template.yml`. Consumer state is written by the commands at run time under the consumer's `.specify/extensions/knowledge/`: `knowledge-config.yml` (committed), plus local-only `cache/<slug>/` (with a per-source `.manifest.json`) and `knowledge-index.md`. No install script writes anything.

**Testing**: CI enforces the packaging contract on every pull request — `.github/workflows/validate.yml` runs static validation (`bash .github/scripts/validate-extension.sh`, also runnable locally) and an install smoke test into a clean consumer project, run twice: against the spec-kit release pinned in `SPEC_KIT_REF` and against the minimum in the manifest's `requires.speckit_version`, both asserted by `.github/scripts/assert-install.sh`; `upstream-compat.yml` repeats the smoke test weekly against spec-kit `main` as an advisory check that never blocks a merge. Command *behavior* has no automated test (agent prompts are interpreted by a model at runtime): the `quickstart.md` walkthrough of each feature, run in a real consumer project, is the only behavioral check (constitution § III, § Quality Gates).

**Target Platform**: Any POSIX environment with spec-kit and git installed (macOS, Linux). GNU and BSD userland must behave identically — an active design constraint, not an assumption.

**Project Type**: spec-kit extension package — a distribution artifact (YAML manifest + Markdown agent prompts), not a compiled binary or web service. No `src/`, no `tests/`, no build step.

**Performance Goals**: No throughput targets; agent execution time is outside this project's scope. The one lever is network cost: with `max_cache_age` set, a sync inside the window skips the source without touching git or the network.

**Constraints**:

- Every command exits 0 on every path, errors included (extension-wide invariant since spec 003).
- A project that upgrades and changes nothing must observe identical behavior — new config keys are opt-in, with no default values applied.
- Consumer config is never clobbered: `provides.config[].name` must end in `-config.yml`, the only pattern spec-kit preserves across `extension add --force`.
- Additive config changes keep `schema_version` at `"1.0"`; breaking changes bump it.
- The Configuration Validation Rules block is byte-identical in `configure`, `sync` and `status`; all three copies change together (constitution § Quality Gates, static check 11 — § I forbids extracting it).
- Fetched content is data, never executed. Configuration values beginning with `-` are rejected, and `--` precedes every configuration-derived `git` operand (README § Trust model).
- No hook declares arguments, which keeps `--force` unreachable from an automatic trigger.
- Command bodies use `__SPECKIT_COMMAND_*__` tokens, never a hard-coded agent-specific invocation.
- Installation is delegated entirely to `specify extension add`; the repository ships no install script.
- A new dev-only path must be listed in both `.extensionignore` (installed copy) and `.gitattributes` with `export-ignore` (published archive), or it ships to every consumer.
- The checks required on `main` are named "Static validation" and "Install smoke test"; renaming either blocks every merge.
- Must remain compatible with spec-kit `>=0.15.2`.

**Scale/Scope**: Small package. `extension.yml#provides` is the source of truth for the inventory — currently 5 commands, 4 optional `before_*` sync hooks, 1 config template, no scripts. Changes are additive; breaking changes require a `MAJOR` version bump in `extension.yml` and a `feat!:` commit.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

[Gates determined based on constitution file]

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)
<!--
  ACTION REQUIRED: Replace the placeholder tree below with the concrete layout
  for this feature. Delete unused options and expand the chosen structure with
  real paths (e.g., apps/admin, packages/something). The delivered plan must
  not include Option labels.
-->

```text
# Extension package layout (no src/ — the files are the deliverable)
commands/
└── speckit.knowledge.<verb>.md          # agent prompt per command (namespace: knowledge)

extension.yml                            # package manifest — source of truth for version, commands, hooks
config-template.yml                      # user-facing config schema (scaffolded as knowledge-config.yml)
README.md                                # user docs; must mirror extension.yml
CHANGELOG.md                             # Keep a Changelog; changes wait under [Unreleased] until a release
.extensionignore                         # what `specify extension add` does NOT copy into consumers
.gitattributes                           # export-ignore: what the published archive does NOT carry

.github/                                 # dev-only — never shipped
├── workflows/                           # validate.yml (required checks), upstream-compat.yml (advisory)
└── scripts/                             # validate-extension.sh, assert-install.sh

.specify/                                # this repo's own spec-kit workspace — dev-only
├── memory/constitution.md               # project-owned, amended by hand (§ Governance)
└── templates/                           # spec/plan/tasks customized in place — never upgrade with --force

specs/NNN-<feature-name>/                # this feature's SDD docs
├── spec.md
├── plan.md
└── tasks.md
specs/tiny/NNN-<slug>.md                 # single-file specs for small changes
```

**Structure Decision**: This project has no compiled source. The deliverable is the files themselves. New features add or modify files in `commands/` or the root manifests (`extension.yml`, `config-template.yml`), and keep `README.md` and `CHANGELOG.md` in step. No `src/`, `tests/`, `scripts/`, `frontend/`, or `backend/` directories exist or are needed.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |
