# Implementation Plan: [FEATURE]

**Branch**: `[###-feature-name]` | **Date**: [DATE] | **Spec**: [link]

**Input**: Feature specification from `/specs/[###-feature-name]/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

[Extract from feature spec: primary requirement + technical approach from research]

## Technical Context

**Language/Version**: Bash (POSIX-compatible), YAML 1.2, Markdown (CommonMark)

**Primary Dependencies**: spec-kit `>= 0.10.0`, git `>= 2.25` — no compiled runtime, no package manager lock file

**Storage**: Files only — `commands/*.md`, `scripts/*.sh`, `extension.yml`, `config-template.yml`; consumer state written to their `.specify/` directory by `install-local.sh`

**Testing**: Manual smoke test — run `bash scripts/install-local.sh` in a clean consumer project; verify via `specify extension list` and per-command invocation. No automated test framework.

**Target Platform**: Any POSIX shell environment where spec-kit and git are installed (macOS, Linux)

**Project Type**: spec-kit extension package (distribution artifact — not a compiled binary or web service)

**Performance Goals**: `install-local.sh` completes in < 5 seconds on a warm filesystem; N/A for command prompts (agent execution time is outside this project's scope)

**Constraints**: No external network calls at install time; `config-template.yml` must not clobber an existing consumer config (no-clobber install); extension must remain backwards-compatible with spec-kit `0.10.x`

**Scale/Scope**: Small package — 4 commands, 1 install script, 1 config template; changes are additive; breaking changes require a `MAJOR` version bump in `extension.yml`

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
# Extension package layout (no src/ — files are the deliverable)
commands/
└── speckit.knowledge.<verb>.md              # agent prompt for each command (namespace: knowledge)

scripts/
└── install-local.sh                     # install tooling (only script allowed)

extension.yml                            # package manifest
config-template.yml                      # user-facing config schema
README.md
CHANGELOG.md

specs/NNN-<feature-name>/               # this feature's SDD docs
├── spec.md
├── plan.md
└── tasks.md
```

**Structure Decision**: This project has no compiled source. The deliverable is the files themselves. New features add or modify files in `commands/`, `scripts/`, or the root manifests. No `src/`, `tests/`, `frontend/`, or `backend/` directories exist or are needed.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |
