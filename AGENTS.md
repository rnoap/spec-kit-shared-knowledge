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

<!-- SPECKIT START -->
For additional context about technologies to be used, project structure,
shell commands, and other important information, read the current plan:

- Active feature: `003-auto-integration`
- Plan: [specs/003-auto-integration/plan.md](specs/003-auto-integration/plan.md)
- Spec: [specs/003-auto-integration/spec.md](specs/003-auto-integration/spec.md)
- Research: [specs/003-auto-integration/research.md](specs/003-auto-integration/research.md)
- Data model: [specs/003-auto-integration/data-model.md](specs/003-auto-integration/data-model.md)
- Quickstart: [specs/003-auto-integration/quickstart.md](specs/003-auto-integration/quickstart.md)
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
