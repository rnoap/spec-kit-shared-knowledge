# Quickstart: Verify the AGENTS.md knowledge section

Behavior check for feature 010 (research R11). Run it in a scratch consumer project with the extension installed from this branch (`specify extension add <repo> --dev`) and two local sources, `docs-a` and `docs-b`, each a git repo with a few `.md` files.

Before each step, keep a copy of `AGENTS.md` (`cp AGENTS.md /tmp/a.md`, or note that it is absent), so you can compare with `diff`.

| # | Do | Expect |
|---|----|--------|
| 1 | No `AGENTS.md`. Run sync. | `✅ Created AGENTS.md with the shared knowledge section.` The file holds only the section from [contracts/agents-md-section.md](./contracts/agents-md-section.md), listing `docs-a` and `docs-b`. |
| 2 | Run sync again. | `ℹ️ … already up to date`. `diff` shows no change (SC-002). |
| 3 | Add text above and below the section, and a `<!-- SPECKIT START -->…<!-- SPECKIT END -->` block. Run sync. | Unchanged line. `diff` shows no change: other content is never touched (SC-003). |
| 4 | Fresh chat, no command, no file named: "What does docs-a say about <topic>?" Repeat 5 times. | At least 4 answers cite `docs-a › <path>` from the index (SC-001). |
| 5 | Run remove on `docs-b` with `--disable`. Do not sync. | `✅ Updated the shared knowledge section…`. Only the `docs-b` label line is gone. `knowledge-index.md` is byte-identical (FR-016). |
| 6 | Fresh chat: ask about `docs-b` 5 times. | No answer comes from `docs-b` index entries (SC-006). |
| 7 | Run remove on `docs-b` with `--enable`. | `docs-b` is listed again. A question about it is answered from the index, or the agent suggests `speckit.knowledge.sync`. |
| 8 | Remove `docs-a` and `docs-b`. | After the last one: `✅ Removed the shared knowledge section…`. The text from step 3 is intact. |
| 9 | Re-add both sources and sync. Set `agents_md: false` and sync. | The section is removed. Sync again: no `AGENTS.md` line, file untouched (FR-010). |
| 10 | Set `agents_md: "no"` and sync. | Invalid-key warning. `AGENTS.md` untouched. The index is still written (R1, SC-004). |
| 11 | Restore `agents_md: true`. Delete the `<!-- KNOWLEDGE END -->` line. Sync. | Damaged-markers warning. `AGENTS.md` untouched. Sync otherwise completes with exit 0 (FR-011). |
| 12 | Fix the markers. Re-label a source to ``a-->b`x``, then sync. | The label shows as ``- ``a-->b`x`` `` inside the section. The end marker is still the only marker line that closes it (FR-013). |
| 13 | `chmod a-w AGENTS.md` and change a label. Sync. | Write-failed warning. The index is updated. Exit 0 (FR-012). |
| 14 | Delete the index and the caches, keep `AGENTS.md`, and make both sources unreachable (rename their folders). Sync. | No `AGENTS.md` line. The section stays (R6). A fresh-chat question gets a suggestion to run `speckit.knowledge.sync`. |

Then run `bash .github/scripts/validate-extension.sh` with PyYAML available: rule 11 (identical validation blocks) and check 5 (command tokens) must pass.
