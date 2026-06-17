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

<!-- SPECKIT START -->
For additional context about technologies to be used, project structure,
shell commands, and other important information, read the current plan
<!-- SPECKIT END -->
