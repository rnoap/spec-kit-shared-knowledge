# Quickstart: verifying Shell-Safe Configuration

**Feature**: [shell-safe-config.spec.md](./shell-safe-config.spec.md) · **Plan**: [plan.md](./plan.md) · **Contracts**: [commands](./contracts/commands.md) · [configuration](./contracts/knowledge-config.schema.md) · [checks](./contracts/ci.md)

The scripts prove the second layer: quoting, the slug procedure and file names. Only an agent run proves the first: the character rule is applied in the agent's reasoning, so no script can exercise it. Run every part before opening the pull request.

## 1. Scripts

From the repository root. On a Homebrew `python3` without PyYAML, prefix the first command with `PATH=/tmp/py314shim:$PATH` (a `python3` link to `python3.14`).

```bash
bash .github/scripts/validate-extension.sh        # check 12 passes, check 11 still passes
bash .github/scripts/test-sync-git.sh             # every new section passes, on macOS
```

Then the Linux run in [contracts/ci.md § 3.4](./contracts/ci.md#34-linux-run), which adds git 2.25, GNU `timeout` and dash as `sh`.

**SC-006**: copy the repository to a scratch directory, remove the quotes around one `<url>` in its `commands/speckit.knowledge.status.md`, and run its `validate-extension.sh`. It fails and names that file and line.

## 2. Agent walkthrough

Install the working tree into a scratch consumer project with `specify extension add <repo> --dev`, delete `/tmp/sk007-pwned` if it exists, and write this `knowledge-config.yml`:

```yaml
schema_version: "1.0"
sources:
  - url: "https://example.com/x.git;touch /tmp/sk007-pwned"
    label: bad-url
  - url: https://github.com/github/spec-kit
    label: bad-filter
    path_filter: "docs/;touch /tmp/sk007-pwned"
  - url: "https://example.com/\e[31mred"
    label: bad-escape
  - url: <a local repository whose path contains a space, e.g. ~/My Repos/kb>
    label: spaced
```

| Step | Expect | Proves |
| --- | --- | --- |
| Run sync by hand | One refusal line each for `bad-url` (`;`), `bad-filter` (`;`) and `bad-escape` (`\e`, shown escaped, the terminal unchanged); `spaced` synchronizes; exit 0; `/tmp/sk007-pwned` absent | SC-001, SC-003, SC-005 |
| Run a spec-kit command whose knowledge hook fires, and accept the prompt | The same three lines; the command continues | SC-001 (hook) |
| Run status | `⚠️ invalid` rows for the three; `spaced` is `✅ reachable (local)`; marker absent | SC-001, SC-005 |
| Run configure with ``https://example.com/`id` `` | Error naming `` ` ``; the file is unchanged | SC-001 (configure) |
| Run configure with `'~/My Repos/kb' specs/` | The path is kept as one argument | Edge case: configure with a quoted path |
| Remove `bad-url` | Entry deleted; its cache left for the next prune | Edge case: removing a refused source |
| Sync again with `bad-filter` and `bad-escape` still present | Nothing is pruned | Edge case: no pruning while a source is refused |
| Add each `url` and `path_filter` value shown in the README and `config-template.yml`, plus one of each form in [contracts/knowledge-config.schema.md § 4.1](./contracts/knowledge-config.schema.md#41-still-accepted-sc-002) | No refusal | SC-002 |

## 3. Agent guidance

**SC-008**: the spec-kit sections of `AGENTS.md` and `.github/copilot-instructions.md` both name `007-shell-safe-config`, and `AGENTS.md` states the status recorded in `.spec-context.json`.
