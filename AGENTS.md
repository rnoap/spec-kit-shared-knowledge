<!-- CODE-GRAPH-PRIORITY START -->
## ⚠️ CRITICAL: Codebase Exploration

**ALWAYS explore the codebase with the code-review-graph MCP tools BEFORE `grep_search` / `file_search` / `read_file`.**

```
✅ mcp_code-review-g_semantic_search_nodes_tool  (provider=local, model=all-MiniLM-L6-v2)
✅ mcp_code-review-g_query_graph_tool            (callers / callees / imports / tests)
❌ grep_search as a first step to find a file, class, function or module
```

Before any `grep_search`, ask: "Could the knowledge graph answer this?" If yes, use the graph first. `grep_search` is only for exact literal strings the graph doesn't index. See the "code-review-graph MCP" section below for full details.

> If `code-review-graph` is not yet installed, run `/speckit-setup` first.
<!-- CODE-GRAPH-PRIORITY END -->

<!-- SPECKIT-HOOKS START -->
## ⛔ Spec-kit hooks — YOU execute the mandatory ones

`.specify/extensions.yml` sets `settings.auto_execute_hooks: true`. When a
spec-kit command finishes it lists its `after_*`/`before_*` hooks and may print
`EXECUTE_COMMAND: <cmd>`. **`EXECUTE_COMMAND` is a GUI signal for the Companion
UI — in AI-agent / YOLO mode there is no GUI, so YOU are the executor.**
Printing the command is not enough; a hook with `optional: false` that you do
not run is a missed step.

**Do this after every spec-kit command — works for any installed extension set:**

1. Read `hooks.after_<command>` (and any `before_<command>`) in
   `.specify/extensions.yml`. **Only the hooks listed there exist** — never
   assume a hook (e.g. a `companion.*` capture) that is not present in the file.
2. For each entry with `enabled: true` **and** `optional: false`:
   1. Resolve its command markdown: a `command:` of `speckit.<ext>.<name>`
      lives at `.specify/extensions/<ext>/commands/speckit.<ext>.<name>.md`.
   2. Read that file's **Execution** section and run exactly what it specifies,
      passing the current event (e.g. `after_plan`) where the script takes one.
3. For each entry with `optional: true` → offer it as a suggestion; run only if
   the user confirms.
4. Confirm in one line which mandatory hooks you executed.

**Exception: Companion pipeline commands.** `speckit.companion.specify`,
`speckit.companion.plan`, `speckit.companion.tasks` and
`speckit.companion.implement` (the dash form `speckit-companion-*` where the
project registers skills, and every step `speckit.companion.auto` runs) do the
`.specify/extensions.yml` pass themselves and skip Companion's own capture
hooks. Execute each `EXECUTE_COMMAND:` block such a command prints, once, offer
its optional blocks, and add no pass of your own. Never dispatch the capture
hooks around the outer Companion command. A stock gate invoked inside an
approved node hook still owns its own configured hook pass, including converge's
before/after capture hooks, once per gate invocation. These are not an extra
outer-pipeline pass. A second outer pass creates a second branch and rewrites
the recorded state.

**Worked example — `speckit.git.commit`** (the `git` extension is always installed):

> markdown: `.specify/extensions/git/commands/speckit.git.commit.md`
> runs:     `bash .specify/extensions/git/scripts/bash/auto-commit.sh <event>`

Any other extension (`companion`, company extensions, …) follows the same
resolve-then-run rule via its own command markdown. Do **not** hardcode another
extension's arguments here, and skip any extension that is not in
`.specify/extensions.yml` — the file is the single source of truth.

> **Why this matters:** hooks marked `optional: false` are non-negotiable steps
> (the auto-commit, and context/cost journaling when those extensions are
> installed). They were being skipped when the agent merely echoed
> `EXECUTE_COMMAND` instead of running the script, leaving mandatory work undone
> until a human noticed.
<!-- SPECKIT-HOOKS END -->

<!-- SPECKIT-TINY-SPECS START -->
## Tiny specs are numbered — `specs/tiny/NNN-<slug>.md`

Reserve the number before you create a tiny spec, including one written by hand.
Never invent, guess or reuse a number, and never use a PR number. The helper
ships with the spec-kit-walmart plugin; unless `CLAUDE_PLUGIN_ROOT` is set, set
`SPECKIT_RUNTIME` to `wibey` or `code_puppy` (yours, or whichever has the plugin
on this machine):

```bash
bash "${CLAUDE_PLUGIN_ROOT:-$HOME/.$SPECKIT_RUNTIME/plugins/spec-kit-walmart}/skills/speckit-setup/scripts/next-tiny-number.sh" --slug "fix receipt preview"
# -> specs/tiny/NNN-fix-receipt-preview.md
```

- The number is one above the highest `NNN-` prefix in this checkout, the other
  worktrees and every local and remote-tracking branch — offline and local.
- Before answering, the helper numbers any tiny spec still missing a prefix
  (oldest first: by when git first recorded it, else its `**Date**:` line, else
  by name) and rewrites links to it. Commit those renames with your change.
  `--check` instead of `--slug` previews them without touching anything.
- A tiny spec's number is its permanent ID: never renumber or reuse one.
- Plugin not installed: one above the highest `NNN-` prefix in `specs/tiny/`,
  zero-padded, after checking `git worktree list` for an uncommitted one
  elsewhere. Leave unnumbered files to `/speckit-update`.
<!-- SPECKIT-TINY-SPECS END -->

<!-- SPECKIT START -->
Active feature: **007-shell-safe-config**.

Status: in progress on branch `007-shell-safe-config`; not yet released.
The [recorded context](specs/007-shell-safe-config/.spec-context.json) is the
source of truth for current progress.

- [Specification](specs/007-shell-safe-config/shell-safe-config.spec.md)
- [Plan](specs/007-shell-safe-config/plan.md)
- [Research](specs/007-shell-safe-config/research.md)
- [Data model](specs/007-shell-safe-config/data-model.md)
- [Contracts](specs/007-shell-safe-config/contracts/commands.md)
- [Quickstart](specs/007-shell-safe-config/quickstart.md)
- [Tasks](specs/007-shell-safe-config/tasks.md)
<!-- SPECKIT END -->

<!-- CODE-GRAPH-GUIDE START -->
## MCP Tools: code-review-graph

Full detail for the "Codebase Exploration" directive near the top of this file.
Applies whenever a `.code-review-graph/` directory exists or the
`code-review-graph` MCP server is connected — otherwise ignore this section.

The graph is faster and cheaper than file scanning (measured 6.8x–8.2x fewer
tokens on review tasks) and answers structural questions — callers, dependents,
test coverage — that grep cannot answer at all.

### Use the graph first for

| Question | Tool | Instead of |
|----------|------|------------|
| Where is this symbol defined? | `semantic_search_nodes` | grepping for the name |
| What calls / is called by X? | `query_graph` (`callers_of`, `callees_of`) | reading every importer |
| What breaks if I change X? | `get_impact_radius` | tracing imports by hand |
| Which tests cover X? | `query_graph` (`tests_for`) | guessing from filenames |
| What changed and how risky? | `detect_changes` | reading the whole diff |
| Show me only the code I need to review | `get_review_context` | reading entire files |
| How is this codebase laid out? | `get_architecture_overview`, `list_communities` | directory spelunking |
| Any dead code / safe renames? | `refactor_tool` | manual audit |

Fall back to `Grep` / `Glob` / `Read` only for exact literal strings the graph
does not index (log messages, config values, comments), or when the graph has no
entry for the language in question.

### Notes

- Tool names are prefixed per assistant — e.g.
  `mcp__code-review-graph__query_graph_tool` (Claude Code) or
  `mcp_code-review-g_query_graph_tool` (Cursor / Wibey). Call whichever your
  runtime exposes.
- The graph updates incrementally as files change; a stale answer means it has
  not caught up yet, not that the graph is wrong.
- Semantic (fuzzy) matching in `semantic_search_nodes` needs the embedding index
  built once. Without it, that tool still works but matches lexically.
<!-- CODE-GRAPH-GUIDE END -->
