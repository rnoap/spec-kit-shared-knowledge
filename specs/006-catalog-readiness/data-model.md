# Data Model: Catalog Readiness

**Feature**: [catalog-readiness.spec.md](catalog-readiness.spec.md) · **Plan**: [plan.md](plan.md) · **Research**: [research.md](research.md)

No runtime data changes. `knowledge-config.yml`, `.manifest.json` and `knowledge-index.md` keep their shape, and `schema_version` stays `"1.0"`. What changes are package facts: values the manifest declares, the places that restate them, and the checks that prove them. Each fact has one authoritative value. Every other place either copies it by hand, which is where drift comes from, or derives it at run time.

```text
extension.yml (authoritative, constitution § II)
├── requires.speckit_version ">=0.15.2"
│     ├── copied by hand ──▶ README badge, README Prerequisites, constitution, plan template (§ 2)
│     ├── derived ─────────▶ CI job smoke-minimum installs v<floor> (contracts/ci.md § 3)
│     └── enforced ────────▶ spec-kit refuses an install below it (§ 3)
├── extension.category, extension.effect ──▶ shown by `specify extension info knowledge` (§ 1)
├── extension.version "1.5.0", unchanged ──▶ README status badge and `--from` tag, CHANGELOG
└── provides.commands (5), hooks (4) ──▶ counted by assert-install.sh (§ 5)
```

## 1. Manifest fields

| Field | Today | After | spec-kit rule | Req |
|---|---|---|---|---|
| `requires.speckit_version` | `">=0.10.0"` | `">=0.15.2"` | Must parse as a version specifier. A running spec-kit that does not satisfy it refuses the install. | FR-001 |
| `extension.category` | absent | `integration` | Optional, any non-empty string. | FR-011 |
| `extension.effect` | absent | `read-write` | Optional, exactly `read-only` or `read-write`. | FR-011 |

- Both new keys sit under `extension:`, where spec-kit reads them. They exist since spec-kit 0.10.2, below the new floor, and the minimum-version job proves on every pull request that 0.15.2 accepts them.
- `requires.speckit_version` keeps a `>=` clause, because the minimum-version job installs the release it names and fails when there is none.
- Static validation reads only `extension.id` and `extension.version` from this block, so the new keys pass it untouched.

## 2. Floor statements

One version, stated in six places. The manifest is authoritative and the other five follow in the same pull request (FR-002). Every place writes the literal `>=0.15.2`, so one search for that string measures SC-003. The badge is the one exception: a shields.io path carries `≥` URL-encoded.

| Location | Today | After |
|---|---|---|
| `extension.yml`, `requires.speckit_version` | `">=0.10.0"` | `">=0.15.2"` |
| `README.md` L9, spec-kit badge | `spec--kit-%E2%89%A50.10.0` | `spec--kit-%E2%89%A50.15.2` |
| `README.md` L31, Prerequisites | spec-kit `>= 0.10.0` | spec-kit `>=0.15.2` |
| `.specify/memory/constitution.md` L74 | `>= 0.10.0` | `>=0.15.2` |
| `.specify/templates/plan-template.md` L17 | `>= 0.10.0` | `>=0.15.2` |
| `.specify/templates/plan-template.md` L42 | `>= 0.10.0` | `>=0.15.2` |

Left as written, because they record what was true at the time: `specs/001` to `specs/005`, released CHANGELOG sections, and other extensions' floors under `.specify/extensions/`. The two template rows are the hand edit the plan's Complexity Tracking justifies.

## 3. Install routes

These are spec-kit states the README must describe correctly (FR-004 to FR-008). Exact wording and commands are in [contracts/commands.md](contracts/commands.md) § 1.

| Route | Command | On a default setup | README role |
|---|---|---|---|
| A | `specify extension add knowledge --from <release archive URL>` | `Untrusted Source` prompt, installs once confirmed | primary (FR-005, FR-006) |
| B | `specify extension add knowledge` from a catalog the team controls and marks install-allowed | installs, no prompt | for teams (FR-007) |
| C | `specify extension add knowledge` with spec-kit's built-in catalogs | refused: the community catalog is discovery-only | said to fail on a default setup, never always (FR-004) |
| D | `specify extension add <path> --dev` | installs | unchanged, for contributors and CI |

- spec-kit resolves catalogs from the first of: `SPECKIT_CATALOG_URL`, the project's `.specify/extension-catalogs.yml`, the user's `~/.specify/extension-catalogs.yml`, the built-in stack. The first one found is the whole list, which is why marking the community catalog install-allowed with `catalog add` drops the `default` catalog. FR-008 forbids suggesting it.
- The route A URL names `v<extension.version>`, `v1.5.0` today. At release it must move with the manifest version, or catalog users install the previous release. Nothing checks this automatically.

### State: a `--from` install

```text
PROMPTED ("Untrusted Source", default no)
  ├─ yes ──────────▶ VERSION GATE ─┬─ spec-kit ≥ floor ──▶ INSTALLED: 5 commands, 4 hooks, knowledge-config.yml
  │                                └─ spec-kit < floor ──▶ REFUSED, message names >=0.15.2
  ├─ no / Enter ───▶ CANCELLED, exit 0, nothing installed
  └─ no terminal ──▶ ABORTED, nothing installed; the README documents no way around it
```

A script that checks only the exit code reads CANCELLED as success.

## 4. Command invocation names

The manifest name `speckit.knowledge.<verb>` is canonical. spec-kit renders it per agent at install time, so what a user types depends on the agent and the spec-kit version, never on this extension.

| Form | Example | Used by |
|---|---|---|
| Dot | `/speckit.knowledge.sync` | agents that install prompts or slash commands, such as Copilot on spec-kit 1.0.4; every README example |
| Skills | `/speckit-knowledge-sync` | agents that install skills, such as Copilot on spec-kit 1.1.2 |
| Codex | `$speckit-knowledge-sync` | Codex |

- README examples keep the dot form: static validation requires `/speckit.knowledge.<verb>` for every command.
- The other forms appear only in the README note (FR-009). Under `commands/`, a literal `/speckit-` or `$speckit-` fails the portability check, so command bodies keep their `__SPECKIT_COMMAND_*__` tokens.

## 5. Install assertions

`assert-install.sh` reads the manifest for every expected value, then checks the consumer project. Its interface is unchanged. What changes is how it reports a broken install (FR-016, FR-017):

| Check | Today, on an aborted install | After |
|---|---|---|
| Commands registered | count reads `0` twice and the `[` test errors | one integer, `0` when nothing matches or the log is missing |
| Files copied | a `find` error, then `PASS installed file count is sane (0)` | 0 files fails with a readable line |
| Hooks registered | Python `FileNotFoundError` traceback | fails with a message naming the missing file |

Every assertion still runs after an earlier failure (`set -uo pipefail`, no `-e`), so one broken install reports all its failures. The seeded cases for SC-005 and the exact lines are in [contracts/ci.md](contracts/ci.md) § 4.

## 6. Constitution record

| Field | Today | After |
|---|---|---|
| Version | 1.1.0 | 1.2.0 (research § 8) |
| Last Amended | 2026-09-04 | the date of the amending commit |
| Rationale notes | `1.1.0 rationale` | adds `1.2.0 rationale`, same blockquote style |
| Requirements & Compatibility | spec-kit `>= 0.10.0` | spec-kit `>=0.15.2` |
| Quality Gates, Install smoke test | one run, at the pinned release | two runs: the pinned newest release and the manifest's floor |

One `docs(constitution):` commit lands it (Governance, Principle IV). Smoke check 4 already reads "the installed file count is sane", which covers a non-zero lower bound, so its wording stays.
