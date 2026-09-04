---
description: "Initialize or edit the knowledge source configuration for the current project"
---

## speckit.knowledge.configure

**Purpose**: Initialize or edit the knowledge source configuration for the current project.

**Arguments**: `$ARGUMENTS` — optional. May contain:
- A Git repository URL (SSH or HTTPS), e.g. `https://github.com/your-org/your-repo`
- **Or** a local filesystem path to a Git repository — absolute (`/Users/me/repos/your-repo`) or tilde (`~/repos/your-repo`)
- **Optional path filter(s)** after the URL/path. Pass one **or more** folder paths to scope indexing to only those folders. Examples:
  - `https://github.com/your-org/your-repo specs/`
  - `~/repos/your-repo specs/ docs/decisions/`
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

`sources:` written with no value parses as **null**, not as an empty list. Treat
absent, null, and `[]` identically: the project has no configured sources.

| Field | Rule |
|-------|------|
| `schema_version` | Required. Exactly `"1.0"`. |
| `max_cache_age` (top level and per source) | Optional. Matches `^[0-9]+[mhd]$` — `30m`, `4h`, `7d`. |
| `url` | Required, non-empty. Either a local path (`/`, `./`, `../`, `~`) that exists and contains `.git`, or a remote URL matching `^(https?://\|ssh://\|git\+ssh://\|git@)`. **Must not begin with `-`.** |
| `label` | Optional in the file, derived when absent. Non-empty, no whitespace, **unique across `sources`** (FR-028). |
| `revision` | Optional. Non-empty, matching `^[A-Za-z0-9._/-]+$`. **Must not begin with `-`**, must not contain `..`, must not end with `.lock`. |
| `path_filter` | Optional. A string or a list of strings. Each entry non-empty, **no leading `/`**, **no `..`**, and **must not begin with `-`**. |
| `enabled` | Optional, default `true`. Exactly `true` or `false` — `"yes"` and `1` are rejected. |

### Why no value may begin with `-`

Every `url`, `revision`, and `path_filter` is interpolated into a `git` command
line. A value beginning with `-` is parsed by `git` as an **option**, not as data.
A `revision` of `--upload-pack=<command>` handed to `git fetch` is remote code
execution on the developer's machine, triggered by nothing more than a pull
request that edits a YAML file.

FR-034 therefore requires **two** defenses, and neither is sufficient alone:

1. **Reject** — any value beginning with `-` fails its rule above.
2. **Neutralize** — every `git` invocation that consumes a configuration value
   places `--` before it, so a value that bypassed defense 1 still cannot be read
   as an option.

### On failure

A value that violates its rule skips **only its own source** (FR-030):

```
⚠️  payments-v2: skipped — invalid `revision` value "-u" (must not begin with "-")
```

Every other source is processed normally and the command exits **0** (FR-023).
Always name the field and the offending value, so the user can fix it without
guessing.

---

## Behavior

### 1. Locate or create configuration file

Check for `.specify/extensions/knowledge/knowledge-config.yml` in the project root.

- **If absent**: create the directory `.specify/extensions/knowledge/` and copy the extension's `config-template.yml` to that location, producing a file with `schema_version: "1.0"` and `sources: []`.
- **If present**: read the existing file and parse its `sources` list.

### 2. Parse arguments (if provided)

If `$ARGUMENTS` is non-empty (excluding `--verbose`):

1. Split `$ARGUMENTS` on whitespace.
2. First token is the **URL or local path**. Validate:
   - Must be non-empty
   - Must not be `--verbose`
   - Detect type:
     - **Local path**: starts with `/`, `./`, `../`, or `~` → expand `~` to `$HOME`
     - **Remote URL**: everything else (SSH `git@...` or HTTPS `https://...`)
3. **All remaining tokens** (zero or more, after the first) are **path filters**. Each must:
   - Not start with `/` (no absolute paths)
   - Not contain `..` (no directory traversal)
   - Not begin with `-` (it would be read as a git option — FR-034)
   - Not be `--verbose`, `--revision`, or a `--revision` value (skip flag tokens)
   - If any token is invalid: print an error for that field and stop — do not write
   - **Zero tokens** → omit `path_filter` from the source entry (indexes all `.md` files in the repo)
   - **One token** → store as a single string for readability: `path_filter: specs/`
   - **Two or more tokens** → store as a YAML list: `path_filter: [specs/, docs/decisions/]`

3a. **Extract the revision**, if given (FR-013):
   - `--revision <rev>` → take the following token
   - otherwise, if the URL token contains `@` **and** the URL is not SSH-style
     (`git@…` or `ssh://…`), split on the **last** `@`: everything before is the
     URL, everything after is the revision
   - an SSH URL written as `<url>@<rev>` is an error, not a guess — see § Error cases
   - validate the value against the `revision` rule in § Configuration Validation Rules
   - omit `revision` from the entry entirely when none was given: that keeps the
     source on the remote's default revision **and** keeps the cache slug it
     already has (FR-010, FR-024)
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

6. Append a new source entry to `sources`:
   ```yaml
   - url: <url>
     label: <derived-or-provided-label>
     revision: <revision>         # omit entirely when none was given
     path_filter: <path_filter>   # omit if no filters; string if one filter; YAML list if two+
   ```

   **Merge only when the URL *and* the revision both match.** An existing entry
   with the same URL **and** the same revision is updated in place (its
   `path_filter`, and its label if not already set). An existing entry with the
   same URL but a **different** revision is a different source and must be left
   alone — appending a second entry is the correct outcome.

   This narrows the 1.3.0 rule, which merged on URL alone. Under revision pinning
   that rule would make it impossible to configure two revisions of one repository:
   the second `configure` would silently overwrite the first (FR-009, FR-011).

### 3. Display current configuration

Print the numbered sources list:

```
Configured sources:
  1. payment-service  →  https://github.com/your-org/payment-service  (path: specs/)
  2. identity-service →  https://github.com/your-org/identity-service  (path: all .md files)
  3. shared-contracts →  ~/repos/shared-contracts                     (paths: specs/, docs/decisions/)
```

Prompt the developer to confirm or edit the displayed configuration before writing.

### 4. Write configuration

On confirmation, write the updated `knowledge-config.yml` back to disk, preserving `schema_version: "1.0"` at the top and all existing source entries.

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

When `--verbose` is present in `$ARGUMENTS`, additionally print the full YAML content of `knowledge-config.yml` after the success message:

```
--- VERBOSE: knowledge-config.yml ---
schema_version: "1.0"

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

| Condition | Output |
|-----------|--------|
| `url` empty or matching no accepted form | `❌ Error: url must be a Git URL (https://, ssh://, git@) or a local path (/, ./, ../, ~)` |
| `url` begins with `-` | `❌ Error: url must not begin with "-" (it would be read as a git option)` |
| Local path does not exist | `❌ Error: Local path "<path>" does not exist.` |
| Local path is not a git repo | `❌ Error: Local path "<path>" is not a Git repository (no .git directory found).` |
| `label` contains whitespace | `❌ Error: label must not contain whitespace` |
| `label` already used by another source | `❌ Error: label "<label>" is already used. Choose another with --label, or remove the existing source first.` |
| `revision` fails `^[A-Za-z0-9._/-]+$` | `❌ Error: revision "<value>" contains characters git does not accept in a refname` |
| `revision` begins with `-` | `❌ Error: revision must not begin with "-" (it would be read as a git option)` |
| `revision` contains `..` or ends `.lock` | `❌ Error: revision "<value>" is not a valid refname` |
| `path_filter` starts with `/` | `❌ Error: path_filter must not be an absolute path (remove the leading /)` |
| `path_filter` contains `..` | `❌ Error: path_filter must not contain .. (directory traversal not allowed)` |
| `path_filter` begins with `-` | `❌ Error: path_filter must not begin with "-" (it would be read as a git option)` |
| `max_cache_age` fails `^[0-9]+[mhd]$` | `❌ Error: max_cache_age must be a number followed by m, h or d — e.g. 30m, 4h, 7d` |
| `enabled` is not a boolean | `❌ Error: enabled must be true or false` |
| Invalid YAML in existing config | `❌ Error: knowledge-config.yml contains invalid YAML: <parse error>. Fix the file manually and re-run.` |
| `schema_version` missing | `❌ Error: knowledge-config.yml is missing schema_version. Expected "1.0".` |
| `schema_version` unknown | `⚠️ Warning: Unknown schema_version "<value>". Proceeding with caution.` |
| SSH URL given with the `<url>@<rev>` form | `❌ Error: SSH URLs already contain "@". Pass the revision with --revision <rev>.` |

---

## Side effects

- Creates `.specify/extensions/knowledge/` directory if absent
- Creates or modifies `.specify/extensions/knowledge/knowledge-config.yml`
- Does **not** modify `.specify/extensions.yml` (hook registration is a separate manual step)
- Does **not** run sync (prompt developer to run `__SPECKIT_COMMAND_KNOWLEDGE_SYNC__` afterwards)

---

## Exit codes

`0` always — validation errors are surfaced as messages, not process failures.
