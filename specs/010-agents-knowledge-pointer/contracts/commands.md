# Contract: Command surface

**Feature**: [../agents-knowledge-pointer.spec.md](../agents-knowledge-pointer.spec.md) · **Plan**: [../plan.md](../plan.md) · **Research**: [../research.md](../research.md)

The commands keep their names, arguments, flags and hooks. **Exit code is `0` on every path, including every path added here.**
What changes is that `speckit.knowledge.sync` and `speckit.knowledge.remove` keep the knowledge section in the project's root `AGENTS.md`, and report what they did on one line.
The section text and the write and remove rules are in [agents-md-section.md](./agents-md-section.md).
Command prose cites this feature's requirements as `010 FR-001`.

---

## 1. Commands

| Command | Change |
| --- | --- |
| `speckit.knowledge.sync` | New `§ Agent Context Section` in § Algorithm Reference. Step 1a applies it in remove mode. New step 8b applies it after the index is written. One report line. |
| `speckit.knowledge.remove` | New step 3a applies `§ Agent Context Section` by reference after the config write, including with `--disable` and `--enable`. One report line. |
| `speckit.knowledge.configure` | Validation-rules row only. Step 4 preserves every top-level key. Never touches `AGENTS.md`. |
| `speckit.knowledge.status` | Validation-rules row only. Never touches `AGENTS.md`. |
| `speckit.knowledge.search` | Unchanged |

No flag is added. `--no-context-output` keeps controlling only the printed step 10 block ([research R9](../research.md#r9---no-context-output-does-not-affect-the-section)).

---

## 2. When the section step runs

The section step is one application of `§ Agent Context Section`.
It runs at most once per command run.
It never runs after an early-exit error: config absent, invalid YAML, the schema gate, or a missing `sources` key.

| Command | Point | Runs when | Labels | Mode |
| --- | --- | --- | --- | --- |
| `speckit.knowledge.sync` | Step 1a, after deleting the index | No enabled source remains | None | Remove |
| `speckit.knowledge.sync` | Step 8b, after step 8a | `knowledge-index.md` exists, written this run or kept from an earlier one | Enabled, accepted sources | Write |
| `speckit.knowledge.remove` | Step 3a, after step 3 writes the config | `knowledge-index.md` exists | Enabled, accepted sources after the change | Write, or remove when no label remains |

- With `agents_md: false`, write mode becomes remove mode.
- When every source is unreachable on a first sync, no index exists, so step 8b does nothing ([research R6](../research.md#r6-when-no-index-exists-sync-leaves-the-section-alone)).
- When remove finds no index, step 3a does nothing (FR-015).
- An ambiguous, unknown or already-applied identifier changes no config, so step 3a does not run.
- Neither command ever writes `knowledge-index.md` from the section step. Remove never writes it at all (FR-016).

Inside the step, the checks run in this order, and the first that fails ends the step:

1. `agents_md` is absent, `true` or `false`.
2. `AGENTS.md` can be read, or does not exist.
3. The markers are absent or present, not damaged.
4. The write or removal succeeds.

---

## 3. Report lines

The step prints exactly one line, or none.
Every line is agent output, never `echo` or `printf`.
`<value>`, `<problem>` and `<reason>` are escaped under § Values in messages (007 FR-005).

| Outcome | Line |
| --- | --- |
| Created | `✅ Created AGENTS.md with the shared knowledge section.` |
| Updated, section added to an existing file | `✅ Added the shared knowledge section to AGENTS.md.` |
| Updated, section replaced | `✅ Updated the shared knowledge section in AGENTS.md.` |
| Unchanged | `ℹ️  The shared knowledge section in AGENTS.md is already up to date. Nothing was changed.` |
| Removed | `✅ Removed the shared knowledge section from AGENTS.md.` |
| Removed, file deleted | `✅ Removed the shared knowledge section and deleted AGENTS.md, which held nothing else.` |
| Skipped, damaged markers | `⚠️  AGENTS.md was left untouched: <problem>. Delete the knowledge marker lines and the text between them, then run __SPECKIT_COMMAND_KNOWLEDGE_SYNC__.` |
| Skipped, invalid key | ``⚠️  Ignoring `agents_md` value "<value>" (must be true or false). AGENTS.md was left untouched.`` |
| Write failed | `⚠️  Could not update AGENTS.md (<reason>). Everything else in this run completed.` |

`<problem>` is one of:

| Markers found | `<problem>` |
| --- | --- |
| Start and end lines not exactly one each | `found <n> "<!-- KNOWLEDGE START -->" and <m> "<!-- KNOWLEDGE END -->" lines` |
| One of each, end before start | `"<!-- KNOWLEDGE END -->" comes before "<!-- KNOWLEDGE START -->"` |

`<reason>` is the error the file tool returned, such as `permission denied`.
It covers read failures and write failures alike (FR-012).

No line is printed when the step does not run, or when remove mode finds no section.
With `agents_md: false` and no section present, `AGENTS.md` stays silent and untouched (FR-010).

Examples:

```text
✅ Knowledge index updated: 20 items from 2 sources.
   → .specify/extensions/knowledge/knowledge-index.md
✅ Created AGENTS.md with the shared knowledge section.
```

```text
✅ Enabled source "payments-v2". Its cache was retained, so no re-download is needed.
   Run __SPECKIT_COMMAND_KNOWLEDGE_SYNC__ to rebuild the index with it.
✅ Updated the shared knowledge section in AGENTS.md.
```

```text
⚠️  AGENTS.md was left untouched: found 1 "<!-- KNOWLEDGE START -->" and 0 "<!-- KNOWLEDGE END -->" lines. Delete the knowledge marker lines and the text between them, then run __SPECKIT_COMMAND_KNOWLEDGE_SYNC__.
```

### 3.1 Placement

| Command | Path | The line follows |
| --- | --- | --- |
| `speckit.knowledge.sync` | Normal | The pointer line `   → .specify/extensions/knowledge/knowledge-index.md` |
| `speckit.knowledge.sync` | Step 1a | The last line of the step 1a report |
| `speckit.knowledge.remove` | Remove, `--disable`, `--enable` | The last line of the step 4 report |

Sync's emission order becomes: status lines, summary line, pointer line, `AGENTS.md` line, one blank line, then the step 10 block.
A hook-driven sync prints the same line, finishes and exits 0.

---

## 4. Error cases

New rows in each command's error table:

| Condition | Status | Exit |
|-----------|--------|------|
| `agents_md` not exactly `true` or `false` | Invalid-key line; `AGENTS.md` untouched; sources, index and config change unaffected | 0 |
| `AGENTS.md` markers damaged | Damaged-markers line; file untouched | 0 |
| `AGENTS.md` unreadable or not writable | Write-failed line; result otherwise unchanged | 0 |
| Section already matches | Unchanged line; file not written | 0 |
| No index exists (remove, or sync with nothing written) | No line; `AGENTS.md` untouched | 0 |

None of these changes a sync's result or the remove operation's result (FR-012, SC-004).

---

## 5. Side effects

- `speckit.knowledge.sync` may create, edit or delete the root `AGENTS.md`, only through `§ Agent Context Section`. It touches no other file at the project root.
- `speckit.knowledge.remove` may create, edit or delete the root `AGENTS.md`, only through step 3a and only when `knowledge-index.md` exists. It still does not run sync and does not touch `knowledge-index.md`.
- Neither command edits a byte of `AGENTS.md` outside the knowledge section (FR-006).
- Neither command reads or writes a source repository's `AGENTS.md`. The default exclusions already keep it out of the cache and the index.
