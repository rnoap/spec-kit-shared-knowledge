# spec-kit-shared-knowledge Constitution

> **What this project is**: A spec-kit extension package that injects shared/cross-repo knowledge into any SDD workspace. It is a distribution artifact (Bash scripts + YAML manifests + Markdown agent prompts), not a compiled application.

## Core Principles

### I. Extension-Package Discipline

This project IS a spec-kit extension, so every change must remain installable by consumers:

- `extension.yml` is the single source of truth for the package manifest (id, version, commands, hooks, requirements).
- `config-template.yml` is the canonical user-facing config schema. Its `schema_version` must be bumped on any breaking schema change.
- Commands (`commands/*.md`) are **agent prompts**; they must be self-contained Markdown documents — no hidden runtime dependencies outside of what `extension.yml` declares.
- Install logic lives exclusively in `scripts/install-local.sh`. No other script may mutate a consumer's `.specify/` directory.

### II. Source-of-Truth Hierarchy

When any two artifacts conflict, resolve using this order (highest → lowest authority):

1. `extension.yml` — package contract and version
2. `config-template.yml` — config schema
3. `commands/*.md` — agent behavior
4. `scripts/install-local.sh` — install mechanics
5. `README.md` — user documentation (must stay in sync with 1–4)

### III. Simplicity (YAGNI)

- No compiled code. Bash + YAML + Markdown only.
- No test framework required for the extension package itself (agent prompts cannot be unit-tested in the traditional sense).
- No CI/CD pipeline exists yet; quality gates are manual (install and smoke-test before tagging a release).
- If a feature can be expressed as a Markdown addition to a command file, it MUST NOT become a Bash script.

### IV. Conventional Commits (NON-NEGOTIABLE)

Every commit **must** follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>[optional scope]: <description>

Types: feat | fix | refactor | docs | chore | test | style
```

- `feat:` — new command, new config key, or new hook
- `fix:` — corrects incorrect behavior in an existing command or script
- `refactor:` — restructures without changing external behavior
- `docs:` — README, CHANGELOG, or inline comment updates only
- `chore:` — CHANGELOG housekeeping, version bump, dependency update
- **Breaking changes**: append `!` after type (e.g., `feat!:`) and describe in commit body

## Naming Conventions

- **Extension ID**: `knowledge` (kebab-compatible, no version suffix). Repository name is `spec-kit-shared-knowledge` (descriptive); display name in the manifest is `Shared Knowledge`.
- **Command IDs**: dot-notation `speckit.<ext-id>.<verb>` where `<ext-id>` matches the extension id. Examples: `speckit.knowledge.sync`, `speckit.knowledge.search`. The pattern `^speckit\.{ext-id}\.{command}$` is enforced by spec-kit validation.
- **Command files**: dot-notation matching the command ID, with `.md` suffix: `speckit.knowledge.sync.md`. Skill wrappers in `.claude/skills/` use kebab-case (`speckit-knowledge-sync/SKILL.md`).
- **Script files**: kebab-case with `.sh` extension (e.g., `install-local.sh`)
- **Config keys**: snake_case in YAML
- **Spec directories**: `NNN-kebab-case` under `specs/` where `NNN` is a zero-padded three-digit sequential number (e.g., `001-auth-flow`, `002-sync-command`). Both `speckit-specify` and `speckit-brownfield-migrate` assign numbers automatically.

## Code Boundaries

| Directory / File | Purpose | Who touches it |
|-----------------|---------|---------------|
| `commands/` | Agent prompt Markdown files (the extension's deliverable) | Extension authors |
| `scripts/` | Install tooling only (`install-local.sh`) | Extension authors |
| `extension.yml` | Package manifest | Extension authors; bump `version` on every release |
| `config-template.yml` | User-facing config schema (no-clobber install) | Extension authors; bump `schema_version` on breaking changes |
| `README.md` | User documentation | Extension authors; must mirror `extension.yml` commands list |
| `CHANGELOG.md` | Release history (Keep a Changelog format) | Extension authors; update before every version tag |
| `.specify/` | Spec-kit workspace for THIS project's own features | SDD tooling; do not hand-edit |
| `specs/` | Feature specs for THIS project | Extension authors via `/speckit-specify` |

**Never** commit `node_modules/`, `__pycache__/`, `.venv/`, or consumer `.specify/` directories.

## Requirements & Compatibility

- **spec-kit**: `>= 0.10.0`
- **git**: `>= 2.25`
- **Shell**: POSIX-compatible `bash` (scripts must not require `zsh` or `fish` features)
- **License**: MIT

## Quality Gates (Manual — no CI)

Before tagging a release:

1. `bash scripts/install-local.sh` runs to completion without errors in a clean consumer project.
2. All four commands are registered and visible via `specify extension list`.
3. `extension.yml` `version` matches the intended git tag.
4. `CHANGELOG.md` has an entry for the new version.
5. `README.md` command table matches `extension.yml` `provides.commands`.

## Governance

- This constitution supersedes all other practices when conflicts arise.
- Amendments require a `docs:` commit updating this file with a rationale comment.
- There is no automated enforcement yet; compliance is verified during code review and pre-release checklist.

**Version**: 1.0.0 | **Ratified**: 2026-06-17 | **Last Amended**: 2026-06-17
