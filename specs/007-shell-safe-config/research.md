# Research: Shell-Safe Configuration

**Feature**: [shell-safe-config.spec.md](./shell-safe-config.spec.md) · **Plan**: [plan.md](./plan.md)

Each entry records what was chosen, why, and what was turned down. Four code readers mapped the commands, the README, the test script and the slug procedure before these were written. Their findings are folded in below.

## 1. Single quotes, with `'\''` for a value's own quote

**Decision**: Every configuration placeholder in a bash block sits inside single quotes. The agent writes the value exactly as configured, with each `'` in it written as `'\''`.

**Rationale**: Inside single quotes the shell expands nothing and splits nothing. The `'\''` rule makes that hold for any value, including the single-quote break-out SC-004 seeds. Validation refuses `'`, so on the normal path the rule never fires.

**Alternatives considered**:
- Double quotes. `$(…)` and backticks still run inside them, which is today's bug at three sites.
- A quoted heredoc per value. Verbose, and a value containing the delimiter line ends it early.
- Each value written to a file with the agent's file tool, as the git extension does for commit messages. Safe for any bytes, but one file per value per run in every block.
- Environment variables. The assignment has the same quoting problem.

## 2. The quoting rule lives inside the validation block

**Decision**: Extend "Why no value may begin with `-`" in § Configuration Validation Rules into the account of both layers: refuse with the character rule, neutralize with single quotes and `--`.

**Rationale**: That block is already duplicated into configure, sync and status, and check 11 keeps the copies identical. It already explains refuse-and-neutralize for `-`. remove and search reach it by reference.

**Alternatives considered**:
- A section in sync's Algorithm Reference only. status and configure would depend on another command's text for a security rule.
- A shared file. Forbidden by constitution §I: spec-kit would not install it.

## 3. The agent applies the character rule, not a shell snippet

**Decision**: The rule is a row in the table, like every other rule, with the accepted characters listed one by one. No validation snippet.

**Rationale**: A snippet would hand the unchecked value to a shell to check it, which makes validation the one step where a hostile value meets a shell. Every other rule in the table is already applied by the agent, and the second layer covers a value the agent misjudges.

**Alternatives considered**:
- A `case` pattern with a negated bracket expression. Deterministic, but it needs the value in the shell, and `A-Z` ranges depend on the locale in bash 3.2.
- A `tr -d` filter. Misses a trailing line break, because command substitution strips it.

## 4. The accepted characters

**Decision**: A `url` and each `path_filter` entry may contain letters, digits and `. _ ~ : / @ % + -`. A local-path `url` also admits spaces, never a space followed by `-`. A local path starts with `/`, `./`, `../` or `~/`. A `path_filter` entry must not begin with `~`.

**Rationale**: The list covers every remote form the commands accept: scheme, user, host, port, path, percent-encoding and a server-side `~user`. None of its characters can run a command, redirect, glob, comment out the rest of a line or split a value, even unquoted.
- Spaces in local paths are the user's decision (2026-10-19) and are safe once quoted. The dash guard keeps the leading-`-` rule true for every piece a missed quote would produce.
- A `~user/` local path works today only because an unquoted shell expands it. sync and status recognize only `~/`, so once quoted it would go down the remote path and fail. Refusing it says so up front.
- A leading `~` in a `path_filter` expands to a home directory when unquoted, so `find` would index outside the cache. A leading `/` is already refused for the same reason.
- Wildcards (`*`, `?`, `[ ]`, `!`) are refused. The README documents `path_filter` as folder names, and once quoted, `find` takes a pattern as a literal starting point and indexes nothing.

**Alternatives considered**:
- Refusing known metacharacters. A deny-list misses whatever nobody listed.
- Spaces in every field. A remote address never contains one, and configure splits path filters at spaces.

## 5. A refused value never reaches a shell

**Decision**: No command computes a slug, runs a check or prints a message with a refused value.
- status checks every source before step 2 and shows a refused one as `invalid`. That takes precedence over `— disabled`.
- sync prunes nothing (step 8a) in a run where any source was refused.
- remove still acts on a refused target, deleting or toggling its entry, but leaves its cache to the next prune instead of computing its slug.
- search skips refused sources.

**Rationale**: Computing a slug is the one place where quoting would have to hold for a value that really contains `'` or a line break. Not computing it removes that risk instead of managing it. Prune cannot tell a refused source's cache apart, so it must not delete anything that run.

**Alternatives considered**:
- Computing the slug of a refused value under the quoting rule. Workable, but it makes the escape rule carry the load on exactly the hostile input.
- Leaving refused sources out of prune's expected set. Deletes the cache the spec says stays.

## 6. Data-loss guards on deletion

**Decision**: remove purges, and prune deletes, only a directory whose name is exactly 12 lowercase hex characters. Prune runs only when every expected slug has that form.

**Rationale**: Run as written in zsh, today's slug procedure assigns nothing, and an empty slug turns `cache/<slug>/` into the cache root. One check stops a purge of every source's cache.

**Alternatives considered**: Trusting the fixed procedure. The guard costs one line; a wrong purge costs every cache.

## 7. Fetched file names

**Decision**:
- Items are named only through a variable and read through redirection: `wc -c < "$file"`, `sha256sum < "$file"`.
- Indexable Items passes each filter directory with `./` in front and drops any item line with a `..` segment or a leading `/`.
- The manifest and the index are written with the agent's file-writing tool, strings escaped as JSON requires.
- search reads item content with the file tool.

**Rationale**: A file name comes from whoever controls the source. Pasted into a command, its `$(…)` runs; read through a variable it stays data.
- `find` takes no `--`, so `./` is what keeps a filter that bypassed validation from being read as an option.
- Names travel as newline-separated text, so a directory named with a line break could forge a `../…` line, or an absolute `/…` line when the name ends in one. Dropping both closes that.
- Redirection keeps a name beginning with `-` from reaching `sha256sum` as an option.

**Alternatives considered**: NUL-separated lists (`-print0`). Not POSIX, and dash has no `read -d ''`.

## 8. Messages

**Decision**: Refusals, like every other message, are the agent's own output, never `echo` or `printf`. A value, label or fetched file name quoted in a message shows control characters as `\n`, `\t`, `\r`, `\e` or `\xHH`.

**Rationale**: `echo "…"` around a refused value would run its `$(…)`. A label or a file name can carry an escape sequence that rewrites the terminal: the label rule bans whitespace, not control characters.

**Alternatives considered**: A character rule for labels. File names would still need escaping, so one output rule covers both.

## 9. The slug procedure

**Decision**: Move the two comments off the continuation lines. Assign `url='<url>'` and `revision='<revision>'` (empty when none is pinned) at the top. Normalize with `printf '%s\n'` instead of `echo`. Correct the worked example to the real slug, `18dbb51ec4eb`.

**Rationale**: Run as written, zsh stops with a parse error, and sh and bash hash an empty address. Every unpinned source gets `e3b0c44298fc`, and pinned sources that share a revision share a cache.
- The documented algorithm is unchanged: strip `.git`, then a trailing `/`, lowercase, then add the revision after a newline only when one is pinned. Every value FR-001 accepts hashes as documented; the reference values are in [contracts/commands.md](./contracts/commands.md#4-the-slug-procedure).
- Explicit assignments stop a long-lived shell carrying one source's `revision` into the next.
- `printf` prints the same bytes as `echo` for any value without a backslash, which FR-001 guarantees, and does not vary by shell.
- Consequence: a cache the broken procedure named `e3b0c44298fc` is replaced on the next sync and the old directory pruned. Caches named by the documented algorithm stay.

**Alternatives considered**: Keeping `echo`. sh and zsh already read `\t` and `\c` differently from bash.

## 10. Static check 12

**Decision**: In every ```` ```bash ```` block of `commands/*.md`, track ordinary single quotes, double quotes and escapes across physical lines. Check every `<name>` placeholder other than `<slug>` in its original context. It passes only inside ordinary single quotes opened from an unquoted context; double-quoted, escaped, unterminated and ambiguous contexts fail. Report `file:line`. Inert scanner fixtures run with static validation, including `"'<url>'"`, escaped quotes and multiline contexts ([contracts/ci.md § 1.4](./contracts/ci.md#14-scanner-fixtures)). No fixture is shell-executed.

**Rationale**: Removing apparent single-quoted segments without tracking their outer context incorrectly accepts `"'<url>'"`, where `$(…)` still runs. A small context-aware scanner fails closed without adding a shell-parser dependency. Checking every placeholder but an explicit exemption also catches one added later. `<slug>` is twelve hex characters the extension computed.

**Alternatives considered**:

- Deleting pairs of single quotes with a regular expression. It cannot distinguish an effective quote from one inside double quotes or preceded by an escape.
- A list of placeholders to check. A new one would pass silently.
- Running the snippets in CI. The constitution keeps CI on the package, not the prose.

## 11. The behaviour test

**Decision**: Extend `.github/scripts/test-sync-git.sh`, which stays a local check.
- A literal substitution that applies the quoting rule fills placeholders, replacing the sed in `render()`.
- New sections seed 8 hostile values with validation bypassed, sync a local source whose path has a space, run the slug block in sh, bash and zsh against the reference values with empty stderr, and sync a fixture holding a file named `$(touch …).md` and a directory whose name contains a line break.
- Marker files prove nothing ran. A recording `git` stand-in proves git received each value unchanged.
- The Linux run reuses the Podman `ubuntu:20.04` command with zsh added to its packages; sh is dash there.

**Rationale**: sed reads `|`, `&`, `\` and line breaks in a value as syntax. Three of the eight values would break the substitution and pass for the wrong reason.

**Alternatives considered**: Running the test in CI. That needs its own `docs:` amendment and is out of scope.

## 12. Configuration schema 1.1 and manual migration

**Decision**: Set `knowledge-config.yml`'s `schema_version` to `"1.1"` in the template, every configuration example and the three validation-block copies. All five commands check the version before source use; a legacy `"1.0"`, missing or unknown version prints an escaped diagnostic and exits 0 without using source values or changing configuration or caches. configure creates and preserves `"1.1"`. The README describes a manual, version-only migration after backing up the file and reviewing the narrowed value rules. The manifest and index keep their existing schema versions and formats (FR-014, SC-009).

**Rationale**: Constitution Principle I requires a schema bump on any breaking schema change, not only on field or type changes. The compatibility contract explicitly changes a bracketed IPv6 address from accepted to refused, so retaining `"1.0"` is not compliant. An explicit migration makes the break visible. Changing only the version preserves source values and slug inputs: once migrated, invalid sources are refused individually while valid sources retain their caches. Migration never evaluates a stored value and never deletes a cache.

**Alternatives considered**: Retaining `"1.0"` because the shape is unchanged contradicts Principle I. Automatically rewriting consumers' files conceals the compatibility break and is unnecessary; a documented manual scalar edit needs no new command, flag, runtime script or dependency. Supporting legacy files under the new rules without an explicit migration would silently reinterpret their schema.

## 13. configure keeps a quoted argument whole

**Decision**: configure splits `$ARGUMENTS` on whitespace, except inside matching `'…'` or `"…"`, which is one argument.

**Rationale**: Without it, a local path with a space can only be added by editing the YAML.

## 14. AGENTS.md

**Decision**: Edit the spec-kit section by hand once `.github/copilot-instructions.md` names 007, which the after-plan hook does. One task makes the edit. Its status line stays true until the release: in progress on the branch, not yet released, with the current step in `.spec-context.json`. The release that ships the feature rewrites the line as shipped. No CHANGELOG line.

**Rationale**: Commit a774934 set the pattern: the shipped status was written at release. The file is excluded from the archive, so it is not part of the package. A second edit at completion would give the file two owner phases in the task list.

**Alternatives considered**: Adding `AGENTS.md` to the agent-context targets. It would replace the hand-written section with the generic pointer, and it edits tooling-owned `.specify/` configuration.

## 15. Requirement citations

**Decision**: Command prose cites this feature's requirements as `007 FR-001`.

**Rationale**: The commands already cite bare FR numbers from 004 and 005, and FR-006 and FR-010 mean other requirements there.

## 16. Spec changes found during planning

Applied to the spec in this step:
- FR-001: a local path starts with `~/`, and a `path_filter` entry must not begin with `~`.
- FR-002: covers every command that reads the configuration, not only configure, sync and status.
- FR-005: covers labels and fetched file names in any message.
- FR-012: names what the CHANGELOG records, leaving out the `AGENTS.md` pointer.
- User Story 3 and SC-007: sh and bash hash an empty address today, so caches the broken procedure named are replaced once.
- Edge cases: removing a refused source, pruning while a source is refused, configure with a quoted path, a fetched directory whose name contains a line break.
