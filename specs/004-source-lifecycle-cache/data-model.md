# Phase 1 — Data Model: Source Lifecycle & Cache Policy

**Feature**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md) | **Research**: [research.md](research.md)

This extension persists no database. Its "data model" is two files on disk — the
team-committed `knowledge-config.yml` and the local, per-source `.manifest.json` — plus three
values derived at runtime and never written down. This document defines all five, the state
machine a source moves through, and the decision table that reconciles this feature with the
Context Output Block contract inherited from 003.

---

## 1. Persisted entities

### 1.1 `knowledge-config.yml` — the configured knowledge set

Location: `.specify/extensions/knowledge/knowledge-config.yml` (committed to the consumer's
repository). Scaffolded from `config-template.yml` at install time.

**Top-level fields**

| Field | Type | Required | Default | New in 1.4.0 | Notes |
|-------|------|:--------:|---------|:------------:|-------|
| `schema_version` | string | yes | `"1.0"` | — | Must be exactly `"1.0"`. **Unchanged** (FR-025) — every new field is optional and additive, so no existing file becomes invalid. |
| `sources` | list | yes | `[]` | — | May be empty. An empty list is a valid, meaningful state (FR-031). |
| `max_cache_age` | string | no | *absent* | ✅ | Project-wide freshness policy. Absent means "no policy" — every sync fetches, exactly as in 1.3.0 (FR-017, FR-024). |

**Per-source fields** (each element of `sources`)

| Field | Type | Required | Default | New in 1.4.0 | Notes |
|-------|------|:--------:|---------|:------------:|-------|
| `url` | string | yes | — | — | Remote URL or local path. No longer a unique key — see § 2.2. |
| `label` | string | no in file, always present after `configure` | derived from `url` | — | **The identity of the source** (FR-001, FR-028). Unique across `sources`. |
| `path_filter` | string \| list | no | *absent* | — | Absent means every `.md` file in the repository. |
| `enabled` | boolean | no | `true` | — | Existed in the schema since 1.0.0; this feature is the first to expose it through a command. |
| `revision` | string | no | *absent* | ✅ | Branch, tag, or full commit SHA. Absent means the remote's default revision (FR-010). |
| `max_cache_age` | string | no | inherits top-level | ✅ | Per-source override (FR-016). A source-level value always wins over the project-level one. |

Field validation rules are normative in
[contracts/knowledge-config.schema.md](contracts/knowledge-config.schema.md) and are applied
**every time the file is read**, not only when written (FR-029).

### 1.2 `.manifest.json` — the per-source cache receipt

Location: `.specify/extensions/knowledge/cache/<slug>/.manifest.json` (local only, gitignored).
Written **last** by sync, which is what makes its presence mean "this cache is complete" and its
mtime mean "this is when the cache became valid" (see [research.md](research.md) § R4).

| Field | Type | New in 1.4.0 | Notes |
|-------|------|:------------:|-------|
| `schema_version` | string | — | `"1.0"`; unchanged. |
| `source_url` | string | — | The `url` this cache was built from. |
| `source_slug` | string | — | Redundant with the directory name; kept for self-description. |
| `revision` | string \| null | ✅ | The revision this cache holds, or `null` for a source pinning none. Written for diagnosability — the slug already guarantees separation, so nothing reads this to make a decision. |
| `synced_at` | ISO 8601 | — | Rendered to the user. **Advisory** for the freshness gate; mtime is authoritative. |
| `item_count` | integer | — | Must equal `len(items)` and the actual `.md` file count. |
| `items` | list of `{path, sha256}` | — | Integrity-check input. |

**Backward compatibility**: a manifest written by 1.3.0 has no `revision` field. Readers treat
absent as `null`. No migration and no re-sync is required — an unpinned source keeps its slug
(see [research.md](research.md) § R2), so its existing cache directory is found and reused.

---

## 2. Derived entities

These are computed on demand and never persisted. Each is a pure function of configuration.

### 2.1 Cache slug

**Input**: `url`, `revision` → **Output**: 12 hex characters.

```text
normalized = lowercase(strip_trailing_slash(strip_trailing_dot_git(url)))
hash_input = normalized                       when revision is absent
           = normalized + "\n" + revision     when revision is present
slug       = first 12 hex chars of sha256(hash_input)
```

The conditional is the entire backward-compatibility guarantee: an unpinned source hashes the
same bytes it hashed in 1.3.0, so upgrading re-downloads nothing (FR-024, SC-005).

**Relationship to identity**: a slug is intentionally *narrower* than a repository identity.
`https://github.com/o/r` and `git@github.com:o/r` produce **two different slugs** (different
fetch targets, different credentials, different cache state) but **one identity** (same body of
knowledge). Conflating them would break either FR-011 or FR-026.

### 2.2 Repository identity

**Input**: `url` → **Output**: a comparison key such as `github.com/org/payments`.

Derivation is normative in [research.md](research.md) § R3. Used for exactly one purpose:
deciding whether a shared file path is a conflict (FR-026).

> **Why `url` stopped being a key.** Before this feature, one URL meant one source, so `url` was
> a usable identifier. FR-009 makes it legal to configure the same repository twice at different
> revisions, so a URL can now resolve to several sources. This is why FR-001 identifies a source
> by `label` and why FR-028 makes label uniqueness an enforced invariant rather than a
> convention. A URL is still *accepted* as an identifier, but only when it resolves to exactly
> one source; otherwise the command lists the candidates and changes nothing.

### 2.3 Freshness verdict

**Input**: effective `max_cache_age`, mtime of `.manifest.json`, `--force` flag
**Output**: one of `fetch` | `skip`.

| Effective policy | Cache state | `--force` | Verdict | Reported as |
|------------------|-------------|:---------:|---------|-------------|
| absent | any | any | `fetch` | `fresh` / `cached` / `unreachable` (1.3.0 behavior, FR-017) |
| present | no manifest | any | `fetch` | normal cold-path statuses |
| present | mtime within policy | no | **`skip`** | `current` — new status, no network touched (FR-018, FR-019) |
| present | mtime within policy | yes | `fetch` | normal statuses (FR-021) |
| present | mtime outside policy | any | `fetch` | normal statuses |

"Effective policy" = source-level `max_cache_age` if present, else top-level, else absent.

**`--force` is unreachable from a hook.** The four `hooks.*` entries in `extension.yml` declare
no arguments, so an automatically triggered sync cannot pass it (FR-022). This is the same
structural guarantee 003 established for `--no-context-output`, and it must survive any future
edit to the hooks block.

---

## 3. Source state machine

```text
                    configure <url> [revision] [path_filter...]
                                    │
                                    ▼
                            ┌───────────────┐
                            │    ENABLED    │  enabled: true (default)
                            │  entry ✓      │  synced; contributes to the index
                            │  cache ✓      │
                            └───────┬───────┘
              remove --disable      │     ▲   remove --enable
                                    ▼     │
                            ┌───────────────┐
                            │   DISABLED    │  enabled: false
                            │  entry ✓      │  skipped by sync; contributes nothing
                            │  cache ✓      │  cache retained → re-enable is free
                            └───────┬───────┘
                                    │
                       remove       │       remove
                                    ▼
                            ┌───────────────┐
                            │    ABSENT     │  entry ✗ · cache purged
                            └───────────────┘
```

| Transition | Command | Entry | Cache | Requirement |
|------------|---------|-------|-------|-------------|
| → ENABLED | `configure <url> …` | created | created on next sync | FR-013 |
| ENABLED → DISABLED | `remove <label> --disable` | retained, `enabled: false` | **retained** | FR-002, FR-004 |
| DISABLED → ENABLED | `remove <label> --enable` | retained, `enabled: true` | reused, no re-download | FR-005, SC-002 |
| ENABLED → ABSENT | `remove <label>` | deleted | **purged** | FR-001, FR-003 |
| DISABLED → ABSENT | `remove <label>` | deleted | **purged** | FR-001, FR-003 |
| *(no match)* | `remove <unknown>` | unchanged | unchanged | FR-007 |
| *(ambiguous URL)* | `remove <url matching 2+>` | unchanged | unchanged | FR-001, SC-009 |

A DISABLED source is invisible to sync and contributes zero items to the index (FR-008). Its
cache directory is nonetheless **protected from pruning** (see § 4) — that is what makes
re-enabling free.

---

## 4. Cache directory lifecycle

The cache root holds one directory per slug. Three forces create and destroy them:

| Event | Effect on `cache/<slug>/` |
|-------|---------------------------|
| First sync of a source | Created (cold path) |
| Subsequent sync | Updated in place (warm path), or reused untouched (freshness skip) |
| Source disabled | **Retained**, untouched |
| Source removed | **Purged** (FR-003) |
| Source's `revision` edited | Slug changes → a *new* directory is created; the old one is **orphaned** |

That last row is gap **G1** in [research.md](research.md): no Functional Requirement covers it,
yet it produces exactly the "orphaned cache directories accumulate" outcome FR-003 exists to
prevent. The proposed handling is a prune pass at the end of sync:

```text
expected = { slug(s) : s ∈ sources }        # ALL sources — enabled AND disabled
actual   = { directory names under cache/ }
prune      actual − expected
```

Computing `expected` over disabled sources too is essential; computing it over enabled sources
only would delete exactly the caches FR-004 promises to keep.

---

## 5. Emission-gate decision table (003 contract)

003 established when sync emits the Context Output Block. This feature introduces two states
that table did not anticipate. Both are resolved here so implementation cannot guess.

| State | Index on disk | Block emitted? | Requirement |
|-------|---------------|:--------------:|-------------|
| ≥ 1 source `fresh` | written | **yes** | 003 FR-012 |
| All `cached`, ≥ 1 usable | written | **yes** | 003 FR-012 |
| All `unreachable`, no prior index | not written | no — soft warning | 003 FR-013a |
| `--no-context-output` passed | written | no | 003 FR-014 |
| Early-exit config error | not written | no | 003 FR-013 |
| **≥ 1 source skipped for freshness** | **written (unchanged content)** | **yes** | **FR-020** |
| **Zero enabled sources** | **deleted** | **no** | **FR-031** |

The last two rows are the additions.

- **Freshness skip emits.** A cache that is fresh by policy is current knowledge; suppressing
  the block would strip cross-repo context from an agent precisely because the cache was *too
  good* to need refetching. The source appears under its own `current` status so the user can
  still see no network access occurred (FR-019).
- **Zero enabled sources deletes the index and emits nothing.** Leaving the previous index in
  place would point an agent at knowledge the project no longer declares — a silent failure
  that looks like success. The command still exits 0 (FR-023, FR-031).

---

## 6. Requirement coverage

Every entity, field, and transition above traces to at least one requirement.

| Requirement | Where modeled |
|-------------|---------------|
| FR-001, FR-006, FR-007 | § 3 state machine (transition table, no-match row) |
| FR-002, FR-004, FR-005 | § 3 DISABLED state; § 4 retention row |
| FR-003 | § 4 purge row |
| FR-008 | § 3 (DISABLED contributes nothing) |
| FR-009 … FR-012 | § 1.1 `revision`; § 2.1 cache slug |
| FR-013, FR-014 | § 1.1 `revision`; rendered by `status` |
| FR-015 | [research.md](research.md) § R6 Tier-3 fallback |
| FR-016 … FR-019, FR-021, FR-022, FR-027 | § 2.3 freshness verdict table |
| FR-020, FR-031 | § 5 emission-gate table |
| FR-023 | Exit 0 on every row of every table above |
| FR-024, FR-025 | § 1.1 defaults; § 2.1 conditional hash input |
| FR-026 | § 2.2 repository identity |
| FR-028 | § 1.1 `label`; § 2.2 rationale |
| FR-029, FR-030 | [contracts/knowledge-config.schema.md](contracts/knowledge-config.schema.md) |
