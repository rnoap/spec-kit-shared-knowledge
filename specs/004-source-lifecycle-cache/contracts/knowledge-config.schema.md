# Contract — `knowledge-config.yml` schema

**Status**: normative for extension version 1.4.0 | **Schema version**: `"1.0"` (unchanged)
**Feature**: [../spec.md](../spec.md) | **Plan**: [../plan.md](../plan.md)

This is the contract between the extension and the consumer project. The file is
**committed to the consumer's repository** and shared across their team, which is why every
rule below is enforced **each time the file is read** — not only when a command writes it
(FR-029). Configuration arrives by hand-edit, by pull request, and from older versions of the
extension; validating only on write leaves all three routes unchecked.

Location: `.specify/extensions/knowledge/knowledge-config.yml`
Scaffolded from: `config-template.yml`

---

## Compatibility guarantee

`schema_version` stays `"1.0"`. Both fields added in 1.4.0 are optional and default to the
1.3.0 behavior, so:

- A config file written for 1.0.0–1.3.0 remains **valid and unchanged in meaning** under 1.4.0.
- Upgrading re-downloads nothing: an unpinned source keeps the cache slug it already has.
- Downgrading to 1.3.0 leaves `revision` and `max_cache_age` as ignored unknown keys; the
  project reverts to fetch-every-time behavior without error.

Per Constitution §I, a `schema_version` bump is required only for a **breaking** schema change.
Additive optional keys are not breaking, so the version correctly stays put (FR-025).

---

## Top-level keys

```yaml
schema_version: "1.0"      # required
max_cache_age: 4h          # optional — new in 1.4.0
sources: []                # required; may be empty
```

| Key | Type | Required | Default | Rule |
|-----|------|:--------:|---------|------|
| `schema_version` | string | yes | — | Must be exactly `"1.0"`. |
| `sources` | list | yes | — | May be empty. An empty list is valid and meaningful (FR-031). |
| `max_cache_age` | string | no | absent | Matches `^[0-9]+[mhd]$`. Absent = no freshness policy = fetch every sync (FR-017). |

---

## Per-source keys

```yaml
sources:
  - url: https://github.com/org/payments   # required
    label: payments-v2                     # unique identity
    revision: v2.4.1                       # optional — new in 1.4.0
    path_filter: specs/                     # optional
    max_cache_age: 7d                       # optional — new in 1.4.0; overrides top-level
    enabled: true                           # optional; default true
```

| Key | Type | Required | Default | Rule |
|-----|------|:--------:|---------|------|
| `url` | string | yes | — | Non-empty. Either a local path (`/`, `./`, `../`, `~`) that exists and contains `.git`, or a remote URL matching `^(https?://\|ssh://\|git\+ssh://\|git@)`. **Must not begin with `-`.** |
| `label` | string | no | derived from `url` | Non-empty. No whitespace. **Unique across `sources`** (FR-028). |
| `revision` | string | no | absent | Non-empty, matching `^[A-Za-z0-9._/-]+$`. **Must not begin with `-`**, must not contain `..`, must not end with `.lock`. Absent = the remote's default revision (FR-010). |
| `path_filter` | string \| list | no | absent | Each entry non-empty, **no leading `/`**, **no `..`**, **must not begin with `-`**. Absent = every `.md` file in the repository. |
| `max_cache_age` | string | no | inherits top-level | Matches `^[0-9]+[mhd]$`. A source-level value always wins over the project-level one. |
| `enabled` | boolean | no | `true` | Exactly `true` or `false`. `"yes"` and `1` are rejected. |

### Label derivation (when `label` is omitted)

Unchanged from 1.3.0:

- **Local path** → the last path component: `/Users/me/repos/payments` → `payments`
- **Remote URL** → `<host>/<org>/<repo>` after stripping `.git` and a trailing `/`:
  `https://github.com/org/payments.git` → `github.com/org/payments`

If derivation produces a label that already exists, `configure` must resolve the collision
before writing (FR-028). Two situations make this reachable: two local paths sharing a final
component, and the same repository added twice at different revisions.

---

## `max_cache_age` format

`<N><unit>` where `N` is a non-negative integer and `unit` is one of:

| Unit | Meaning | Example |
|------|---------|---------|
| `m` | minutes | `30m` |
| `h` | hours | `4h` |
| `d` | days | `7d` |

Rejected: `4 hours` (space, word unit), `-1h` (negative), `PT4H` (ISO 8601), `3600` (bare
number — the unit would be ambiguous in a committed file).

`0m` is syntactically valid and means "always stale", which is equivalent to having no policy.
It is accepted rather than special-cased.

The policy is a **hint, not an expiry** (FR-027). It governs only whether a refresh is
*attempted*. An over-age cache whose source cannot be reached is still served, with its
staleness reported. Configuring a freshness policy never leaves a project with less available
knowledge than it had before.

---

## `revision` semantics

| Form | Example | Fetch strategy |
|------|---------|----------------|
| Branch | `main`, `develop` | `git clone --depth=1 --branch` |
| Tag | `v2.4.1` | `git clone --depth=1 --branch` |
| Full commit SHA | 40 hex chars (or 64 for SHA-256 repos) | Clone empty, then `git fetch --depth=1 origin -- <sha>`; deepen once if the server refuses |
| Abbreviated SHA | `a1b2c3d` | **Not supported** — reported as an unresolvable revision |

Abbreviated SHAs are rejected because they are not fetchable by any strategy and are not stable:
a prefix that is unique today can become ambiguous as the repository grows. The full ladder and
its fallbacks are in [../research.md](../research.md) § R6.

---

## Validation failure behavior

A value that violates its rule causes **only its own source** to be skipped (FR-030):

```text
⚠️  payments-v2: skipped — invalid `revision` value "-u" (must not begin with "-")
```

- Every other source is processed normally.
- The command exits **0**. Validation failures are messages, never process errors (FR-023).
- The offending field **and** its value are named, so the user can find and fix it without
  guessing.

---

## Security notes

Two rules above exist for security rather than tidiness, and must not be relaxed.

**1. No value may begin with `-`.** Every one of `url`, `revision`, and `path_filter` is
interpolated into a `git` command line. A value beginning with `-` is parsed by `git` as an
option, not as data. A `revision` of `--upload-pack=<command>` passed to `git fetch` is remote
code execution on the developer's machine, triggered by nothing more than a pull request that
edits a YAML file. This is the classic argument-injection variant of OWASP A03 (Injection), and
validation is the primary control.

**2. Every `git` invocation that consumes a config value must place `--` before it.**

```sh
git fetch --depth=1 origin -- "$revision"
git sparse-checkout set -- "$pattern1" "$pattern2"
git clone --filter=blob:none --no-checkout --depth=1 -- "$url" "$cache_dir"
```

The `--` separator is defense in depth: it makes a value that somehow bypassed validation
uninterpretable as an option. Neither control is sufficient alone — validation can be bypassed
by a future code path that forgets to call it, and `--` does not help for `git` subcommands that
accept option-like values after the separator. Both are required.

**3. `path_filter` must not contain `..` or a leading `/`.** Both would let a filter escape the
cache directory during sparse-checkout, turning a knowledge source into an arbitrary-path read.
This rule predates 1.4.0; it is restated here because it now runs on the read path, where it
also covers hand-edited and pull-requested configuration for the first time.
