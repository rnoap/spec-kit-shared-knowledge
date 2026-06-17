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
- The flag `--verbose` to print full YAML after write

---

## Behavior

### 1. Locate or create configuration file

Check for `.specify/extensions/knowledge/knowledge.yml` in the project root.

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
   - Not be `--verbose` (skip flag tokens)
   - If any token is invalid: print an error for that field and stop — do not write
   - **Zero tokens** → omit `path_filter` from the source entry (indexes all `.md` files in the repo)
   - **One token** → store as a single string for readability: `path_filter: specs/`
   - **Two or more tokens** → store as a YAML list: `path_filter: [specs/, docs/decisions/]`
4. Derive **label** if no explicit label is provided:
   - **Local path**: use the last path component of the directory (e.g. `/Users/me/repos/payment-service` → `payment-service`)
   - **Remote URL**:
     - Strip trailing `.git` and trailing `/`
     - Extract the last three path components: `<host>/<org>/<repo>`
     - Examples:
       - `https://github.com/your-org/payment-service.git` → `github.com/your-org/payment-service`
       - `git@github.com:your-org/identity-service` → `github.com/your-org/identity-service`
5. Append a new source entry to `sources`:
   ```yaml
   - url: <url>
     label: <derived-or-provided-label>
     path_filter: <path_filter>   # omit if no filters; string if one filter; YAML list if two+
   ```
   If a source with the same `url` already exists: update its `path_filter` (and label if not already set) instead of appending a duplicate.

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

On confirmation, write the updated `knowledge.yml` back to disk, preserving `schema_version: "1.0"` at the top and all existing source entries.

### 5. Update .gitignore

After writing `knowledge.yml`, check the project root `.gitignore` (create it if absent) for the two knowledge-cache entries. For each entry that is **not already present**, append it:

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
✅ knowledge.yml updated.
✅ .gitignore updated with cache exclusion entries.

Configured sources:
  1. payment-service  →  https://github.com/your-org/payment-service  (path: specs/)
  2. identity-service →  https://github.com/your-org/identity-service  (path: all .md files)

Run /speckit-knowledge-sync to refresh the cache.
```

If no sources are configured (empty list):
```
✅ knowledge.yml initialized with empty sources list.
✅ .gitignore updated with cache exclusion entries.

Run /speckit-knowledge-configure <url> to add a knowledge source.
```

---

## --verbose flag

When `--verbose` is present in `$ARGUMENTS`, additionally print the full YAML content of `knowledge.yml` after the success message:

```
--- VERBOSE: knowledge.yml ---
schema_version: "1.0"

sources:
  - url: https://github.com/your-org/payment-service
    label: payment-service
    path_filter: specs/
--- END VERBOSE ---
```

---

## Error cases

| Condition | Output |
|-----------|--------|
| `path_filter` starts with `/` | `❌ Error: path_filter must not be an absolute path (remove the leading /)` |
| `path_filter` contains `..` | `❌ Error: path_filter must not contain .. (directory traversal not allowed)` |
| Local path does not exist | `❌ Error: Local path "<path>" does not exist.` |
| Local path is not a git repo | `❌ Error: Local path "<path>" is not a Git repository (no .git directory found).` |
| Invalid YAML in existing config | `❌ Error: knowledge.yml contains invalid YAML: <parse error>. Fix the file manually and re-run.` |
| `schema_version` missing | `❌ Error: knowledge.yml is missing schema_version. Expected "1.0".` |
| `schema_version` unknown | `⚠️ Warning: Unknown schema_version "<value>". Proceeding with caution.` |

---

## Side effects

- Creates `.specify/extensions/knowledge/` directory if absent
- Creates or modifies `.specify/extensions/knowledge/knowledge.yml`
- Does **not** modify `.specify/extensions.yml` (hook registration is a separate manual step)
- Does **not** run sync (prompt developer to run `/speckit-knowledge-sync` afterwards)

---

## Exit codes

`0` always — validation errors are surfaced as messages, not process failures.
