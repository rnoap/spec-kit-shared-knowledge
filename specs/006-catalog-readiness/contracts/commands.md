# Contract: Install instructions, command names, and the reachability call

**Feature**: [../catalog-readiness.spec.md](../catalog-readiness.spec.md) · **Plan**: [../plan.md](../plan.md) · **Research**: [../research.md](../research.md)

What a first-time user types, what their agent calls the commands, and the one git call this
feature changes. The five commands' flags, output and exit codes are otherwise unchanged.

---

## 1. Installing from the catalog

spec-kit registers its community catalog as discovery-only (`install_allowed: false`):
`specify extension search` finds extensions there, and `specify extension add <id>` refuses to
install them. The README's catalog instructions therefore lead with the release archive.

`knowledge` is not listed yet; the submission is out of scope. The `--from` path works today; the
rest of this section describes the listed state. Behaviour shown is spec-kit 1.2.0's, read from its
source and CLI help. Older supported releases may word it differently.

### 1.1 Primary: the release archive (FR-005, FR-006)

```bash
specify extension add knowledge --from https://github.com/rnoap/spec-kit-shared-knowledge/archive/refs/tags/v<extension.version>.zip
```

| Moment | What happens |
|---|---|
| Before downloading | A panel titled `Untrusted Source` shows the URL, then `Continue with installation?`, defaulting to **No** |
| User confirms | The extension installs: 5 commands, 4 hooks, `knowledge-config.yml` (SC-001) |
| User declines | `Cancelled`; nothing installed; exit 0 |
| No terminal | The prompt cannot be answered, and the install aborts |

- `<extension.version>` is the manifest version: `v1.5.0` today. The release that ships this
  feature updates the example to its own tag, or catalog users install an older release. Nothing
  checks this automatically.
- The README offers no way to skip or pre-answer the prompt.

### 1.2 Teams: a catalog you control (FR-007, FR-008)

A team that wants no prompt lists the extension in a catalog it curates and marks that catalog install-allowed. After that, `specify extension add knowledge` installs without the `Untrusted Source` confirmation (US1 AS2). This is the route spec-kit itself recommends.

The README never suggests `specify extension catalog add <community catalog URL> --install-allowed`:

- **spec-kit advises against it.** Its messages call that flag the vetting boundary: "Don't flip a discovery-only catalog to install_allowed".
- **It breaks the project's catalog list.** `catalog add` writes `.specify/extension-catalogs.yml`, and a project-level catalog file replaces spec-kit's built-in stack. The project silently stops consulting the `default` catalog.

### 1.3 Plain `specify extension add knowledge`

Works wherever a trusted catalog lists the extension, so the README does not say it always fails. On a default setup spec-kit refuses with `'knowledge' was found in the 'community' catalog, which is discovery-only — a search surface, not an install source.` and points to `--from`.

### 1.4 What the README states

| Statement | Requirement |
|---|---|
| The community catalog is searchable, not installable, by default | FR-004 |
| The primary install is `specify extension add knowledge --from <release archive URL>` | FR-005 |
| spec-kit asks the user to confirm the source | FR-006 |
| Teams that want no prompt list the extension in a catalog they control | FR-007 |
| Nothing suggests marking the community catalog install-allowed | FR-008 |
| The agent may show the commands under another name, at least `/speckit-knowledge-sync` | FR-009, § 2 |
| Supported platforms | FR-010, § 3 |

The local and development install, `specify extension add <path> --dev`, is unchanged.

---

## 2. Command names by agent (FR-009)

The examples keep the dot form. One note at the top of README § Commands tells the reader their
agent may list the commands under another name.

| Form | Sync command | Used by |
|---|---|---|
| Dot | `/speckit.knowledge.sync` | Agents that install commands as prompts or slash commands; every README example |
| Skills | `/speckit-knowledge-sync` | Agents that install commands as skills, such as Copilot on spec-kit 1.1.2 (on 1.0.4 it gets prompts) |
| Codex | `$speckit-knowledge-sync` | Codex ([research § 7](../research.md#7-one-invocation-note-examples-unchanged)) |

The skills and Codex forms replace every `.` in the command id with `-`; the same rule names the
other four commands.

- The README keeps `/speckit.knowledge.<verb>` for all five commands. `validate-extension.sh`
  fails without them.
- The other forms appear in `README.md` only. Command bodies keep their `__SPECKIT_COMMAND_*__`
  tokens; a literal `/speckit-` or `$speckit-` under `commands/` fails the agent-portability check.

---

## 3. Supported platforms (FR-010)

README § Prerequisites states: **macOS and Linux; Windows through WSL or Git Bash.**

- CI runs on Linux only. Windows is stated, not exercised.
- The macOS claim relies on the separately tracked `timeout` fix, which ships in the same release.

---

## 4. Status reachability call (FR-012)

`commands/speckit.knowledge.status.md`, § 3 Check reachability, remote-URL branch:

| | Call |
|---|---|
| Before | `timeout 5 git ls-remote --exit-code <url> HEAD` |
| After | `timeout 5 git ls-remote --exit-code -- <url> HEAD` |

- The git invocation is exactly `git ls-remote --exit-code -- <url> HEAD`. The `timeout 5` wrapper
  belongs to the separately tracked `timeout` fix, not to this contract.
- Results are unchanged: exit 0 → `✅ reachable`; non-zero or timed out → `❌ timeout` (US4 AS2).
- Paths written `/`, `~/` or `./` take the local-path branch and never reach this call. A `../`
  path, which configure accepts, is classified remote here and does reach it; its result is
  unchanged.
- The edit lies outside the `## Configuration Validation Rules` … `## Behavior` block that static
  validation keeps byte-identical across configure, sync and status.

---

## 5. Every configuration-derived git operand (SC-006)

The README's trust model promises `--` before every config-derived `git` operand. With § 4
applied, every row holds.

| Command | Call | Value from config | `--` |
|---|---|---|---|
| status | `git ls-remote --exit-code -- <url> HEAD` | `url` | added here |
| sync | `git clone … -- <url> <cache-dir>`, Tiers 1 and 2 | `url` | already |
| sync | `git clone … -- <expanded-path> <cache-dir>` | `url`, local path | already |
| sync | `git fetch … origin -- <revision>`, cold and warm paths | `revision` | already |
| sync | `git checkout -- <revision>`, Tiers 2 and 3 | `revision` | already |
| sync | `git sparse-checkout set -- <pattern> …`, cold and warm paths | `path_filter` | already |

Not operands, so outside the promise: `--branch <revision>` on `git clone`, and
`-C "<expanded-path>"` in status's local-path check. Each passes the value as an option's argument,
which git consumes without parsing it as an option. Validation also rejects a leading `-` in all
three fields.
