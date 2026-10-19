# Feature Specification: Shell-Safe Configuration

**Feature Branch**: `007-shell-safe-config`

**Created**: 2026-10-16

**Status**: Draft

**Input**: User description: "punto 1 , 2,  5 (solo lo de agents ya yo borre la rama remota)". The points are the v1.6.0 follow-ups listed earlier in the same session: (1) validation lets shell syntax through `url` and `path_filter`, and the commands paste those values into shell commands unquoted; (2) the Source Slug Generation procedure puts a comment after each line continuation, so it fails when run as written; (5) `AGENTS.md` still points at feature 005 and v1.5.0. Point 5 also listed a stale remote branch, which the user has since deleted.

`knowledge-config.yml` is committed and shared, so a merged change to it is read on every teammate's machine and in every automatic sync. The commands paste `url` and `path_filter` values into shell commands, unquoted or inside double quotes, and validation refuses only a leading `-`. A merged line such as `url: https://example.com/x.git;touch /tmp/pwned` therefore runs a command everywhere the configuration is read. This feature refuses values that carry shell syntax and makes every command hand values to the shell as literal data. It also repairs the slug procedure and points `AGENTS.md` at the current feature.

Narrowing accepted values is a breaking configuration-schema change, including for previously accepted bracketed IPv6 addresses. The configuration schema therefore becomes `1.1`, as constitution Principle I requires. A `1.0` file is not silently rewritten or used: the user backs it up, reviews the compatibility changes and changes only its schema version before commands process its sources. The cache manifest and index formats do not change.

## Clarifications

### Session 2026-10-19

- Q: Should a local path containing a space be accepted? → A: Yes, in a `url` written as a local path. Remote addresses and `path_filter` entries keep refusing spaces.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A configuration change cannot run commands (Priority: P1)

A teammate merges a pull request that edits `knowledge-config.yml`. Everyone else's next sync reads it, including the automatic syncs before specify, clarify, plan and tasks. Today a `url` or `path_filter` value can carry `$(…)`, a backtick, `;` or `|`, and the commands paste it into shell commands, so one merged line runs a command on every machine that syncs. After this change such a value is refused before anything uses it. Its source is skipped with a message that names the problem, and every other source still syncs.

**Why this priority**: It is command execution on every teammate's machine for the price of one approved pull request, and the automatic hooks trigger it for people who never saw the change.

**Independent Test**: Seed one source's `url` and another source's `path_filter` with command substitution, add one valid source, and run configure, sync and status. No injected command runs and the valid source synchronizes.

**Acceptance Scenarios**:

1. **Given** a source whose `url` contains `$(touch /tmp/pwned)`, **When** sync runs, manually or from a hook, **Then** it skips that source, names the field and the character `$`, runs nothing from the value, and synchronizes the other sources.
2. **Given** a `path_filter` entry containing `;`, **When** status runs, **Then** it reports the source as skipped with the same kind of message and runs no reachability check for it.
3. **Given** a user running configure with an address that contains a backtick, **When** configure validates it, **Then** it writes nothing and names the character.
4. **Given** a `1.1` configuration using a supported address or folder form listed in SC-002, **When** any command reads it, **Then** its values are accepted; discontinued forms are refused as the migration reference documents.

---

### User Story 2 - Values reach the shell as data (Priority: P2)

Validation is the first defense. This story is the second, for the day validation is bypassed and for the input it never sees. Today the commands paste values into shell commands unquoted, or inside double quotes, where `$(…)` still runs. A file fetched from a source is another input: its name comes from whoever controls that repository, and no configuration rule checks it. After this change every value a command hands to the shell arrives as one literal argument, and a change that pastes a value unquoted again fails the automated checks. This is also what makes a local path with a space work: unquoted, the shell splits it in two and the clone fails.

**Why this priority**: It only matters once validation is bypassed or a source carries a hostile file name. That is exactly when it has to hold.

**Independent Test**: Run the commands' shell steps directly with hostile values, bypassing validation, then sync a source that contains a file named with shell syntax and a source at a local path containing a space.

**Acceptance Scenarios**:

1. **Given** validation is bypassed, **When** a shell step receives a value containing `$(…)`, a quote or a line break, **Then** nothing from the value runs and git receives the value unchanged.
2. **Given** a source holding a file named `$(touch pwned).md`, **When** sync indexes the source and search reads it, **Then** nothing runs.
3. **Given** a pull request that adds an unquoted value to a command's shell step, **When** the automated checks run, **Then** they fail and name the file and line.
4. **Given** a source at a local path containing a space, **When** sync and status run, **Then** the source synchronizes and status reports it reachable.

---

### User Story 3 - The slug procedure runs as written (Priority: P2)

Each source's cache directory is named by a slug computed from its address and revision. The procedure in the commands puts a comment after each line continuation. Run as written, zsh stops with a syntax error, and sh and bash hash an empty address, so every unpinned source lands in the same cache directory. After this change it runs as written in all three and gives every source the slug the documented algorithm defines.

**Why this priority**: Every command that locates a cache depends on it. A wrong slug means a full download, a status that cannot see a cache that exists, or two sources mixing their files in one directory.

**Independent Test**: Copy the procedure verbatim, run it in sh, bash and zsh for reference sources, and compare against the expected slugs.

**Acceptance Scenarios**:

1. **Given** the procedure copied verbatim, **When** it runs in sh, bash or zsh, **Then** it prints a slug and no error.
2. **Given** a source whose cache is named by the documented algorithm, **When** it syncs after the upgrade, **Then** it updates that cache instead of cloning again.
3. **Given** two sources with the same address and different revisions, **When** their slugs are computed, **Then** they differ, as today.
4. **Given** sources that the broken procedure put in one shared cache directory, **When** sync runs after the upgrade, **Then** each source gets its own cache and the shared directory is pruned.

---

### User Story 4 - Agent guidance points at the current feature (Priority: P3)

Agents read `AGENTS.md` first. Its spec-kit section still names feature 005, says it shipped in v1.5.0 and says no feature is in progress, while `.github/copilot-instructions.md` already points at 006. After this change both name the same latest feature, and `AGENTS.md` states its status truthfully.

**Why this priority**: A stale pointer sends agents to a finished plan. It costs context, not correctness.

**Independent Test**: Compare the spec-kit section of both files with the latest feature directory and its recorded status.

**Acceptance Scenarios**:

1. **Given** this feature in progress, **When** an agent reads `AGENTS.md`, **Then** it is pointed at this feature's documents and told the feature is in progress.
2. **Given** both agent guidance files, **When** a reviewer compares them, **Then** they name the same feature.

### Edge Cases

- A command reads a legacy `1.0` configuration. It reports the required migration and exits 0 before using sources or changing configuration or caches; a hook lets its parent command continue. The upgrade is manual, never an automatic rewrite.
- A configuration already holds a value the new rule refuses, such as a `path_filter` written as a wildcard pattern, `docs/*.md`. That source is skipped on every read until the value is edited. Its cache stays in place and nothing is deleted.
- A local path has a space followed by `-`, such as a copied folder named `kb - Copy`. It is refused, since a piece of it would read as an option if a quote were ever missed. Renaming the folder or linking to it under another name works.
- A refused value contains a control character, such as a line break or an escape sequence. The message shows it escaped, never raw, so it cannot rewrite the terminal.
- A user removes a source whose value is now refused. Remove deletes the entry and runs nothing from the value. Its cache is left for the next sync to prune.
- While any source holds a refused value, sync prunes no cache, since it cannot tell which directory belongs to that source.
- A user passes a local path with a space to configure. Written in quotes, it stays one argument.
- A hook-driven sync meets a refused value. The source is skipped, the hook finishes, and the spec-kit command it precedes continues.
- A value is well formed but points somewhere hostile. It is accepted: the rule concerns shell syntax, not trust, and the README's review checklist still applies.
- An agent runs the shell steps in zsh, the macOS default, rather than bash. Values arrive the same way.
- A fetched file's name holds shell syntax. Whether or not it is indexed, nothing runs.
- A fetched directory's name contains a line break. No item is read from outside the source's cache.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Every time `knowledge-config.yml` is read, a `url`, and each `path_filter` entry, MUST be refused when it contains any character other than letters, digits, `.`, `_`, `~`, `:`, `/`, `@`, `%`, `+` and `-`. A `url` written as a local path, starting with `/`, `./`, `../` or `~/`, also admits spaces, provided no space is followed by `-`. A `path_filter` entry must not begin with `~`.
- **FR-002**: Every command that reads `knowledge-config.yml` MUST check a value before any other use of it, including configure's local-path check, status's reachability check and the slug computation, so a refused value never reaches a command.
- **FR-003**: Configure MUST refuse to write a value that fails FR-001, naming the field and the first character that is not allowed.
- **FR-004**: Sync and status MUST skip only the source holding a refused value, name the source, the field and the first character that is not allowed, and go on with every other source, still exiting 0, as they do for any other invalid value.
- **FR-005**: Every message that quotes a configuration value, a source label or a fetched file name MUST show control characters in escaped form, never raw.
- **FR-006**: Every place a command hands a value to the shell MUST pass it as one literal argument that the shell neither expands nor splits. This covers configuration values, a local path after `~` expansion, and the names of files fetched from a source.
- **FR-007**: The automated checks MUST fail when a command's shell step hands a configuration value to the shell unquoted.
- **FR-008**: The Source Slug Generation procedure MUST run as written in sh, bash and zsh.
- **FR-009**: The procedure MUST yield, for every source, the slug the documented algorithm yields today.
- **FR-010**: The README's trust model MUST list the new defense: what it covers, a merged configuration change running commands on teammates' machines, and what it does not, a well-formed value pointing somewhere hostile.
- **FR-011**: The README's configuration reference and the configuration template MUST state schema version `1.1` and the characters `url` and `path_filter` accept. The README MUST explain the manual `1.0` to `1.1` migration and the previously accepted values that stop being accepted.
- **FR-012**: The security fix, the slug fix, the documentation changes, the new check and the constitution amendment MUST each be recorded under `[Unreleased]` in the CHANGELOG.
- **FR-013**: The spec-kit section of `AGENTS.md` MUST name the same latest feature as `.github/copilot-instructions.md` and state that feature's status truthfully.
- **FR-014**: Every command MUST check `knowledge-config.yml`'s schema version before using its sources. Only `"1.1"` is accepted. A missing, `"1.0"` or unknown version MUST produce an escaped diagnostic and exit 0 without shell use of source values or configuration/cache writes or deletions. configure MUST create and preserve version `"1.1"`. Migration from `"1.0"` MUST be manual: back up the file, review the changed validation rules, and change only the schema-version scalar; source values and cache identities are preserved and then checked by the normal per-source rules. The manifest and index schema versions MUST remain unchanged.

### Key Entities

- **Knowledge source**: one entry in `knowledge-config.yml`: an address (`url`), an optional `revision`, optional `path_filter` folders, a label and budgets.
- **Shell-bound value**: anything a command hands to the shell: a source's address or local path, its revision, its folder filters, and the names of files fetched from it.
- **Refusal**: the per-source outcome of a failed check: the source, the field, and the first character that is not allowed.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: With 8 seeded hostile values in `url` and in `path_filter` (command substitution, backticks, `;`, `&&`, `|`, a redirection, a single-quote break-out, a line break), configure, sync (manual and from an automatic hook) and status run 0 injected commands.
- **SC-002**: 100% of the values the README and the configuration template show as valid are still accepted, along with one example of each accepted address form: `https://`, `ssh://`, `git+ssh://`, `git@`, and local paths starting with `/`, `~/`, `./` and `../`.
- **SC-003**: In a configuration with one refused and one valid source, the valid source synchronizes, the command exits 0, and the refusal is one line naming source, field and character, with a control character shown escaped.
- **SC-004**: With validation bypassed, the same 8 values handed straight to the commands' shell steps run 0 injected commands, and a source file named with shell syntax runs nothing when synchronized and searched.
- **SC-005**: A source at a local path containing a space synchronizes, and status reports it reachable.
- **SC-006**: A seeded unquoted value in a command's shell step fails the automated checks: 1 of 1.
- **SC-007**: The slug procedure, copied verbatim, yields the expected slug in sh, bash and zsh for 100% of a reference set covering HTTPS and SSH addresses, with and without a revision, a trailing `.git` or `/`, and mixed case. After the upgrade, 0 caches named by the documented algorithm are cloned again.
- **SC-008**: `AGENTS.md` and `.github/copilot-instructions.md` name the same feature.
- **SC-009**: With a `1.0` configuration holding one valid and one hostile source, all five commands and a hook-driven sync report migration, exit 0, run 0 commands from source values and leave configuration and cache bytes unchanged. After a backup and a version-only edit to `1.1`, sync uses the valid source's existing documented cache, refuses only the hostile source and prunes nothing. Missing and unknown versions also stop before any source use; configure creates `1.1` when the file is absent.

## Assumptions

- The allowed characters cover the supported address forms SC-002 lists, including ports, user names, percent-encoding and a server-side `~user` path, and the folder names the README documents for `path_filter`. Letters means ASCII letters. A previously accepted bracketed IPv6 address is refused under schema `1.1`; a host name works instead.
- A local path written `~user/` is refused. It worked only because an unquoted shell expanded it, and sync and status never recognized it as local.
- Spaces are accepted only in a local-path `url`, where folder names often contain them. A remote address writes a space as `%20`, and configure splits `path_filter` entries at spaces, so neither needs one. A local path with a space works only because every command quotes it (FR-006).
- A space followed by `-` stays refused. It is the leading-`-` rule applied to every piece the shell would see if a quote were ever missed.
- `path_filter` is documented as folder names, so wildcard and negation patterns (`*`, `?`, `[ ]`, `!`) are refused. Once quoted, a pattern would index nothing.
- `revision` keeps its rule, which already admits only letters, digits, `.`, `_`, `/` and `-`.
- No command hands a source's label to the shell. The code readers confirmed this during planning.
- The configuration `schema_version` becomes `1.1` because the accepted value domain narrows, even though fields and types do not change. `.manifest.json` and `knowledge-index.md` retain their existing versions and formats. There is no automatic migration or cache invalidation based only on the configuration version.
- `AGENTS.md` stays hand-maintained. Making the agent-context refresh manage it would edit `.specify/`, which the constitution reserves for tooling.
- This feature bumps no package version and tags nothing. Its configuration-schema bump and other changes wait under `[Unreleased]`.

## Out of Scope

- Package version bump, tag, release, and the catalog submission. The configuration-schema bump is in scope.
- Prompt injection through fetched content, and credential exposure to a configured host: the README's stated non-defenses.
- Running the commands' shell steps in CI. The behaviour test stays a local check.
- `../` local paths, which configure accepts but sync and status treat as remote addresses.
- Repository settings, such as which checks the main branch requires.
