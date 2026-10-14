# Contract: `extension.yml` — compatibility floor and catalog metadata

**Feature**: [../catalog-readiness.spec.md](../catalog-readiness.spec.md) · **Plan**: [../plan.md](../plan.md) · **Research**: [../research.md](../research.md)

spec-kit reads the manifest to decide whether it may install the extension, and to describe it.
This feature changes three fields. Everything else — `schema_version`, `extension.version`,
`provides`, `hooks`, `tags` — stays as it is, and nothing is version-bumped.

---

## 1. Fields

```yaml
schema_version: "1.0"            # unchanged

extension:
  id: knowledge                  # unchanged, as are name, version "1.5.0", description,
                                 # author, repository, homepage and license
  category: integration          # NEW (FR-011)
  effect: read-write             # NEW (FR-011)

requires:
  speckit_version: ">=0.15.2"    # was ">=0.10.0" (FR-001)
  tools:                         # unchanged
    - name: git
      required: true
```

| Field | Exact value | Read by | Rule spec-kit enforces |
|---|---|---|---|
| `requires.speckit_version` | `>=0.15.2` | `specify extension add`; the minimum-version CI job ([ci.md § 3](ci.md#3-the-minimum-version-job-fr-014)) | A string that parses as a version specifier |
| `extension.category` | `integration` | `specify extension info` | Non-empty string. Free-form; common values are `docs`, `code`, `process`, `integration`, `visibility` |
| `extension.effect` | `read-write` | `specify extension info` | Exactly `read-only` or `read-write` |

- Both new keys go under `extension:`. That is where spec-kit reads them.
- A value that breaks its rule fails manifest validation, and spec-kit refuses the install.
- `requires.speckit_version` must keep a `>=` clause. The minimum-version job tests the release
  that clause names and fails when there is none: `>=0.15.2,<2` would still work, `~=0.15` would not.

---

## 2. Observable behaviour

| Situation | Result |
|---|---|
| spec-kit older than 0.15.2 | Install refused, nothing installed, with a message naming `>=0.15.2` (SC-002). spec-kit 1.2.0 words it `Extension requires spec-kit >=0.15.2, but <installed> is installed.` The user's own, older release prints the refusal, so verify it on a release just below the floor (US2 independent test) |
| spec-kit 0.15.2 or newer | 5 commands, 4 hooks, and `knowledge-config.yml` under `.specify/extensions/knowledge/` (US2 AS2) |
| `specify extension info knowledge`, installed | `Category: integration` and `Effect: read-write`, read from the installed manifest (US3 AS1, SC-007) |

Before installation, `specify extension info` shows the catalog entry's values instead. The catalog
submission is out of scope; when it happens, its entry should carry the same three values.

Why 0.15.2: [research § 1](../research.md#1-the-floor-is-0152).

---

## 3. Every other statement of the floor (FR-002, SC-003)

Each location states the floor in the verbatim form `>=0.15.2`, without the space today's prose
uses, so one literal search finds them all. The badge is the exception: a shields.io path carries
`≥` URL-encoded.

| Location | Today | After |
|---|---|---|
| `extension.yml` → `requires.speckit_version` | `">=0.10.0"` | `">=0.15.2"` |
| `README.md` spec-kit badge | `badge/spec--kit-%E2%89%A50.10.0-7d4cdb` | `badge/spec--kit-%E2%89%A50.15.2-7d4cdb`, rendering `≥0.15.2` |
| `README.md` § Prerequisites | spec-kit `>= 0.10.0` | spec-kit `>=0.15.2` |
| `.specify/memory/constitution.md` § Requirements & Compatibility | `>= 0.10.0` | `>=0.15.2` |
| `.specify/templates/plan-template.md`, **Primary Dependencies** line | spec-kit `>= 0.10.0` | spec-kit `>=0.15.2` |
| `.specify/templates/plan-template.md`, compatibility constraint | `>= 0.10.0` | `>=0.15.2` |

- **Left as written**: `CHANGELOG.md` entries for released versions and `specs/001`–`specs/005`,
  which record what was true at the time; the floors declared by other extensions under
  `.specify/extensions/`.
- **The status badge is a different badge.** Static validation compares `badge/status-v1.5.0`
  with `extension.version`, and both stay unchanged.
- **The template is project-owned.** `.specify/templates/plan-template.md` states the floor on lines 17
  and 42. spec-kit resets it on a `--force` upgrade, and `395c326` restored it by hand, so a later
  upgrade must keep these two lines too.
