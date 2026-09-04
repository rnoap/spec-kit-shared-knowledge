---
description: "Remove, disable, or re-enable a configured knowledge source"
---

## speckit.knowledge.remove

**Purpose**: Remove, disable, or re-enable a configured knowledge source without
hand-editing YAML.

> The command is named for its destructive mode, but it owns the **whole activation
> lifecycle**. Disabling and re-enabling live here too, so one help surface shows
> every way a source can be switched on or off. There is deliberately no second
> command that also writes `enabled`.

**Arguments**: `$ARGUMENTS` — an optional source identifier, plus optional flags:

- `<label>` — the source to act on. **This is the identity of a source.**
- `<url>` — accepted as an identifier **only** when it resolves to exactly one
  source. Revision pinning lets two sources share a URL, so a URL is no longer a
  unique key.
- `--disable` — mark the source inactive; keep its entry **and** its cache
- `--enable` — mark a disabled source active again
- *(no identifier)* — list the configured sources and prompt for a choice
- `--verbose` — print the resulting YAML after write

---

## Configuration Validation Rules

Read `.specify/extensions/knowledge/knowledge-config.yml` and apply the rules in
`speckit.knowledge.sync.md` § Configuration Validation Rules before acting on any
value.

This command writes the configuration file, so it validates for a second reason
beyond FR-029: refusing to persist a file whose other entries are already invalid
keeps a bad edit from becoming this command's fault. When an unrelated source
fails a rule, report it and continue — the requested operation still proceeds, and
the exit code is still 0.

---

## Behavior

### 1. Resolve the source

Match in this order. Do **not** fall through once a stage matches:

1. **Exact `label` match.** One source, or none.
2. **`url` match**, only if stage 1 found nothing. Compare the raw configured
   `url` string.
   - Exactly one match → act on it.
   - **Two or more matches → ambiguous.** List the candidates with their
     revisions, change nothing, exit 0.
3. **No match** → report, list the configured labels, change nothing, exit 0.

When `$ARGUMENTS` contains no identifier, print the source list with each entry's
state and prompt for a selection instead of guessing.

### 2. Apply the requested mode

| Mode | Configuration entry | Cache directory |
|------|---------------------|-----------------|
| default (remove) | **deleted** | **purged** |
| `--disable` | retained, `enabled: false` | **retained** |
| `--enable` | retained, `enabled: true` | retained |

Compute the cache directory with the Source Slug Generation algorithm in
`speckit.knowledge.sync.md` § Algorithm Reference. A source that pins a `revision`
hashes that revision into its slug, so removing one revision of a repository must
not touch the cache of another revision of the same repository.

**Purge is immediate**, not deferred to a cleanup pass. "Remove" that leaves the
bytes behind is the more surprising reading, and a garbage-collection concept is
not worth introducing for one directory.

**Disable retains the cache on purpose.** That retention is the entire reason to
prefer `--disable` over remove for a temporary pause: re-enabling costs nothing.

### 3. Write the configuration

Write `knowledge-config.yml` back with `schema_version: "1.0"` preserved and every
other source entry untouched.

### 4. Report

Removal:

```
✅ Removed source "payments-v2" from knowledge-config.yml
✅ Purged cache directory .specify/extensions/knowledge/cache/abc123def456/
   Run __SPECKIT_COMMAND_KNOWLEDGE_SYNC__ to rebuild the index.
```

Disable:

```
✅ Disabled source "payments-v2". Its cache is retained — re-enabling will not re-download.
   Run __SPECKIT_COMMAND_KNOWLEDGE_SYNC__ to rebuild the index without it.
```

Re-enable:

```
✅ Enabled source "payments-v2". Its cache was retained, so no re-download is needed.
   Run __SPECKIT_COMMAND_KNOWLEDGE_SYNC__ to rebuild the index with it.
```

No identifier given:

```
Configured sources:
  1. payments-v2        enabled   https://github.com/org/payments  (revision: v2.4.1)
  2. payments-main      enabled   https://github.com/org/payments  (revision: main)
  3. identity-service   disabled  ~/repos/identity-service         (revision: default)

Which source? (number, or a label)
```

Ambiguous URL:

```
❌ "https://github.com/org/payments" matches 2 configured sources:
     payments-v2   (revision: v2.4.1)
     payments-main (revision: main)
   Re-run with a label to disambiguate. Nothing was changed.
```

Unknown identifier:

```
❌ No configured source matches "paymnets". Nothing was changed.
   Configured sources: payments-v2, payments-main, identity-service
```

Already in the requested state — report and change nothing, rather than treating
it as an error:

```
ℹ️  Source "payments-v2" is already disabled. Nothing was changed.
```

---

## --verbose flag

When `--verbose` is present in `$ARGUMENTS`, print the full YAML after the success
message:

```
--- VERBOSE: knowledge-config.yml ---
schema_version: "1.0"

sources:
  - url: https://github.com/org/payments
    label: payments-main
    revision: main
    path_filter: specs/
--- END VERBOSE ---
```

---

## Error cases

| Condition | Status | Exit |
|-----------|--------|------|
| No identifier given | Interactive source list | 0 |
| Identifier matches no source | Message + configured labels listed | 0 |
| URL matches two or more sources | Candidates listed, nothing changed | 0 |
| Source already in the requested state | Informational message | 0 |
| Config file absent | `❌ Error: knowledge-config.yml not found. Run __SPECKIT_COMMAND_KNOWLEDGE_CONFIGURE__ to initialize.` | 0 |
| Config YAML invalid | Parse error reported, nothing changed | 0 |
| An unrelated source fails a validation rule | Reported; requested operation still proceeds | 0 |
| Cache directory already absent on remove | Entry still removed; no warning needed | 0 |
| Cache directory cannot be deleted | Entry removed, cache retention reported as a warning | 0 |

---

## Side effects

- Modifies `.specify/extensions/knowledge/knowledge-config.yml`
- Deletes `cache/<slug>/` **on removal only** — never on `--disable`
- Does **not** run sync, and does **not** touch `knowledge-index.md`. The index is
  rebuilt by the next sync, which keeps this command's failure surface to one file
- Does **not** modify `.specify/extensions.yml`

---

## Exit codes

`0` always — every condition above is surfaced as a message, not a process failure.
