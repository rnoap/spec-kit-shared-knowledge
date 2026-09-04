# Contract: `knowledge-config.yml` (v1.5.0)

**Feature**: [../spec.md](../spec.md) · **Plan**: [../plan.md](../plan.md)

The user-facing configuration contract. This file is **committed** to the consumer's repository
and shared across their team — see § Trust boundary below, which is why that matters.

`schema_version` remains **`"1.0"`**. Both keys added here are optional and default to prior
behaviour, so no existing configuration becomes invalid (FR-005, FR-023).

---

## 1. Full schema

```yaml
schema_version: "1.0"          # required; exactly "1.0"

max_cache_age: 4h              # optional; existing (feature 004)
max_items: 120                 # optional; NEW — project-wide item ceiling
max_bytes: 1mb                 # optional; NEW — project-wide size ceiling

sources:                       # required; may be empty, null, or []
  - url: https://github.com/org/payments   # required
    label: payments-v2                     # optional; unique across sources
    revision: v2.4.1                       # optional; existing
    max_cache_age: 7d                      # optional; existing — REPLACES the project value
    max_items: 40                          # optional; NEW — SUB-CEILING, never raises
    max_bytes: 400kb                       # optional; NEW — SUB-CEILING, never raises
    path_filter: specs/                    # optional
    enabled: true                          # optional; default true
```

---

## 2. Field rules

Applied **every time the file is read**, not only when a command writes it (FR-019).

| Field | Rule | On failure |
|-------|------|-----------|
| `schema_version` | Required. Exactly `"1.0"`. | Abort run, exit 0 |
| `max_cache_age` | Optional. `^[0-9]+[mhd]$` | Per source: skip source. Project: report + ignore |
| **`max_items`** | Optional. `^[0-9]+$` and `>= 1` | Per source: skip source (FR-020). Project: report + ignore (FR-021) |
| **`max_bytes`** | Optional. `^[0-9]+(kb\|mb)$` | Per source: skip source (FR-020). Project: report + ignore (FR-021) |
| `url` | Required, non-empty. Local path or remote URL. **Must not begin with `-`.** | Skip source |
| `label` | Optional, derived when absent. Non-empty, no whitespace, unique across `sources`. | Skip all sources sharing the label |
| `revision` | Optional. `^[A-Za-z0-9._/-]+$`. **Must not begin with `-`**, no `..`, no trailing `.lock`. | Skip source |
| `path_filter` | Optional. String or list. Non-empty, no leading `/`, no `..`, must not begin with `-`. | Skip source |
| `enabled` | Optional, default `true`. Exactly `true` or `false`. | Skip source |

**Why `0` is rejected for both new fields.** A ceiling of zero is almost certainly a typo, and
honouring it literally would silently strip the entire corpus — the exact failure this feature's
reporting requirements exist to prevent. Rejecting it makes the mistake loud.

**Why the leading-`-` ban does not extend to the new fields.** `max_items` and `max_bytes` are
never interpolated into a `git` command line, so they are not an argument-injection vector. Their
anchored regexes reject an option-shaped value anyway.

---

## 3. Scoping semantics — the two conventions differ, deliberately

| Key | Per-source value | Why |
|-----|-----------------|-----|
| `max_cache_age` | **Replaces** the project value | One source may legitimately need refreshing less often than the rest |
| `max_items`, `max_bytes` | **Sub-ceiling** — lowers only, never raises | The project value is the total the agent will be asked to read; a per-source value able to exceed it would make the project number meaningless |

A per-source budget larger than the project ceiling is **clamped and reported**, never treated as
an error (FR-003a):

```
ℹ️  payments-v2: max_items 400 exceeds the project ceiling of 120; using 120.
```

---

## 4. Value formats

| Format | Pattern | Examples | Conversion |
|--------|---------|----------|------------|
| Duration | `^[0-9]+[mhd]$` | `30m`, `4h`, `7d` | `m`→×1, `h`→×60, `d`→×1440 minutes |
| Count | `^[0-9]+$`, `>= 1` | `1`, `120` | none |
| Size | `^[0-9]+(kb\|mb)$` | `512kb`, `2mb` | `kb`→×1024, `mb`→×1048576 bytes |

Binary units. Two-letter size suffixes keep `mb` unambiguous against `m` for minutes, which
already means something else in this file.

---

## 5. Backward compatibility

| Existing configuration | Behaviour after upgrade |
|-----------------------|------------------------|
| No budget keys | Byte-identical index and output (FR-004, FR-023, SC-004) |
| Any configuration written by 1.0.0 – 1.4.0 | Valid without edits; `schema_version` unchanged |
| Budget set but corpus fits | Index indistinguishable from unbudgeted (FR-016, SC-011) |

The **only** observable change for an unbudgeted project is the advisory warning above 200 items
or 2 mb (FR-032). It alters nothing it reports on — the index that run produces is identical to
the one it would have produced without it (SC-015).

---

## 6. Trust boundary

**This file is committed and shared.** A merged pull request that adds one `url` line causes that
location to be fetched on every machine and automated environment that later runs a
synchronization — including via the four automatic hooks, which the reviewer of that change may
never invoke themselves.

Fetched content is read as **data** and is never executed. The extension runs no build step, no
script, and no repository hook from a source.

Undefended, and stated as such (FR-026, FR-031):

1. **Prompt injection** — fetched markdown enters the agent's context uninspected.
2. **Credential presentation** — the local credential helper decides what to send to a configured
   host; the extension neither scopes nor filters it.
3. **Symlink following** — a fetched `.md` may be a symbolic link to a file outside the
   repository. Nothing resolves or rejects it, so a source can cause an unrelated local file to
   be read into the agent's context.

Full treatment, with the defenses that *are* implemented and their limits, belongs in the README
trust model section (FR-024 … FR-031). `config-template.yml` must point at it, so that someone
editing this file directly meets it without knowing it exists (FR-030).
