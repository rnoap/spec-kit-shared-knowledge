---
description: "Initialize or edit the knowledge source configuration for the current project"
---

## speckit.xrepo.configure

**Purpose**: Initialize or edit the knowledge source configuration for the current project.

**Arguments**: `$ARGUMENTS` — optional. May contain:
- A Git repository URL (SSH or HTTPS), e.g. `https://gecgithub01.walmart.com/org/repo`
- An optional path filter after the URL, e.g. `https://gecgithub01.walmart.com/org/repo specs/`
- The flag `--verbose` to print full YAML after write

---

## Behavior

### 1. Locate or create configuration file

Check for `.specify/extensions/cross-repo-knowledge/cross-repo-knowledge.yml` in the project root.

- **If absent**: create the directory `.specify/extensions/cross-repo-knowledge/` and copy the extension's `config-template.yml` to that location, producing a file with `schema_version: "1.0"` and `sources: []`.
- **If present**: read the existing file and parse its `sources` list.

### 2. Parse arguments (if provided)

If `$ARGUMENTS` is non-empty (excluding `--verbose`):

1. Split `$ARGUMENTS` on whitespace.
2. First token is the **URL**. Validate:
   - Must be non-empty
   - Must not be `--verbose`
3. Second token (if present) is the **path_filter**. Validate:
   - Must not start with `/` (no absolute paths)
   - Must not contain `..` (no directory traversal)
   - If invalid: print an error for that field and stop — do not write
4. Derive **label** from URL if no explicit label is provided:
   - Strip trailing `.git` from the URL
   - Strip trailing `/`
   - Extract the last three path components: `<host>/<org>/<repo>`
   - Examples:
     - `https://gecgithub01.walmart.com/payment-platform/payment-service.git` → `gecgithub01.walmart.com/payment-platform/payment-service`
     - `git@gecgithub01.walmart.com:identity/identity-service` → `gecgithub01.walmart.com/identity/identity-service`
5. Append a new source entry to `sources`:
   ```yaml
   - url: <url>
     label: <derived-or-provided-label>
     path_filter: <path_filter>   # only if provided
   ```
   If a source with the same `url` already exists: update its `path_filter` (and label if not already set) instead of appending a duplicate.

### 3. Display current configuration

Print the numbered sources list:

```
Configured sources:
  1. payment-service  →  https://gecgithub01.walmart.com/org/payment-service  (path: specs/)
  2. identity-service →  https://gecgithub01.walmart.com/org/identity-service  (path: all .md files)
```

Prompt the developer to confirm or edit the displayed configuration before writing.

### 4. Write configuration

On confirmation, write the updated `cross-repo-knowledge.yml` back to disk, preserving `schema_version: "1.0"` at the top and all existing source entries.

### 5. Emit success output

```
✅ cross-repo-knowledge.yml updated.

Configured sources:
  1. payment-service  →  https://gecgithub01.walmart.com/org/payment-service  (path: specs/)
  2. identity-service →  https://gecgithub01.walmart.com/org/identity-service  (path: all .md files)

Run /speckit-xrepo-sync to refresh the cache.
```

If no sources are configured (empty list):
```
✅ cross-repo-knowledge.yml initialized with empty sources list.

Run /speckit-xrepo-configure <url> to add a knowledge source.
```

---

## --verbose flag

When `--verbose` is present in `$ARGUMENTS`, additionally print the full YAML content of `cross-repo-knowledge.yml` after the success message:

```
--- VERBOSE: cross-repo-knowledge.yml ---
schema_version: "1.0"

sources:
  - url: https://gecgithub01.walmart.com/org/payment-service
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
| Invalid YAML in existing config | `❌ Error: cross-repo-knowledge.yml contains invalid YAML: <parse error>. Fix the file manually and re-run.` |
| `schema_version` missing | `❌ Error: cross-repo-knowledge.yml is missing schema_version. Expected "1.0".` |
| `schema_version` unknown | `⚠️ Warning: Unknown schema_version "<value>". Proceeding with caution.` |

---

## Side effects

- Creates `.specify/extensions/cross-repo-knowledge/` directory if absent
- Creates or modifies `.specify/extensions/cross-repo-knowledge/cross-repo-knowledge.yml`
- Does **not** modify `.specify/extensions.yml` (hook registration is a separate manual step)
- Does **not** run sync (prompt developer to run `/speckit-xrepo-sync` afterwards)

---

## Exit codes

`0` always — validation errors are surfaced as messages, not process failures.
