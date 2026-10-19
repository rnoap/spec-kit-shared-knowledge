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

Install the working tree into a scratch consumer project with `specify extension add <repo> --dev`.
Use a fresh scratch directory for every marker; never reuse or delete a pre-existing global marker.
`MARKER` below means a new, initially absent path inside that directory. Fill it using the file tool,
not by pasting a seed into a terminal command. Start with this `knowledge-config.yml`:

```yaml
schema_version: "1.1"
sources:
  - url: "https://example.com/x.git;touch MARKER"
    label: bad-url
  - url: https://github.com/github/spec-kit
    label: bad-filter
    path_filter: "docs/;touch MARKER"
  - url: "https://example.com/\e[31mred"
    label: bad-escape
  - url: <a local repository whose path contains a space, e.g. ~/My Repos/kb>
    label: spaced
```

### 2.1 Complete hostile-value matrix

The sample above is a smoke check, not the whole of SC-001. Use all eight seeds from
[contracts/ci.md § 3.2](./contracts/ci.md#32-seeds), one failing field at a time, with a fresh marker
for each observation. Keep one separate valid local source present in every configuration.

| Input field | configure | Manual sync | Hook-driven sync | status |
| --- | --- | --- | --- | --- |
| `url`: each of 8 seeds after `https://example.invalid/` | 8 | 8 | 8 | 8 |
| `path_filter`: each of 8 seeds, with a valid local URL | 8 | 8 | 8 | 8 |

This is 64 observations. Record the seed, field, command mode, escaped refusal field/character,
marker absence and exit 0 for each, not just an aggregate pass. For the line-feed seed, use a real
line feed in the parsed value and verify the message shows `\n`, never a raw line break.

For configure, leave the existing configuration valid and give the hostile value as literal
agent-command input, never as a shell command. Wrap the argument in matching double quotes in the
agent input to keep spaces, single quotes and line feeds together; the command parser must not
interpret substitutions. Use a separate valid local repository for the `path_filter` cases to
avoid an unrelated duplicate-source refusal. Assert that the configuration bytes do not change.

For sync and status, write the bad source with a file-editing tool and keep the valid source.
Manual and hook-driven sync must synchronize the valid source; status must check it but perform no
reachability check for the bad source. The hook must finish and its parent spec-kit command must
continue. No marker may exist after any observation. Exercise every registered automatic sync
trigger at least once; record which trigger supplied each hook-mode observation.

### 2.2 Other first-layer scenarios

| Step | Expect | Proves |
| --- | --- | --- |
| Run sync by hand | One refusal line each for `bad-url` (`;`), `bad-filter` (`;`) and `bad-escape` (`\e`, shown escaped, the terminal unchanged); `spaced` synchronizes; exit 0; marker absent | SC-003, SC-005 |
| Run a spec-kit command whose knowledge hook fires, and accept the prompt | The same three lines; the command continues | SC-001 (hook) |
| Run status | `⚠️ invalid` rows for the three; `spaced` is `✅ reachable (local)`; marker absent | SC-001, SC-005 |
| Run configure with ``https://example.com/`id` `` | Error naming `` ` ``; the file is unchanged | SC-001 (configure) |
| Run configure with `'~/My Repos/kb' specs/` | The path is kept as one argument | Edge case: configure with a quoted path |
| Remove `bad-url` | Entry deleted; its cache left for the next prune | Edge case: removing a refused source |
| Sync again with `bad-filter` and `bad-escape` still present | Nothing is pruned | Edge case: no pruning while a source is refused |
| Add each `url` and `path_filter` value shown in the README and `config-template.yml`, plus one of each form in [contracts/knowledge-config.schema.md § 4.1](./contracts/knowledge-config.schema.md#41-still-accepted-sc-002) | No refusal | SC-002 |

### 2.3 Hostile file name search

For SC-004, create and commit a source file literally named `$(touch pwned).md` using a file-writing
tool, with a unique content token such as `sk007-hostile-name`. Do not create it by interpolating
the name into a shell command. No file named `pwned` exists initially in any working directory used
by the commands.

Synchronize the source, then run the knowledge search command for the unique token. Assert that
the result shows the literal file name, that its expected contents are read through the file tool,
and that no shell command is constructed from that name. Inspect the command working directories
after sync and after search: no `pwned` file exists. Record both halves; a successful scripted sync
alone does not satisfy the search acceptance scenario.

### 2.4 Existing cache reuse

For SC-007, prepare a scratch consumer with valid sources, one pinned and one unpinned, and caches
already located at their documented slugs. Do not derive those slugs by running the old broken
block. Record each URL, revision and cache path, and retain the caches across the extension upgrade.
If needed, migrate the configuration by the version-only procedure in § 2.5, leaving source values
unchanged. Make the manifests stale using the file-editing tool so a warm update is required.

Record the executed git commands while syncing the upgraded consumer, without `--force`. Assert
zero new `git clone` calls, the same cache directories and a successful warm update. Run sync once
more and verify that the same paths are still used. The command-call record is required evidence,
not just matching slug strings.

Separately, seed two unpinned sources sharing `cache/e3b0c44298fc/`. The upgraded sync clones each
into its own documented slug and prunes the broken shared directory. Keep this replacement case
separate from the healthy-cache case, where any new clone is a failure.

### 2.5 Schema gate and manual migration

For SC-009, use a separate scratch consumer with a `1.0` configuration containing one valid local
source and one hostile source, plus a correctly named existing cache for the valid source. Record
the configuration and cache bytes before invoking configure, sync, status, remove and search, and
then a hook-driven sync. Give configure a valid new source and remove an existing target so their
write paths would be exercised without the gate.

Every invocation must print the schema diagnostic, exit 0 and make no use of source values: no
slug, source-manifest read, reachability check, configuration write or cache mutation. Configuration
and cache bytes must remain unchanged, and the hook's parent command continues. Repeat the gate
checks with a missing version and an unknown version such as `"2.0"`; neither is rewritten.

Back up the legacy file and perform [the manual migration](./contracts/knowledge-config.schema.md#5-compatibility)
with a file-editing tool: change only `schema_version: "1.0"` to `schema_version: "1.1"`. Compare
parsed source values and other settings with the backup to prove they are unchanged. Sync and
status now process the valid source, reusing its existing cache, and refuse the hostile source
without running it. No marker exists and sync prunes nothing while that source remains refused.
Finally, in an empty scratch consumer, configure with a valid source must create schema `"1.1"`.

## 3. Agent guidance

**SC-008**: the spec-kit sections of `AGENTS.md` and `.github/copilot-instructions.md` both name `007-shell-safe-config`, and `AGENTS.md` states the status recorded in `.spec-context.json`.
