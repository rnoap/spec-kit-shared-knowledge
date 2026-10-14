# Implementation Plan: Catalog Readiness

**Branch**: `006-catalog-readiness` | **Date**: 2026-10-14 | **Spec**: [catalog-readiness.spec.md](./catalog-readiness.spec.md)

## Summary

Make the package tell catalog users the truth, and make CI prove it. The manifest's spec-kit floor moves to `>=0.15.2`, and every place that restates it follows: the README badge and prerequisites, the constitution, and the plan template. The manifest also gains `category: integration` and `effect: read-write`. The README leads its catalog install with `--from <release zip>`, because spec-kit's community catalog is discovery-only by default, and adds the per-agent command names and the supported platforms. The status reachability call gains `--`, CI installs against v1.2.0 and against the floor the manifest declares, and the install assertions stop passing a broken install.

Before publication, a loopback catalog fixture proves the discovery-only refusal. The v1.5.0 archive is a historical download check, not evidence for this feature. After all story phases join, validate an archive containing the current working-tree bytes and execute the installed commands through the agent.

## Project Structure

```text
extension.yml                        # requires.speckit_version ">=0.15.2"; extension.category, extension.effect
README.md                            # spec-kit badge; Prerequisites + platforms; Installation › catalog; Commands note
CHANGELOG.md                         # entries under [Unreleased]
commands/
└── speckit.knowledge.status.md      # § 3 Check reachability: `--` before <url> (outside the duplicated validation block)
.github/
├── workflows/validate.yml           # SPEC_KIT_REF v1.2.0; new job "Install smoke test (minimum spec-kit)"
└── scripts/assert-install.sh        # single-number command count; zero files fails; readable FAIL when hooks file is absent
.specify/
├── memory/constitution.md           # floor; Install smoke test runs twice; version 1.3.0 + rationale
└── templates/plan-template.md       # floor restated on L17 and L42
```

**Structure Decision**: Edit in place. Nothing new ships to consumers, since `.github/` and `.specify/` are excluded from the archive and the install. The minimum-version run is a second job in `validate.yml` that reads the floor from the manifest and reuses `assert-install.sh`.

## Constitution Check

| Principle | Assessment |
| --- | --- |
| I. Extension-Package Discipline | PASS. The manifest stays the single source of truth. No new runtime dependency, commands stay self-contained, install stays with the spec-kit CLI. |
| II. Source-of-Truth Hierarchy | PASS. The floor changes in the manifest first, and the README, constitution and template follow in the same change, so no two artifacts disagree. |
| III. Simplicity (YAGNI) | PASS. No new script. The new CI job reuses the existing assertion script, in Bash and YAML only. |
| IV. Conventional Commits | PASS. One commit per concern: `chore(manifest)`, `docs(readme)`, `fix(status)`, `fix(ci)`, `chore(ci)`, `docs(constitution)`. |
| Naming Conventions | PASS. No new command, id or config key. |
| Code Boundaries | PASS. Constitution 1.2.0 explicitly assigns project-owned templates to extension authors. No exception is inferred from a feature plan. |
| Requirements & Compatibility | PASS once amended. The floor becomes `>= 0.15.2`, with a rationale. |
| Quality Gates | PASS. Static validation still holds: the manifest version, README badge and CHANGELOG entry are unchanged, the README keeps every dot-form command, and the status edit sits outside the byte-identical validation block. The smoke test gets stronger, and the required check names stay. |
| Governance | PASS. The compatibility and CI amendment lands as a `docs:` commit with a rationale note, constitution version 1.2.0 to 1.3.0. The template-authorship amendment is a separate prerequisite. |

Re-checked after Phase 1 design: unchanged.
