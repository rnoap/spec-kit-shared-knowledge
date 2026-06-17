<h1 align="center">Shared Knowledge</h1>

<p align="center">
  <em>A spec-kit extension that injects architectural decisions, API contracts, and shared conventions from other Git repositories into your spec-kit workflow.</em>
</p>

<p align="center">
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-blue.svg"></a>
  <img alt="Spec Kit" src="https://img.shields.io/badge/spec--kit-%E2%89%A50.10.0-7d4cdb">
  <img alt="Status" src="https://img.shields.io/badge/status-v1.0.0-success">
</p>

## Overview

When working in a microservices or multi-repo environment, architectural decisions and API contracts are scattered across repositories. This extension lets you declare which repositories are "knowledge sources" for your project. During `/speckit-specify` and `/speckit-plan`, the assistant automatically loads and surfaces relevant knowledge from those sources — so the generated spec reflects the real contracts and decisions your team has already made.

**Key features**:
- Explicit opt-in: each project declares its own knowledge sources
- Git-native: clones repositories with sparse checkout (only the paths you need)
- Offline-friendly: cached knowledge is used when sources are unreachable
- Path-filtered: scope reads to `specs/`, `docs/decisions/`, or any subdirectory
- Conflict-aware: duplicate paths across sources are flagged, both versions surfaced

## Prerequisites

- `git >= 2.25` (sparse-checkout support required)
- spec-kit `>= 0.10.0`

## Installation

### Published (once available in the catalog)

```bash
specify extension add knowledge
```

Or from a local ZIP:

```bash
specify extension add knowledge --from /path/to/spec-kit-shared-knowledge.zip
```

### Local / Development Install

Install directly from a local checkout:

```bash
cd /path/to/your/spec-kit-project
specify extension add knowledge --dev /path/to/spec-kit-shared-knowledge
```

This copies the four command files, the manifest, and `config-template.yml`
into `.specify/extensions/knowledge/`, registers the extension, and
auto-registers the `before_specify` / `before_plan` hooks. After install,
add these two lines to your project's `.gitignore`:

```gitignore
.specify/extensions/knowledge/cache/
.specify/extensions/knowledge/knowledge-index.md
```

Then reload your editor / AI agent so it picks up the new commands.

## Quick Start

```bash
# 1. Add a knowledge source
/speckit-knowledge-configure https://github.com/your-org/payment-service specs/

# 2. Sync (fetch & cache)
/speckit-knowledge-sync

# 3. Use — next time you run /speckit-specify, cross-repo context is injected automatically
```

## Commands

### `/speckit-knowledge-configure [url] [path_filter]`

Initialize or edit the knowledge source configuration for the current project.

```
✅ knowledge.yml updated.

Configured sources:
  1. payment-service  →  https://github.com/your-org/payment-service  (path: specs/)
```

**Flags**: `--verbose` — print full YAML after write

### `/speckit-knowledge-sync`

Refresh the local cache for all configured, enabled knowledge sources.

```
🔄 Syncing cross-repo knowledge sources...

  payment-service    ✅ fresh    12 items  (synced 2026-06-11T14:00:00Z)

✅ Knowledge index updated: 12 items from 1 source.
   → .specify/extensions/knowledge/knowledge-index.md
```

**Flags**: `--verbose` — list all files loaded and items written to index

### `/speckit-knowledge-search <query>`

Browse and search the knowledge corpus without triggering a full spec workflow.

```
🔍 Search: "payment session"

Found 2 items across 1 source:

  📄 payment-service › specs/events/payment-completed.md
     Tags: specs, events, payment-completed
     Excerpt: "Payment completed event fired after successful charge..."
```

**Flags**: `--source <label>`, `--tag <tag>`, `--verbose`

### `/speckit-knowledge-status`

Display current state of all configured sources.

```
📊 Shared Knowledge Status

┌──────────────────┬──────────────┬────────┬───────┬────────────┐
│ Source           │ Reachability │ Status │ Items │ Cache Age  │
├──────────────────┼──────────────┼────────┼───────┼────────────┤
│ payment-service  │ ✅ reachable │ fresh  │ 12    │ 14 min     │
└──────────────────┴──────────────┴────────┴───────┴────────────┘
```

**Flags**: `--verbose` — list all cached file paths per source

## Integration with /speckit-specify and /speckit-plan

After installing the extension, consuming teams must perform two manual setup steps:

### Step 1: Register the sync hooks in `.specify/extensions.yml`

Add the following entries to your project's `.specify/extensions.yml`:

```yaml
hooks:
  before_specify:
    - extension: knowledge
      command: speckit.knowledge.sync
      optional: true
      prompt: "Sync cross-repo knowledge sources before specifying?"
      description: "Refresh knowledge cache before spec generation so context is current"

  before_plan:
    - extension: knowledge
      command: speckit.knowledge.sync
      optional: true
      prompt: "Sync cross-repo knowledge sources before planning?"
      description: "Refresh knowledge cache before implementation planning"
```

### Step 2: Amend your SKILL.md files

Add the following preamble to `.claude/skills/speckit-specify/SKILL.md` immediately before the `## Outline` section:

```markdown
**Cross-repo knowledge check**: If the file
`.specify/extensions/knowledge/knowledge-index.md` exists in the
project root, read it and all `.md` files it references from the cache
directories BEFORE drafting the specification. Surface relevant knowledge
from those files as context — cite the source (label + path) for each
piece of referenced information.
```

Add the equivalent preamble to `.claude/skills/speckit-plan/SKILL.md` immediately before the `## Outline` section:

```markdown
**Cross-repo knowledge check**: If the file
`.specify/extensions/knowledge/knowledge-index.md` exists in the
project root, read it and all `.md` files it references from the cache
directories BEFORE drafting the implementation plan. Surface relevant knowledge
from those files as context — cite the source (label + path) for each
piece of referenced information.
```

> **Why both steps are required**: The hooks (Step 1) trigger a sync so the cache is fresh. The SKILL.md amendments (Step 2) instruct the agent to read `knowledge-index.md` before generating output. Without Step 2, the sync runs correctly but context never flows into spec or plan output.

> **No-op when not configured**: If `.specify/extensions/knowledge/knowledge.yml` does not exist, all commands exit 0 with a "not configured" message. Projects without the extension are completely unaffected.

## Configuration Reference

See [`config-template.yml`](config-template.yml) for the full annotated configuration schema.

Key fields:
- `sources[*].url` — required; SSH or HTTPS Git URL
- `sources[*].label` — optional; defaults to `<host>/<org>/<repo>` derived from URL
- `sources[*].path_filter` — optional; scope to a subdirectory (e.g., `specs/`)
- `sources[*].enabled` — optional; default `true`; set `false` to skip without removing

## .gitignore Requirements

Add the following to your project's `.gitignore`:

```gitignore
# knowledge extension cache (local only; do not commit)
.specify/extensions/knowledge/cache/
.specify/extensions/knowledge/knowledge-index.md
```

The `knowledge.yml` config file **should** be committed — it declares your team's knowledge sources and is shared across all developers.

## Troubleshooting

**Source unreachable**: The command falls back to the existing cache and reports `⚠️ cached` with the last-sync timestamp and cache age. The command always exits 0.

**Corrupted cache**: If `.manifest.json` is absent or fails integrity checks, the cache directory is discarded and a fresh sync is attempted. If the fresh sync also fails, the source is marked `❌ unreachable`.

**More than 10 sources**: A soft warning is emitted before the sync loop. The command continues normally — the warning is informational only. Use `path_filter` to reduce per-source clone size.

**Context not appearing in spec output**: Verify both setup steps above are complete. Run `/speckit-knowledge-status` to confirm sources are reachable and `knowledge-index.md` exists.

## Contributing

Contributions are welcome. To propose a change:

1. Open an issue describing the bug or enhancement before sending a PR for non-trivial changes
2. Fork the repo and create a feature branch (`feat/<short-name>` or `fix/<short-name>`)
3. Update `CHANGELOG.md` under `[Unreleased]` with your change
4. Test the change with `specify extension add knowledge --dev /path/to/spec-kit-shared-knowledge` against a real spec-kit project
5. Open a pull request and reference the issue

For larger architectural changes, please file a discussion first. See `specs/` for the reverse-engineered specs that document the current behavior.

## License

[MIT](LICENSE) © Raúl Noa Pedroso
