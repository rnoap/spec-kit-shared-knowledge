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

**File-level schema gate (007 FR-014):** before per-source validation, source
resolution or listing, accept only `schema_version: "1.1"`. For `"1.0"`, print as
agent output:

```text
Error: knowledge-config.yml schema_version "1.0" requires migration to "1.1". Back up the file, then change only schema_version. No sources or caches were used or changed.
```

For a missing or unknown version, print the following, substituting `<missing>`
when absent and escaping the value under the message rule below:

```text
Error: Unrecognized knowledge-config.yml schema_version "<value>". Expected "1.1". No sources or caches were used or changed.
```

Both paths exit 0 without using source values, computing slugs, reading source
manifests, checking reachability, pruning, or writing configuration or caches.
No entry is deleted or `enabled` toggled, even for an invalid target. Never
migrate or downgrade automatically; a hook finishes and its parent continues.

Only after the gate succeeds, apply every per-source rule in the agent's own
reasoning, in the order the canonical sync validation block specifies. A target
is **accepted** only when every one of its values passes. Print one escaped
refusal line per source that is not accepted, before other output about sources
(007 FR-002). No value of such a source reaches a shell, not even for its slug or
a message. An unrelated invalid source is reported and preserved unchanged; it
does not block the requested operation, and the exit code is still 0. An invalid
target can receive only the entry changes described in step 2, under schema
`"1.1"` only.

**Values in messages (007 FR-005):** every diagnostic, success message, source
list, ambiguity candidate, configured-label list and verbose value is the agent's
own output, never `echo` or `printf`. Apply sync's message rule to configuration
values, labels, identifiers and slug output: line feed as `\n`, tab as `\t`,
carriage return as `\r`, escape U+001B as `\e`, and other characters below U+0020
or from U+007F to U+009F as `\xHH`. Show backslash as `\\` and a double quote
inside a quoted value as `\"`. Leave other characters unchanged. Escape values
only for display, not for matching or configuration persistence.

---

## Behavior

Complete the file-level schema gate and per-source validation above before
resolving or listing sources. An unsupported version stops here without changing
an entry or cache.

### 1. Resolve the source

Perform exact `label` and raw `url` string comparisons in the agent's own
reasoning, including when the target is not accepted. Never hand either value or
the user's identifier to a shell, even to find a match. Escaped display strings
are not identity keys.

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
| default (remove) | **deleted** | **purged only for an accepted target with a valid slug** |
| `--disable` | retained, `enabled: false` | **retained** |
| `--enable` | retained, `enabled: true` | retained |

**Target not accepted (schema `"1.1"` only):** delete its entry on remove, or
toggle only `enabled` for `--disable` or `--enable`, preserving its other fields.
Do not compute its slug or cache directory, purge its cache, or hand any of its
values to a shell (007 FR-002). Leave the cache for step 8a of the next sync in
which every source is accepted, and use the exact cache-retained notice in step
4. An already-requested activation state still changes nothing.

**Accepted target, default removal only:** compute its slug with Source Slug
Generation in `speckit.knowledge.sync.md` § Algorithm Reference. Before any use
of the slug, including constructing its cache path, confirm in the agent's own
reasoning that it is exactly **12 lowercase hex characters**, matching
`^[0-9a-f]{12}$`. An empty, uppercase, non-hex or wrong-length slug purges nothing;
the entry is still removed. Print this warning with the returned value escaped
under the message rule:

```text
⚠️  Cache not purged: the slug procedure returned "<value>", not 12 lowercase hex characters.
```

Only after that check passes, purge `.specify/extensions/knowledge/cache/<slug>/`
immediately. Never purge the cache root or any other directory. A source that
pins a `revision` hashes that revision into its slug, so removing one revision
must not touch another revision's cache. Never claim a purge succeeded if the
slug check or deletion failed.

**Disable retains the cache on purpose.** That retention is the entire reason to
prefer `--disable` over remove for a temporary pause: re-enabling costs nothing.
Neither activation mode computes a slug or purges a cache.

### 3. Write the configuration

Write `knowledge-config.yml` back with the agent's file-writing tool, preserving
`schema_version: "1.1"`, every other top-level key such as `agents_md`, and every
other source entry untouched, including invalid entries. Display escaping must not
alter persisted values. Never write an unsupported-version file.

### 3a. Update the knowledge section in `AGENTS.md`

After step 3 writes the configuration, and only when
`.specify/extensions/knowledge/knowledge-index.md` exists, apply § Agent Context
Section from `speckit.knowledge.sync.md` in `write` mode. Its labels are those of
the sources that are enabled and accepted **after** this change, so a removed or
disabled source drops out at once. With no label left, the procedure removes the
section (010 FR-015).

This step does not run when nothing was written: after the schema gate, an
unknown or ambiguous identifier, a source already in the requested state, or the
interactive list. It never writes `knowledge-index.md` (010 FR-016). Until the next
sync the index can still list a removed or disabled source, and the section tells
the agent to use only the sources it lists.

Print its line, if any, after the step 4 report.

### 4. Report

Removal of an accepted source after a successful slug check and purge:

```
✅ Removed source "payments-v2" from knowledge-config.yml
✅ Purged cache directory .specify/extensions/knowledge/cache/abc123def456/
   Run __SPECKIT_COMMAND_KNOWLEDGE_SYNC__ to rebuild the index.
```

Removal of a target that is not accepted uses this exact cache-retained notice:

```text
✅ Removed source "notes" from knowledge-config.yml
ℹ️  Its cache was left in place: the source fails validation, so its cache directory is not computed.
   The next __SPECKIT_COMMAND_KNOWLEDGE_SYNC__ in which every source is accepted prunes it.
```

For `--disable` or `--enable` on an invalid target, replace only the first line
with `✅ Disabled source "<label>".` or `✅ Enabled source "<label>".` and keep the
same cache-retained notice. For an accepted source whose slug check fails, print
the removal success line followed by the cache-not-purged warning from step 2,
never the purged-cache line. Escape all substituted values under the message
rule above.

Disable:

```
✅ Disabled source "payments-v2". Its cache is retained — re-enabling will not re-download.
   Run __SPECKIT_COMMAND_KNOWLEDGE_SYNC__ to rebuild the index without it.
```

Re-enable:

```
✅ Enabled source "payments-v2". Its cache was retained, so no re-download is needed.
   Run __SPECKIT_COMMAND_KNOWLEDGE_SYNC__ to rebuild the index with it.
✅ Updated the shared knowledge section in AGENTS.md.
```

The last line comes from step 3a and is one of the report lines in § Agent Context
Section. It is absent when no index exists.

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

When `--verbose` is present in `$ARGUMENTS`, render the full YAML after the success
message as agent output, never a shell dump. Escape every value under the message
rule above, including controls, backslashes and double quotes inside values.
This is display-only escaping; the stored YAML values remain unchanged. No
verbose source output is produced when the schema gate stops the command.

```
--- VERBOSE: knowledge-config.yml ---
schema_version: "1.1"

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
| Legacy schema `"1.0"` | Migration diagnostic above; no source use, entry changes or cache purge | 0 |
| Missing or unknown schema version | Unrecognized-version diagnostic above; no source use, entry changes or cache purge | 0 |
| An unrelated source fails a validation rule | Reported; requested operation still proceeds | 0 |
| Target fails validation under schema `"1.1"` | Entry removed or `enabled` toggled as requested; no slug computed or cache purged; cache-retained notice above | 0 |
| Slug is not exactly 12 lowercase hex characters | Entry removed; cache not purged; escaped warning above | 0 |
| Cache directory already absent on remove | Entry still removed; no warning needed | 0 |
| Cache directory cannot be deleted | Entry removed, cache retention reported as a warning | 0 |
| `agents_md` not exactly `true` or `false` | Requested change applied; invalid-key line; `AGENTS.md` untouched | 0 |
| `AGENTS.md` knowledge markers damaged | Requested change applied; damaged line; `AGENTS.md` untouched | 0 |
| `AGENTS.md` unreadable or not writable | Requested change applied; write-failed line | 0 |
| No `knowledge-index.md` exists | Requested change applied; `AGENTS.md` untouched, no line | 0 |

---

## Side effects

- Modifies `.specify/extensions/knowledge/knowledge-config.yml` only under schema
  `"1.1"`
- Deletes `cache/<slug>/` **on removal only**, for an accepted target after the
  12-lowercase-hex slug check; never for an invalid target, an unsupported schema,
  `--disable` or `--enable`
- Creates, updates or removes the knowledge section in the project's root
  `AGENTS.md` (step 3a), only when `knowledge-index.md` exists, and never a byte
  outside the section
- Does **not** run sync, and does **not** touch `knowledge-index.md`. The index is
  rebuilt by the next sync, so this command never needs the network or index logic
- Does **not** modify `.specify/extensions.yml`

---

## Exit codes

`0` always — every condition above is surfaced as a message, not a process failure.
