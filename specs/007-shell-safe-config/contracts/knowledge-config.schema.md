# Contract: `knowledge-config.yml` values

**Feature**: [../shell-safe-config.spec.md](../shell-safe-config.spec.md) · **Plan**: [../plan.md](../plan.md) · **Research**: [../research.md](../research.md)

The user-facing configuration contract. The file is committed and shared: a merged change to it is
read on every teammate's machine and in every automatic sync. This feature narrows the characters
`url` and `path_filter` accept. Although no field or type is added, the accepted value domain
changes, so the configuration `schema_version` becomes `"1.1"` under constitution Principle I
([research § 12](../research.md#12-configuration-schema-11-and-manual-migration)). Manifest and
index schema versions and formats stay unchanged.

---

## 1. The character rule (FR-001)

Applied every time the file is read, by every command that reads it, before any other use of the
value (FR-002).

The file must first pass the schema gate: only `schema_version: "1.1"` is accepted (FR-014).
Missing, legacy `"1.0"` and unknown versions stop the whole command before source use, configuration
writes or cache changes, with the diagnostic of [commands.md § 1.1](./commands.md#11-schema-gate).
This file-level error is distinct from refusing an individual source in an accepted `1.1` file.

| Value | Accepted characters | Also required |
| --- | --- | --- |
| `url`, remote address | ASCII letters, digits, `.` `_` `~` `:` `/` `@` `%` `+` `-` | Unchanged: matches `^(https?://\|ssh://\|git\+ssh://\|git@)`, does not begin with `-` |
| `url`, local path | The same, plus the space | No space followed by `-`. Unchanged: exists and contains `.git` |
| Each `path_filter` entry | ASCII letters, digits, `.` `_` `~` `:` `/` `@` `%` `+` `-` | Does not begin with `~` (new), `/` or `-`; no `..`; non-empty |
| `revision` | Unchanged: `^[A-Za-z0-9._/-]+$` | Unchanged |
| `label` | Unchanged | Never handed to the shell. Messages quote it with control characters escaped (FR-005) |

- **A local path is recognised by its prefix alone**: `/`, `./`, `../` or `~/`. The prefix decides
  whether a space is accepted, before anything touches the disk.
- **`~user/…` is no longer a local path.** It matches no accepted form and is refused
  ([research § 4](../research.md#4-the-accepted-characters)).
- **The agent applies the rule in its own reasoning.** No command hands an unchecked value to a
  shell to check it ([research § 3](../research.md#3-the-agent-applies-the-character-rule-not-a-shell-snippet)).
  Written as patterns, for reading only:
  - remote `url`, and each `path_filter` entry: `^[A-Za-z0-9._~:/@%+-]+$`
  - local-path `url`: `^[A-Za-z0-9._~:/@%+ -]+$`, holding no space followed by `-`

---

## 2. Check order

After the file-level schema gate, each value goes through these steps in order, all in the agent's
own reasoning:

1. **The character rule.** Reading left to right, the first character outside the accepted set is
   the one reported. In a local-path `url`, a space followed by `-` is reported at that space.
2. **The field's other rules**: non-empty, no leading `-`, the accepted forms, no leading `/` or
   `~`, no `..`.
3. **Only then anything that hands the value to a shell or touches the disk or the network**:
   whether a local path exists and contains `.git`, the reachability checks, the slug, every git
   step.

A source is **accepted** when every one of its values passes. Only an accepted source reaches a
shell ([commands.md § 2](./commands.md#2-refusal)). A source that fails is reported once, at its
first failure; when several of its values fail, a character-rule failure is reported first.

---

## 3. Validation block rows

These three rows replace today's `schema_version`, `url` and `path_filter` rows in § Configuration
Validation Rules, in all three copies: configure, sync and status. Static check 11 keeps the copies
byte-identical, so they are copied exactly. Every other row is unchanged.

```markdown
| `schema_version` | Required. Exactly `"1.1"`. Check before using any source; missing, `"1.0"` and unknown versions stop with the schema diagnostic, exit 0 and no configuration or cache changes (007 FR-014). |
| `url` | Required, non-empty. Either a local path (`/`, `./`, `../`, `~/`) that exists and contains `.git`, or a remote URL matching `^(https?://\|ssh://\|git\+ssh://\|git@)`. **Must not begin with `-`.** **Only ASCII letters, digits and `.` `_` `~` `:` `/` `@` `%` `+` `-`**; a local path may also contain spaces, but **no space followed by `-`** (007 FR-001). |
| `path_filter` | Optional. A string or a list of strings. Each entry non-empty, **no leading `/` or `~`**, **no `..`**, **must not begin with `-`**, and **only ASCII letters, digits and `.` `_` `~` `:` `/` `@` `%` `+` `-`** (007 FR-001). |
```

Beside the rows, the block:

- extends its account of the leading-`-` rule to both layers: **refuse** with the leading-`-` rule
  and the character rule, **neutralize** with `--` and single quotes
  ([commands.md § 3.1](./commands.md#31-the-quoting-rule));
- states that the agent applies every rule in its own reasoning, and hands no value of a source
  that is not accepted to a shell, not even to compute a slug or print a message;
- distinguishes the whole-file schema gate from per-source refusals, referencing the diagnostics
  of [commands.md § 1.1](./commands.md#11-schema-gate);
- adds a character-rule example to its `On failure` lines
  ([commands.md § 2.1](./commands.md#21-the-refusal-line)).

Its headings `## Configuration Validation Rules` and `## Behavior` stay as they are: check 11
compares the text between them.

---

## 4. Examples

### 4.1 Still accepted (SC-002)

Every `url` and `path_filter` value that README.md and config-template.yml show stays accepted,
along with one of each address form:

| Field | Value | Form |
| --- | --- | --- |
| `url` | `https://github.com/your-org/your-repo` | `https://` |
| `url` | `https://git.example.com/team/design%20notes.git` | `https://`, percent-encoding |
| `url` | `ssh://git@git.example.com:2222/team/kb.git` | `ssh://`, with a user and a port |
| `url` | `git+ssh://git@git.example.com/~alice/kb.git` | `git+ssh://`, with a server-side `~user` path |
| `url` | `git@github.com:your-org/architecture-decisions.git` | `git@` |
| `url` | `/Users/devuser/repos/payment-service` | local path, `/` |
| `url` | `~/repos/identity-service` | local path, `~/` |
| `url` | `./vendor/kb` | local path, `./` |
| `url` | `../kb` | local path, `../` |
| `url` | `~/My Repos/kb` | local path with a space |
| `path_filter` | `specs/`, `docs/decisions/` | folder names |

### 4.2 Refused

| Field | Value | Reported |
| --- | --- | --- |
| `url` | `https://example.com/x.git;touch /tmp/pwned` | `;` |
| `url` | `https://example.com/$(touch /tmp/pwned)` | `$` |
| `url` | `` https://example.com/`id` `` | `` ` `` |
| `url` | `https://example.com/my repo` | the space: a remote address writes it `%20` |
| `url` | `https://[2001:db8::1]/kb.git` | `[`: use a host name |
| `url` | `~/kb - Copy` | a space followed by `-` |
| `url` | `~alice/kb` | no accepted form |
| `path_filter` | `specs/;touch /tmp/pwned` | `;` |
| `path_filter` | `docs/*.md` | `*`: once quoted, a wildcard indexes nothing |
| `path_filter` | `!drafts/` | `!` |
| `path_filter` | `~/notes` | begins with `~` |

Each of the eight seeds in [ci.md § 3.2](./ci.md#32-seeds) is refused, in `url` and in
`path_filter` (SC-001).

---

## 5. Compatibility

The configuration schema becomes `"1.1"`. Some previously accepted values are no longer valid,
including bracketed IPv6 addresses; the unchanged field layout does not make this backward
compatible. Legacy `"1.0"` files are rejected with migration guidance, never silently reinterpreted
or rewritten. No command uses their sources or changes their caches, and hooks still exit 0.

**Manual migration from `1.0` (FR-011, FR-014):**

1. Back up `knowledge-config.yml` and review the changed value rules in the table below.
2. With a file-editing tool, change only the root `schema_version` scalar from `"1.0"` to `"1.1"`.
  Preserve every source, value and other setting. Never pass source values to a shell to migrate
  them. This procedure does not apply to missing or unknown schema versions.
3. Run sync and status. The normal `1.1` rules now refuse discontinued values per source, without
  running them, while valid sources keep their original slug inputs and reuse their caches.
4. Correct or remove refused entries as a separate, reviewed edit. While any refused source
  remains, sync prunes nothing. No cache migration or deletion is part of changing the version.

configure creates and preserves `"1.1"`, but does not migrate an existing file automatically.

| Value | Before | After |
| --- | --- | --- |
| Shell syntax in `url` or `path_filter` | Ran as a command wherever a command read it | Refused |
| `path_filter` wildcard or negation: `*`, `?`, `[ ]`, `!` | Expanded by an unquoted shell | Refused. Once quoted, a pattern would index nothing |
| `path_filter` beginning with `~` | Expanded to a home directory, so `find` read outside the cache | Refused, as a leading `/` already is |
| Local path written `~user/…` | Expanded by an unquoted shell; sync and status never treated it as local | Refused: no accepted form |
| Bracketed IPv6 address | Accepted | Refused; use a host name |
| Space in a remote address or a `path_filter` entry | Split in two by an unquoted shell | Refused |
| Space in a local path | Split in two, so the clone failed | Accepted, unless followed by `-` |

A source refused after an upgrade is skipped on every read until its value is edited. Its cache
stays in place: sync prunes nothing while any source is not accepted
([commands.md § 5.2](./commands.md#52-sync-pruning)).

---

## 6. Where the rule is stated (FR-010, FR-011)

| Location | States |
| --- | --- |
| § Configuration Validation Rules in configure, sync and status | The schema gate and character rule (§ 3) |
| README § Configuration Reference | Schema `1.1`, manual `1.0` migration (§ 5), changed value compatibility, and the characters `url` and `path_filter` accept, including spaces in a local path |
| `config-template.yml` | `schema_version: "1.1"`, with the same accepted characters in the `url` and `path_filter` comments |
| README § Trust model, defenses table | The two rows below |
| README § Trust model | One bullet: no configuration value and no fetched file name is ever run as a command |

| Defense | Covers | Does **not** cover |
| --- | --- | --- |
| `url` and `path_filter` accept only ASCII letters, digits and `. _ ~ : / @ % + -`, plus spaces in a local path | A merged configuration change running commands on teammates' machines | A well-formed value pointing somewhere hostile |
| Every value reaches the shell inside single quotes, and fetched file names only through shell variables | The same, if validation is ever bypassed, and hostile file names in a source | As above |
