# spec-kit-shared-knowledge Constitution

> **What this project is**: A spec-kit extension package that injects shared/cross-repo knowledge into any SDD workspace. It is a distribution artifact (YAML manifests + Markdown agent prompts), not a compiled application.

## Core Principles

### I. Extension-Package Discipline

This project IS a spec-kit extension, so every change must remain installable by consumers:

- `extension.yml` is the single source of truth for the package manifest (id, version, commands, hooks, requirements).
- `config-template.yml` is the canonical user-facing config schema. Its `schema_version` must be bumped on any breaking schema change.
- Commands (`commands/*.md`) are **agent prompts**; they must be self-contained Markdown documents — no hidden runtime dependencies outside of what `extension.yml` declares.
- Installation is delegated entirely to the spec-kit CLI (`specify extension add` / `specify extension add --dev`). The repository ships no install script and no project may mutate a consumer's `.specify/` directory outside of what spec-kit's own auto-registration covers.

### II. Source-of-Truth Hierarchy

When any two artifacts conflict, resolve using this order (highest → lowest authority):

1. `extension.yml` — package contract and version
2. `config-template.yml` — config schema
3. `commands/*.md` — agent behavior
4. `README.md` — user documentation (must stay in sync with 1–3)

### III. Simplicity (YAGNI)

- No compiled code. Bash + YAML + Markdown only.
- No test framework required for the extension package itself (agent prompts cannot be unit-tested in the traditional sense).
- **The packaging contract IS enforced automatically.** Agent prompts cannot be unit-tested, but the manifest, the install result, and the published artifact are all mechanically checkable — and every one of them has broken in production. Those checks run on every pull request; see § Quality Gates.
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
- **Config keys**: snake_case in YAML
- **Spec directories**: `NNN-kebab-case` under `specs/` where `NNN` is a zero-padded three-digit sequential number (e.g., `001-auth-flow`, `002-sync-command`). Both `speckit-specify` and `speckit-brownfield-migrate` assign numbers automatically.

## Code Boundaries

| Directory / File | Purpose | Who touches it |
|-----------------|---------|---------------|
| `commands/` | Agent prompt Markdown files (the extension's deliverable) | Extension authors |
| `extension.yml` | Package manifest | Extension authors; bump `version` on every release |
| `config-template.yml` | User-facing config schema (no-clobber install) | Extension authors; bump `schema_version` on breaking changes |
| `README.md` | User documentation | Extension authors; must mirror `extension.yml` commands list |
| `CHANGELOG.md` | Release history (Keep a Changelog format) | Extension authors; update before every version tag |
| `.specify/` | Spec-kit workspace for THIS project's own features | SDD tooling; do not hand-edit — **except `.specify/memory/`**, which § Governance requires amending by hand |
| `.github/workflows/`, `.github/scripts/` | Automated quality gates (§ Quality Gates) | Extension authors. Excluded from both the published archive and the installed copy, so they cost consumers nothing |
| `specs/` | Feature specs for THIS project | Extension authors via `/speckit-specify` |

**Never** commit `node_modules/`, `__pycache__/`, `.venv/`, or consumer `.specify/` directories.

## Requirements & Compatibility

- **spec-kit**: `>= 0.10.0`
- **git**: `>= 2.25`
- **License**: MIT

## Quality Gates (Automated — `.github/workflows/validate.yml`)

Enforced on **every pull request**, not only before a release. This section was
rewritten after v1.2.0, which fixed eight defects that had all reached `main`.
Four of them were found only by installing the extension into a clean project by
hand — and nothing had forced anyone to do that. "Verified during code review" was
not a gate; it was a hope.

**Static validation** — `.github/scripts/validate-extension.sh`, also runnable
locally before you push:

1. `extension.yml` parses, and declares a version.
2. Every `provides.config[].name` ends in `-config.yml` / `-config.local.yml`.
   Anything else is silently not scaffolded, **and** is deleted by
   `extension add --force`, which can destroy a user's configured source list.
3. `provides.config[]` uses only schema keys — unknown ones are ignored silently.
4. Every `provides.commands[].file` exists, and every name matches
   `^speckit\.<ext-id>\.<verb>$`.
5. Command bodies use `__SPECKIT_COMMAND_*__` tokens, never a hard-coded
   agent-specific invocation.
6. `README.md` badge matches the manifest version.
7. `CHANGELOG.md` has an entry for the manifest version.
8. `README.md` documents every command in `provides.commands`.
9. `git archive` — which is what the catalog `download_url` serves — carries no
   dev-only path.
10. No hook declares arguments. That is what keeps `--force` structurally
    unreachable from an automatic trigger (spec 004, FR-022).
11. The Configuration Validation Rules block is byte-identical across the three
    commands that duplicate it. §I forbids extracting it to a shared file, so
    duplication is only safe while the copies cannot drift.

**Install smoke test** — a real `specify extension add` into a clean consumer
project, asserting against the manifest rather than hardcoded numbers:

1. No "Config templates not scaffolded" warning, and the declared config file
   exists on disk afterwards.
2. Every declared command is registered.
3. The reported version matches the manifest.
4. The installed file count is sane. A `.extensionignore` gap once copied 110
   files into consumers, 86 belonging to other extensions entirely.
5. Hooks auto-register, in the declared number, none carrying arguments.

**Still manual, and honestly so.** Nothing above tests what a command *does* —
agent prompts are interpreted by a model at runtime, so the walkthrough in each
feature's `quickstart.md` remains the only check on behavior. CI guards the
package, not the prose.

## Governance

- This constitution supersedes all other practices when conflicts arise.
- Amendments require a `docs:` commit updating this file with a rationale comment.
- The packaging contract in § Quality Gates is enforced automatically on every
  pull request. Everything else — principles, naming, boundaries, and whether a
  command actually behaves as its prose claims — is verified by human review.

**Version**: 1.1.0 | **Ratified**: 2026-06-17 | **Last Amended**: 2026-09-04

> **1.1.0 rationale.** §III previously stated "No CI/CD pipeline exists yet;
> quality gates are manual." That principle was the root cause of the v1.2.0
> release: eight defects reached `main`, and four of them were found only because
> someone happened to install the extension by hand. A manual gate that nothing
> forces is not a gate. The packaging contract is now enforced on every pull
> request. Also folded in: Quality Gate §2 corrected from four commands to five,
> and § Code Boundaries exempted `.specify/memory/` from its no-hand-edit rule,
> which § Governance had always required contradicting.
