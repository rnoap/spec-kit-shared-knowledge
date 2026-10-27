# spec-kit-shared-knowledge Constitution

> **What this project is**: A spec-kit extension package that injects shared/cross-repo knowledge into any SDD workspace. It is a distribution artifact (YAML manifests + Markdown agent prompts), not a compiled application.

## Core Principles

### I. Extension-Package Discipline

This project IS a spec-kit extension, so every change must remain installable by consumers:

- `extension.yml` is the single source of truth for the package manifest (id, version, commands, hooks, requirements).
- `config-template.yml` is the canonical user-facing config schema. Its `schema_version` must be bumped on any breaking schema change.
- Commands (`commands/*.md`) are **agent prompts**; they must be self-contained Markdown documents — no hidden runtime dependencies outside of what `extension.yml` declares.
- Installation is delegated entirely to the spec-kit CLI (`specify extension add` / `specify extension add --dev`). The repository ships no install script and no project may mutate a consumer's `.specify/` directory outside of what spec-kit's own auto-registration covers.
- **Shipped files cite nothing the consumer does not have.** `commands/*.md`, `extension.yml`,
  `config-template.yml` and `README.md` MUST NOT carry this repository's requirement IDs
  (`FR-…`, `SC-…`), spec numbers (`spec 004`, `007 FR-006`) or task IDs (`T012`), and the
  agent-facing files MUST NOT point into this repository's development workspace (`specs/NNN-…/`,
  `specs/tiny/`, `.specify/memory/`, `.specify/bugs/`, `.specify/assessments/`). State the rule
  itself, not its number. Requirement traceability lives in `specs/` (each feature's `tasks.md`)
  and in git history. Not citations: the extension's runtime paths in the consumer project
  (`.specify/extensions/knowledge/…`) and example paths shown to users, such as
  `specs/012-order-tracking/` in a configuration example.

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

```text
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
| --- | --- | --- |
| `commands/` | Agent prompt Markdown files (the extension's deliverable) | Extension authors |
| `extension.yml` | Package manifest | Extension authors; bump `version` on every release |
| `config-template.yml` | User-facing config schema (no-clobber install) | Extension authors; bump `schema_version` on breaking changes |
| `README.md` | User documentation | Extension authors; must mirror `extension.yml` commands list |
| `CHANGELOG.md` | Release history (Keep a Changelog format) | Extension authors; update before every version tag |
| `.specify/` | Spec-kit workspace for THIS project's own features | SDD tooling; do not hand-edit except `.specify/memory/` and the project-owned templates listed below |
| `.specify/templates/*-template.md` | Project-owned SDD templates | Extension authors may edit these files to reflect this constitution and the package contract. Review changes and preserve customizations across toolchain upgrades. This permission does not extend to scripts, installed extensions, presets, or generated agent files |
| `.github/workflows/`, `.github/scripts/` | Automated quality gates (§ Quality Gates) | Extension authors. Excluded from both the published archive and the installed copy, so they cost consumers nothing |
| `specs/` | Feature specs for THIS project | Extension authors via `/speckit-specify` |

**Never** commit `node_modules/`, `__pycache__/`, `.venv/`, or consumer `.specify/` directories.

## Requirements & Compatibility

- **spec-kit**: `>=0.15.2`
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
12. Every configuration placeholder in a ```` ```bash ```` block under `commands/`
   sits inside single quotes opened in an unquoted context, so a configured
   value reaches the shell as one literal argument. Double-quoted, escaped and
   ambiguous quote contexts fail the check; inert scanner fixtures enforce this
   distinction. `<slug>`, which the extension computes, is the only exemption.
13. No shipped file (`commands/*.md`, `extension.yml`, `config-template.yml`,
    `README.md`) cites a requirement ID (`FR-…`, `SC-…`), a spec number, a task
    ID, or a path into `specs/tiny/` or `.specify/memory|bugs|assessments/` (§I).
    `specs/NNN-…` paths are not matched, because user-facing examples use them.

**Install smoke test** — a real `specify extension add` into a clean consumer
project, asserting against the manifest rather than hardcoded numbers. It runs
twice: against the spec-kit release pinned in `SPEC_KIT_REF`, and against the
minimum the manifest declares in `requires.speckit_version`. Each run checks:

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

**Version**: 1.6.0 | **Ratified**: 2026-06-17 | **Last Amended**: 2026-10-27

> **1.1.0 rationale.** §III previously stated "No CI/CD pipeline exists yet;
> quality gates are manual." That principle was the root cause of the v1.2.0
> release: eight defects reached `main`, and four of them were found only because
> someone happened to install the extension by hand. A manual gate that nothing
> forces is not a gate. The packaging contract is now enforced on every pull
> request. Also folded in: Quality Gate §2 corrected from four commands to five,
> and § Code Boundaries exempted `.specify/memory/` from its no-hand-edit rule,
> which § Governance had always required contradicting.
>
> **1.2.0 rationale.** Project-owned templates restate the package contract and
> need authored updates when it changes. Code Boundaries now permits those
> updates explicitly instead of asking feature plans to justify a prohibited
> edit. Scripts, installed extensions, presets and generated agent files remain
> tooling-owned. The package compatibility floor and quality gates are unchanged.
>
> **1.3.0 rationale.** The stated floor, `>= 0.10.0`, was false. On spec-kit
> 0.10.0 the install ran but never created `knowledge-config.yml`: spec-kit
> scaffolds config templates only since 0.15.2, and skills render command
> references only since 0.12.17. The floor is now `>=0.15.2`, the oldest release
> verified to install correctly. A floor nothing tests drifts back into fiction,
> so the install smoke test now also runs against the minimum the manifest
> declares, on every pull request.
>
> **1.4.0 rationale.** Configuration values must reach the shell as literal
> arguments even when validation is bypassed. Static check 12 tracks effective
> quote context, and inert fixtures reject double-quoted and escaped lookalikes.
> This extends the packaging gates without executing command prose in CI.
>
> **1.5.0 rationale.** The command files cited 193 of this repository's requirement IDs, such as
> `(007 FR-006)`. They are the prompts an agent runs in a consumer project, where `specs/` does
> not exist: it is excluded from the published archive. The IDs pointed nowhere, and the
> consumer's own specs carry their own `FR-` numbers, which an agent can take for the one cited.
> §I now forbids such citations in shipped files. The existing IDs are removed by
> `specs/tiny/004-strip-internal-spec-refs-from-shipped-files.md`, which also adds static check
> 13 to enforce the rule. § Quality Gates lists that check only once it exists.
>
> **1.6.0 rationale.** Static check 13 now enforces the §I rule from 1.5.0 on every
> pull request. The shipped files no longer cite any requirement ID: a sentence that
> leaned on one now states the rule it stood for. A rule nothing checks drifts back,
> as the 193 IDs showed.
