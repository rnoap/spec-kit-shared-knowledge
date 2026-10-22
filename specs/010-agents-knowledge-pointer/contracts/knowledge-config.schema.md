# Contract: `knowledge-config.yml` (`agents_md`)

**Feature**: [../agents-knowledge-pointer.spec.md](../agents-knowledge-pointer.spec.md) · **Plan**: [../plan.md](../plan.md) · **Research**: [../research.md](../research.md)

The user-facing configuration contract. This file is committed and shared, so one teammate's `agents_md` value decides whether every teammate's sync edits `AGENTS.md`.

`schema_version` remains **`"1.1"`**. The new key is optional and defaults to the new behavior. Every valid 1.1 file stays valid without edits ([research R2](../research.md#r2-no-schema_version-bump)).

---

## 1. Full schema

```yaml
schema_version: "1.1"          # required; exactly "1.1"

agents_md: true                # optional; NEW. Keep the knowledge section in AGENTS.md
max_cache_age: 4h              # optional; existing (feature 004)
max_items: 120                 # optional; existing (feature 005)
max_bytes: 1mb                 # optional; existing (feature 005)

sources:                       # required; may be empty, null, or []
  - url: https://github.com/org/payments
    label: payments-v2
    enabled: true
```

`agents_md` exists only at the top level. The section is project-wide, so a per-source value would have nothing to control ([research R1](../research.md#r1-opt-out-key-agents_md)).

---

## 2. Field rules

Applied every time the file is read. Rows for the other fields are unchanged.

| Field | Rule | On failure |
|-------|------|-----------|
| **`agents_md`** | Optional, top level only, default `true`. Exactly `true` or `false`, like `enabled`. | sync and remove warn once and leave `AGENTS.md` untouched. No source is skipped. |

Values `"yes"`, `no`, `1` and `"false"` are rejected, as for `enabled`.

**The validation-rules row.** Add this row to § Configuration Validation Rules, byte-identical, in `speckit.knowledge.configure`, `speckit.knowledge.status` and `speckit.knowledge.sync` (quality gate 11):

```markdown
| `agents_md` | Optional, top level only, default `true`. Exactly `true` or `false`, like `enabled`. An invalid value leaves `AGENTS.md` untouched and skips no source (010 FR-010). |
```

---

## 3. Behavior by value

| Value | sync | remove |
| --- | --- | --- |
| absent or `true` | Writes the section after writing the index. Removes it when step 1a deletes the index. | Rewrites the section after a config change, when the index exists |
| `false` | Removes a present section. Never creates one. | Removes a present section, when the index exists. Never creates one. |
| invalid | Leaves `AGENTS.md` untouched. Sources and the index are unaffected. | Leaves `AGENTS.md` untouched. The config change still applies. |

Exact report lines are in [commands.md § 3](./commands.md#3-report-lines).

---

## 4. Why an invalid value fails closed

`max_items` and `max_bytes` fail open: a malformed project-wide value is reported and treated as unconfigured.
`agents_md` cannot follow that precedent.
The default writes to a committed file, and a typo such as `agents_md: no` may be an attempt to stop exactly that.
Leaving `AGENTS.md` untouched is the reversible choice.
A present section also stays in place, because removing it is a write too.

---

## 5. Other commands

- `speckit.knowledge.configure` never reads or writes `AGENTS.md`. On edits it preserves `agents_md` and every other top-level key as written ([research R10](../research.md#r10-configure-keeps-every-other-top-level-key)).
- `speckit.knowledge.status` carries the validation row only. It never reads or writes `AGENTS.md`.
- `--no-context-output` has no effect on `AGENTS.md`. `agents_md` alone governs it ([research R9](../research.md#r9---no-context-output-does-not-affect-the-section)).

---

## 6. Backward compatibility

| Existing configuration | Behavior after upgrade |
| --- | --- |
| Any valid 1.1 file | Valid without edits; `schema_version` unchanged |
| No `agents_md` key | The next sync that writes the index adds the section to `AGENTS.md` |
| `agents_md: false` added before the first sync | `AGENTS.md` is never created or modified |
