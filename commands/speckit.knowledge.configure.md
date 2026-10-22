---
description: "Initialize or edit the knowledge source configuration for the current project"
---

## speckit.knowledge.configure

**Purpose**: Initialize or edit the knowledge source configuration for the current project.

**Arguments**: `$ARGUMENTS` — optional. May contain:
- A Git repository URL (SSH or HTTPS), e.g. `https://github.com/your-org/your-repo`
- **Or** a local filesystem path to a Git repository starting with `/`, `./`, `../` or `~/`. Quote a path containing spaces, e.g. `'~/My Repos/kb'`.
- **Optional path filter(s)** after the URL/path. Pass one **or more** folder paths to scope indexing to only those folders. Examples:
  - `https://github.com/your-org/your-repo specs/`
  - `~/repos/your-repo specs/ docs/decisions/`
  - `'~/My Repos/kb' specs/`
  - `/abs/path/to/repo` (no filter — indexes every `.md` file in the repo)
- **Optional revision** — a branch, tag, or full commit SHA to read from, in either form:
  - `--revision <rev>` — always works
  - `<url>@<rev>` — shorthand, split on the **last** `@`. Unambiguous for HTTPS URLs
    and local paths. **Not available for SSH URLs**, which already contain `@`; the
    command says so rather than guessing.
- The flag `--verbose` to print full YAML after write

---

## Configuration Validation Rules

> **This block is duplicated verbatim in `speckit.knowledge.configure`,
> `speckit.knowledge.sync`, and `speckit.knowledge.status`.** That is deliberate.
> Extracting it to a shared file would create a runtime dependency `extension.yml`
> does not declare, so spec-kit would not install it and every command would break
> in a consumer project. Keep the three copies identical.

Apply these rules **every time `knowledge-config.yml` is read**, not only when a
command writes it (FR-029). Configuration reaches a project by hand-editing, by
pull request, and from older versions of this extension — validating only on write
leaves all three routes unchecked.

Apply every rule in the agent's own reasoning, never by sending an unchecked value
to a shell. After the schema gate, check the character rule first, then the other
syntax rules, then local existence or any other use. Check `url`, then each
`path_filter` entry, before the remaining source fields. No value of a source
that is not accepted reaches a shell, not even for its slug or a message
(007 FR-001, FR-002).

**Schema gate (007 FR-014):** before using any source, accept only configuration
schema `"1.1"`. For `"1.0"`, print as agent output:

```text
Error: knowledge-config.yml schema_version "1.0" requires migration to "1.1". Back up the file, then change only schema_version. No sources or caches were used or changed.
```

For a missing or unknown version, print the following, substituting `<missing>`
when absent and escaping the value under the message rule below:

```text
Error: Unrecognized knowledge-config.yml schema_version "<value>". Expected "1.1". No sources or caches were used or changed.
```

Both paths exit 0 before computing slugs, reading source manifests, checking
reachability, pruning, or writing configuration or caches. A hook finishes and
its parent command continues. Never migrate or downgrade automatically. configure
uses `"1.1"` when creating a missing file and preserves it on edits. This gate
does not change the separate manifest or index schema versions.

`sources:` written with no value parses as **null**, not as an empty list. Treat
absent, null, and `[]` identically: the project has no configured sources.

| Field | Rule |
|-------|------|
| `schema_version` | Required. Exactly `"1.1"`. Check before using any source; missing, `"1.0"` and unknown versions stop with the schema diagnostic, exit 0 and no configuration or cache changes (007 FR-014). |
| `max_cache_age` (top level and per source) | Optional. Matches `^[0-9]+[mhd]$` — `30m`, `4h`, `7d`. |
| `url` | Required, non-empty. Either a local path (`/`, `./`, `../`, `~/`) that exists and contains `.git`, or a remote URL matching `^(https?://\|ssh://\|git\+ssh://\|git@)`. **Must not begin with `-`.** **Only ASCII letters, digits and `.` `_` `~` `:` `/` `@` `%` `+` `-`**; a local path may also contain spaces, but **no space followed by `-`** (007 FR-001). |
| `label` | Optional in the file, derived when absent. Non-empty, no whitespace, **unique across `sources`** (FR-028). |
| `revision` | Optional. Non-empty, matching `^[A-Za-z0-9._/-]+$`. **Must not begin with `-`**, must not contain `..`, must not end with `.lock`. |
| `path_filter` | Optional. A string or a list of strings. Each entry non-empty, **no leading `/` or `~`**, **no `..`**, **must not begin with `-`**, and **only ASCII letters, digits and `.` `_` `~` `:` `/` `@` `%` `+` `-`** (007 FR-001). |
| `enabled` | Optional, default `true`. Exactly `true` or `false` — `"yes"` and `1` are rejected. |
| `max_items` (top level and per source) | Optional. Matches `^[0-9]+$` and is `>= 1`. |
| `max_bytes` (top level and per source) | Optional. Matches `^[0-9]+(kb\|mb)$` — `512kb`, `2mb`. |

### Why a budget ceiling of `0` is rejected

`max_items: 0` and `max_bytes: 0kb` are refused by the rules above rather than
honoured. A literal reading would withhold the entire corpus while reporting
success — the silent-truncation failure this budget exists to prevent. Rejecting
it routes the mistake through the loud paths instead: per source it skips only
that source and names the field, and project-wide it is reported and treated as
unconfigured.

Neither `max_items` nor `max_bytes` is ever handed to `git`, so the leading-`-`
ban below does not apply to them. Their anchored patterns reject an option-shaped
value regardless.

### Two layers against option injection and shell syntax

1. **Refuse** with both the leading-`-` rule and the character rule. A local path
  is recognized by its prefix alone: `/`, `./`, `../` or `~/`. Only that form
  admits spaces, never a space followed by `-`. A `path_filter` cannot start
  with `~`. Report the first disallowed character from left to right.
2. **Neutralize** with `--` before every configuration-derived git operand
  (FR-034) and single quotes around every configuration placeholder in a shell
  command (007 FR-006), including commands the agent composes itself. Copy the
  value literally, replacing each `'` with `'\''`. For `<expanded-path>`,
  expand `~/` to the actual home directory before quoting. `$HOME` and `~` do
  not expand inside single quotes. `with_timeout` forwards only through `"$@"`.

Fetched file names enter commands only through the double-quoted shell variable
`"$file"`, never pasted into command text. Read through redirection:
`wc -c < "$file"`, `sha256sum < "$file"`, or `shasum -a 256 < "$file"` on macOS.
Labels and messages never reach a shell.

### Values in messages (007 FR-005)

Every message quoting a configuration value, source label or fetched file name
is agent output, never `echo` or `printf`. Escape line feed as `\n`, tab as `\t`,
carriage return as `\r`, escape U+001B as `\e`, and other characters below U+0020
or from U+007F to U+009F as `\xHH`. Show backslash as `\\` and a double quote
inside a quoted value as `\"`. Leave other characters unchanged.

### On failure

A value that violates its rule skips **only its own source** (FR-030):

```
⚠️  payments-v2: skipped — invalid `revision` value "-u" (must not begin with "-")
⚠️  source 3: skipped — invalid `url` value "https://example.com/$(touch /tmp/pwned)" ("$" is not allowed)
```

Every other source is processed normally and the command exits **0** (FR-023).
Always name the field and the offending value, so the user can fix it without
guessing. Emit only the first failure per source, on one escaped line. Use its
label; without one, derive a label only from an accepted URL, otherwise use
`source <n>`, its 1-based position. A character-rule failure names `"<c>" is not
allowed`; a local space followed by `-` names `a space followed by "-" is not
allowed`; a leading `~` filter names `must not begin with "~"`. A URL matching no
accepted form names `not a Git URL, nor a local path starting /, ./, ../ or ~/`.

---

## Behavior

### 1. Locate or create configuration file

Check for `.specify/extensions/knowledge/knowledge-config.yml` in the project root.

- **If absent**: prepare a new configuration from the extension's `config-template.yml`, setting `schema_version: "1.1"` and `sources: []`. Defer directory and file creation until validation and confirmation succeed in step 4, so a refused argument writes nothing.
- **If present**: read the existing file and parse its YAML. Before using any source, require `schema_version` to be exactly the string `"1.1"`. For a missing, `"1.0"` or unknown version, apply the schema gate in § Configuration Validation Rules and exit 0 without using sources or changing configuration, caches or `.gitignore`. Never migrate, downgrade or rewrite an unsupported-version file automatically.
- Only after the schema gate, validate every existing source under § Configuration Validation Rules before listing or merging sources. An existing entry that is not accepted gets its § On failure line before the source list and is preserved unchanged on write; none of its values reaches a shell.

### 2. Parse arguments (if provided)

If `$ARGUMENTS` is non-empty (excluding `--verbose`):

1. Split `$ARGUMENTS` on whitespace, except inside a matching pair of `'...'` or `"..."`. Keep that text as one argument and remove the matching quotes (007 FR-003). An unmatched quote stays in its argument and is refused by the character rule. Parse in the agent's own reasoning: nothing else is interpreted, including `$` or a backslash escape; never evaluate the text in a shell.
2. Remove the `--verbose` flag and extract `--revision <rev>` as described in 3a. The first remaining token is the **URL or local path**. Extract any revision shorthand under 3a before validating the resulting URL/path:
   - Apply the character rule first, reporting the first disallowed character from left to right. A local path may contain spaces, but no space followed by `-`.
   - Must be non-empty
   - Detect type:
     - **Local path**: starts with `/`, `./`, `../` or `~/`, recognized by prefix alone. `~user/` is not a local path and matches no accepted form.
     - **Remote URL**: matches `^(https?://|ssh://|git\+ssh://|git@)` and contains no spaces; anything matching neither form is an error.
   - Apply the remaining `url` rules. Defer local existence and `.git` checks until the character and other syntax rules have passed for the source, including its filters and revision (007 FR-001, FR-002).
3. **All remaining tokens** (zero or more, after the URL/path and excluding flags and their values) are **path filters**. Each must:
   - Pass the character rule before any other use; only ASCII letters, digits and `. _ ~ : / @ % + -` are accepted, with no spaces
   - Be non-empty
   - Not start with `/` (no absolute paths)
   - Not start with `~` (no home-directory expansion)
   - Not contain `..` (no directory traversal)
   - Not begin with `-` (it would be read as a git option — FR-034)
   - Not be `--verbose`, `--revision`, or a `--revision` value (skip flag tokens)
   - If the URL/path, any filter or revision is invalid: print the § Error cases diagnostic with escaped values and stop with exit 0; write nothing, including a new configuration or `.gitignore`
   - **Zero tokens** → omit `path_filter` from the source entry (indexes all `.md` files in the repo)
   - **One token** → store as a single string for readability: `path_filter: specs/`
   - **Two or more tokens** → store as a YAML list: `path_filter: [specs/, docs/decisions/]`

3a. **Extract the revision**, if given (FR-013):
   - `--revision <rev>` → take the following token
   - otherwise, if the URL token contains `@` **and** the URL is not SSH-style
     (`git@…`, `ssh://…` or `git+ssh://…`), split on the **last** `@`: everything before is the
     URL, everything after is the revision
   - an SSH URL written as `<url>@<rev>` is an error, not a guess — see § Error cases
   - validate the value against the `revision` rule in § Configuration Validation Rules
   - omit `revision` from the entry entirely when none was given: that keeps the
     source on the remote's default revision **and** keeps the cache slug it
     already has (FR-010, FR-024)

| Typed after the command | URL or path | `path_filter` |
| --- | --- | --- |
| `'~/My Repos/kb' specs/` | `~/My Repos/kb` | `specs/` |
| `"~/My Repos/kb"` | `~/My Repos/kb` | none |
| `~/My Repos/kb` | `~/My`, which does not exist | `Repos/kb` |

4. Derive **label** if no explicit label is provided:
   - **Local path**: use the last path component of the directory (e.g. `/Users/me/repos/payment-service` → `payment-service`)
   - **Remote URL**:
     - Strip trailing `.git` and trailing `/`
     - Extract the last three path components: `<host>/<org>/<repo>`
     - Examples:
       - `https://github.com/your-org/payment-service.git` → `github.com/your-org/payment-service`
       - `git@github.com:your-org/identity-service` → `github.com/your-org/identity-service`

5. **Enforce label uniqueness before writing** (FR-028). The label is the identity
   of a source — it is what `__SPECKIT_COMMAND_KNOWLEDGE_REMOVE__` takes, and what
   `status` and `search` display. A URL stopped being a unique key the moment
   revisions became pinnable, so uniqueness has to be guaranteed here, once,
   rather than resolved separately by every command that consumes a source.

   Two situations reach a collision, and both are ordinary rather than exotic:

   - two local paths sharing a final component — `~/a/payments` and `~/b/payments`
   - the same repository added twice at different revisions

   On collision, **do not write and do not silently overwrite**. Offer a suffixed
   candidate and let the developer accept or replace it:

   ```
   ⚠️  Label "payments" is already used by https://github.com/org/payments (revision: v2.4.1).
       Suggested label for this source: payments-main
       Accept, or type a different label:
   ```

   When a revision is pinned and no explicit label was given, prefer
   `<derived>-<revision>` as the suggestion — `payments-v2.4.1` — because it is
   the distinction the developer just drew. Never write two entries with the same
   label, under any input.

  After all source syntax checks pass, check that a local path exists and
  contains `.git`. Expand only a leading `~/` to the actual home directory for
  this check; the stored `url` keeps the path as typed. Any shell check uses the
  single-quoting rule in § Configuration Validation Rules, never an unchecked
  value.

6. Append a new source entry to `sources`:
   ```yaml
   - url: <url>
     label: <derived-or-provided-label>
     revision: <revision>         # omit entirely when none was given
     path_filter: <path_filter>   # omit if no filters; string if one filter; YAML list if two+
   ```

  **Merge only into an accepted entry when the URL *and* the revision both match.** An existing entry
   with the same URL **and** the same revision is updated in place (its
   `path_filter`, and its label if not already set). An existing entry with the
   same URL but a **different** revision is a different source and must be left
  alone — appending a second entry is the correct outcome. Existing entries that
  are not accepted are preserved unchanged, never merged or silently repaired.

   This narrows the 1.3.0 rule, which merged on URL alone. Under revision pinning
   that rule would make it impossible to configure two revisions of one repository:
   the second `configure` would silently overwrite the first (FR-009, FR-011).

### 3. Display current configuration

Print the numbered sources list as agent output. Escape every configuration value
and label under § Values in messages (007 FR-005), including control characters;
never format the list through a shell. Apply the same escaping to the success
source list in step 6:

```
Configured sources:
  1. payment-service  →  https://github.com/your-org/payment-service  (path: specs/)
  2. identity-service →  https://github.com/your-org/identity-service  (path: all .md files)
  3. shared-contracts →  ~/repos/shared-contracts                     (paths: specs/, docs/decisions/)
```

Prompt the developer to confirm or edit the displayed configuration before writing.

### 4. Write configuration

Only after validation and confirmation, create `.specify/extensions/knowledge/`
if absent and write the updated `knowledge-config.yml` with the agent's
file-writing tool. Set `schema_version: "1.1"` when creating it and preserve
`schema_version: "1.1"` on edits, along with all existing source entries except
accepted entries explicitly updated in step 2. Entries that failed validation
stay unchanged. Serialize values with valid YAML quoting and escaping so their
literal values are preserved; display escapes must not alter stored values.
Never write or migrate an existing file whose version failed the schema gate.

### 4a. Context budget ceilings

`max_items` and `max_bytes` may appear at the top level and on any source. Validate
both with § Configuration Validation Rules **before** writing, exactly as for every
other field. A malformed per-source value skips only its own source; a malformed
project-wide value is reported and treated as unconfigured.

**A per-source ceiling larger than the project ceiling is clamped, not rejected.**
Report the clamp and keep the source:

```
ℹ️  payments-v2: max_items 400 exceeds the project ceiling of 120; using 120.
ℹ️  payments-v2: max_bytes 4mb exceeds the project ceiling of 1mb; using 1mb.
```

Clamping rather than skipping is deliberate. The value is well-formed and has
exactly **one** safe reading — the project ceiling still binds — so refusing the
source would destroy that source's knowledge to punish a redundancy. Only a value
that cannot be interpreted at all costs a source its place.

The file keeps the user's original number. The clamp applies when the budget is
*used*, not when it is stored, so lowering the project ceiling later never
silently rewrites a source's declared intent.

> A per-source budget is a **sub-ceiling**: it can only lower what a source
> contributes, never raise it. This is the opposite of `max_cache_age`, whose
> per-source value *replaces* the project value despite sitting in the same
> position in the file.

### 5. Update .gitignore

After writing `knowledge-config.yml`, check the project root `.gitignore` (create it if absent) for the two knowledge-cache entries. For each entry that is **not already present**, append it:

```
# knowledge extension cache (local only; do not commit)
.specify/extensions/knowledge/cache/
.specify/extensions/knowledge/knowledge-index.md
```

- If both lines are already in `.gitignore` → silently skip (idempotent).
- If `.gitignore` does not exist → create it with only those two lines + comment.
- Always exit 0; this step must never block the configure workflow.

### 6. Emit success output

```
✅ knowledge-config.yml updated.
✅ .gitignore updated with cache exclusion entries.

Configured sources:
  1. payment-service  →  https://github.com/your-org/payment-service  (path: specs/)
  2. identity-service →  https://github.com/your-org/identity-service  (path: all .md files)

Run __SPECKIT_COMMAND_KNOWLEDGE_SYNC__ to refresh the cache.
```

If no sources are configured (empty list):
```
✅ knowledge-config.yml initialized with empty sources list.
✅ .gitignore updated with cache exclusion entries.

Run __SPECKIT_COMMAND_KNOWLEDGE_CONFIGURE__ <url> to add a knowledge source.
```

---

## --verbose flag

When `--verbose` is present in `$ARGUMENTS`, additionally render the full
configuration as YAML in agent output after the success message, not through a
shell or as raw file bytes. Escape control characters inside scalar values under
§ Values in messages (007 FR-005), with YAML string quoting as needed. Structural
YAML newlines remain newlines; display escaping never changes the file's values:

```
--- VERBOSE: knowledge-config.yml ---
schema_version: "1.1"

sources:
  - url: https://github.com/your-org/payment-service
    label: payment-service
    path_filter: specs/
--- END VERBOSE ---
```

---

## Error cases

Every row exits **0** — validation problems are messages, never process failures
(FR-023). Rules are normative in § Configuration Validation Rules above.
Diagnostics are agent output, with quoted values and `<c>` escaped under
§ Values in messages. Rejected arguments write nothing; schema-gate errors stop
before any source use or configuration/cache change.

| Condition | Output |
|-----------|--------|
| `url` empty or matching no accepted form | `❌ Error: url must be a Git URL (https://, ssh://, git@) or a local path (/, ./, ../, ~/)` |
| `url` contains a character outside the accepted set | `❌ Error: url contains "<c>", which is not allowed. A url may contain only letters, digits and . _ ~ : / @ % + - (a local path may also contain spaces).` |
| A local-path `url` contains a space followed by `-` | `❌ Error: url contains a space followed by "-", which is not allowed. Rename the folder, or link to it under another name.` |
| `url` begins with `-` | `❌ Error: url must not begin with "-" (it would be read as a git option)` |
| Local path does not exist | `❌ Error: Local path "<path>" does not exist.` |
| Local path is not a git repo | `❌ Error: Local path "<path>" is not a Git repository (no .git directory found).` |
| `label` contains whitespace | `❌ Error: label must not contain whitespace` |
| `label` already used by another source | `❌ Error: label "<label>" is already used. Accept the suggested label, type a different one, or remove the existing source first with __SPECKIT_COMMAND_KNOWLEDGE_REMOVE__ <label>.` |
| `revision` fails `^[A-Za-z0-9._/-]+$` | `❌ Error: revision "<value>" contains characters git does not accept in a refname` |
| `revision` begins with `-` | `❌ Error: revision must not begin with "-" (it would be read as a git option)` |
| `revision` contains `..` or ends `.lock` | `❌ Error: revision "<value>" is not a valid refname` |
| A `path_filter` entry contains a character outside the accepted set | `❌ Error: path_filter contains "<c>", which is not allowed. A path_filter may contain only letters, digits and . _ ~ : / @ % + -` |
| A `path_filter` entry begins with `~` | `❌ Error: path_filter must not begin with "~" (it would be read as a home directory)` |
| `path_filter` starts with `/` | `❌ Error: path_filter must not be an absolute path (remove the leading /)` |
| `path_filter` contains `..` | `❌ Error: path_filter must not contain .. (directory traversal not allowed)` |
| `path_filter` begins with `-` | `❌ Error: path_filter must not begin with "-" (it would be read as a git option)` |
| `max_cache_age` fails `^[0-9]+[mhd]$` | `❌ Error: max_cache_age must be a number followed by m, h or d — e.g. 30m, 4h, 7d` |
| `enabled` is not a boolean | `❌ Error: enabled must be true or false` |
| Invalid YAML in existing config | `❌ Error: knowledge-config.yml contains invalid YAML: <parse error>. Fix the file manually and re-run.` |
| `schema_version` is `"1.0"` | `Error: knowledge-config.yml schema_version "1.0" requires migration to "1.1". Back up the file, then change only schema_version. No sources or caches were used or changed.` |
| `schema_version` missing | `Error: Unrecognized knowledge-config.yml schema_version "<missing>". Expected "1.1". No sources or caches were used or changed.` |
| `schema_version` unknown | `Error: Unrecognized knowledge-config.yml schema_version "<value>". Expected "1.1". No sources or caches were used or changed.` |
| SSH URL given with the `<url>@<rev>` form | `❌ Error: SSH URLs already contain "@". Pass the revision with --revision <rev>.` |

---

## Side effects

- Only after validation and confirmation, creates `.specify/extensions/knowledge/` directory if absent
- Creates or modifies `.specify/extensions/knowledge/knowledge-config.yml` using schema `"1.1"`; never writes an existing unsupported-version file
- Does **not** modify `.specify/extensions.yml` — spec-kit auto-registers the hooks when the extension is installed
- Does **not** run sync (prompt developer to run `__SPECKIT_COMMAND_KNOWLEDGE_SYNC__` afterwards)

---

## Exit codes

`0` always — validation errors are surfaced as messages, not process failures.
