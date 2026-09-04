<h1 align="center">Shared Knowledge</h1>

<p align="center">
  <em>A spec-kit extension that injects architectural decisions, API contracts, and shared conventions from other Git repositories into your spec-kit workflow.</em>
</p>

<p align="center">
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-blue.svg"></a>
  <img alt="Spec Kit" src="https://img.shields.io/badge/spec--kit-%E2%89%A50.10.0-7d4cdb">
  <img alt="Status" src="https://img.shields.io/badge/status-v1.4.0-success">
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

Or from a release archive:

```bash
specify extension add knowledge --from https://github.com/rnoap/spec-kit-shared-knowledge/archive/refs/tags/v1.2.0.zip
```

### Local / Development Install

Install directly from a local checkout — the path is the positional argument:

```bash
cd /path/to/your/spec-kit-project
specify extension add /path/to/spec-kit-shared-knowledge --dev
```

This copies the four command files, the manifest, and `config-template.yml`
into `.specify/extensions/knowledge/`, scaffolds `knowledge-config.yml`,
registers the extension, and auto-registers the `before_specify` /
`before_plan` hooks. After install, add these two lines to your project's
`.gitignore`:

```gitignore
.specify/extensions/knowledge/cache/
.specify/extensions/knowledge/knowledge-index.md
```

Then reload your editor / AI agent so it picks up the new commands.

## Quick Start

```bash
# 1a. Add a knowledge source from a REMOTE repository (single folder filter)
/speckit.knowledge.configure https://github.com/your-org/payment-service specs/

# 1b. … or from a LOCAL repository on your machine
/speckit.knowledge.configure ~/repos/payment-service specs/

# 1c. … or with NO filter (indexes every .md file in the repo)
/speckit.knowledge.configure git@github.com:your-org/architecture-decisions.git

# 1d. … or scoped to MULTIPLE folders
/speckit.knowledge.configure ~/repos/shared-contracts specs/ docs/decisions/

# 2. Sync (fetch & cache)
/speckit.knowledge.sync

# 3. Use — next time you run /speckit-specify, cross-repo context is injected automatically
```

## Commands

| Command | What it does |
|---------|--------------|
| `/speckit.knowledge.configure` | Initialize or edit the knowledge source configuration |
| `/speckit.knowledge.sync` | Refresh the local cache for all configured, enabled sources |
| `/speckit.knowledge.search` | Browse and search the knowledge corpus |
| `/speckit.knowledge.status` | Show reachability, revision, last sync, item count, and cache age |
| `/speckit.knowledge.remove` | Remove, disable, or re-enable a configured source |

### `/speckit.knowledge.configure [url-or-path] [--revision <rev>] [path_filter ...]`

Initialize or edit the knowledge source configuration for the current project. Accepts:

- **A remote Git URL** — HTTPS (`https://github.com/your-org/your-repo`) or SSH (`git@github.com:your-org/your-repo`).
- **A local filesystem path to a Git repository** — use this when the repo is already cloned on your machine and you want to avoid network roundtrips, or when it lives on a private network. Both **absolute** paths and **`~`-prefixed** paths are supported (the tilde is expanded to `$HOME`).
- **An optional revision** — a branch, tag, or full commit SHA. See [Pinning a revision](#pinning-a-revision).
- **Zero or more path filters** after the URL/path. With zero filters every `.md` file in the repo is indexed; with one or more filters, indexing is restricted to those folders only.

**Examples**:

```bash
# Remote URL, single folder filter
/speckit.knowledge.configure https://github.com/your-org/payment-service specs/

# Local absolute path, single folder filter
/speckit.knowledge.configure /Users/devuser/repos/payment-service specs/

# Local path with tilde, NO filter (indexes every .md in the repo)
/speckit.knowledge.configure ~/repos/architecture-decisions

# Local path, MULTIPLE folder filters
/speckit.knowledge.configure ~/repos/shared-contracts specs/ docs/decisions/

# Pinned to a tag
/speckit.knowledge.configure https://github.com/your-org/payments --revision v2.4.1 specs/

# Same, using the @ shorthand (HTTPS and local paths only — not SSH)
/speckit.knowledge.configure https://github.com/your-org/payments@v2.4.1 specs/
```

**Output**:

```
✅ knowledge-config.yml updated.
✅ .gitignore updated with cache exclusion entries.

Configured sources:
  1. payment-service     →  https://github.com/your-org/payment-service  (path: specs/)
  2. architecture-decisions → ~/repos/architecture-decisions             (path: all .md files)
  3. shared-contracts    →  ~/repos/shared-contracts                     (paths: specs/, docs/decisions/)
```

**Flags**: `--verbose` — print full YAML after write

### `/speckit.knowledge.sync [--force]`

Refresh the local cache for all configured, enabled knowledge sources.

```
🔄 Syncing cross-repo knowledge sources...

  payment-service    ✅ fresh    12 items  (synced 2026-06-11T14:00:00Z)
  payments-v2        ⏭️  current  12 items  (cached 12m ago; policy 4h — no network)

✅ Knowledge index updated: 24 items from 2 sources.
   → .specify/extensions/knowledge/knowledge-index.md
```

**Flags**:
- `--verbose` — list all files loaded and items written to index
- `--force` — ignore the cache freshness policy and fetch every source

### `/speckit.knowledge.search <query>`

Browse and search the knowledge corpus without triggering a full spec workflow.

```
🔍 Search: "payment session"

Found 2 items across 1 source:

  📄 payment-service › specs/events/payment-completed.md
     Tags: specs, events, payment-completed
     Excerpt: "Payment completed event fired after successful charge..."
```

**Flags**: `--source <label>`, `--tag <tag>`, `--verbose`

### `/speckit.knowledge.status`

Display current state of all configured sources.

```
📊 Shared Knowledge Status

┌──────────────────┬──────────────┬──────────┬────────┬───────┬────────────┐
│ Source           │ Reachability │ Revision │ Status │ Items │ Cache Age  │
├──────────────────┼──────────────┼──────────┼────────┼───────┼────────────┤
│ payment-service  │ ✅ reachable │ default  │ fresh  │ 12    │ 14 min     │
│ payments-v2      │ ✅ reachable │ v2.4.1   │ fresh  │ 12    │ 3d         │
└──────────────────┴──────────────┴──────────┴────────┴───────┴────────────┘

Freshness policy: payments-v2 7d (per-source) · others 4h (project)
```

**Flags**: `--verbose` — list all cached file paths per source

### `/speckit.knowledge.remove <label> [--disable | --enable]`

Remove, disable, or re-enable a configured source. Named for its destructive mode,
but it owns the whole activation lifecycle — there is deliberately no second
command that also writes `enabled`.

```bash
# Delete the entry AND purge its cache
/speckit.knowledge.remove payments-v2

# Keep the entry and the cache; just stop consuming it
/speckit.knowledge.remove payments-v2 --disable

# Bring it back — no re-download, because the cache was kept
/speckit.knowledge.remove payments-v2 --enable

# No identifier: pick from a list of configured sources
/speckit.knowledge.remove
```

Takes a **label**, which is unique by construction. A URL is also accepted, but
only when it resolves to exactly one source — with revision pinning a URL can
match several, and the command lists the candidates rather than guessing:

```
❌ "https://github.com/org/payments" matches 2 configured sources:
     payments-v2   (revision: v2.4.1)
     payments-main (revision: main)
   Re-run with a label to disambiguate. Nothing was changed.
```

**Flags**: `--disable`, `--enable`, `--verbose`

## Source lifecycle

Before 1.4.0 the only way to stop consuming a source was to hand-edit YAML. Now:

| You want to | Use | Entry | Cache |
|-------------|-----|-------|-------|
| Stop consuming it permanently | `remove <label>` | deleted | **purged** |
| Pause it temporarily | `remove <label> --disable` | kept, `enabled: false` | **kept** |
| Bring a paused source back | `remove <label> --enable` | kept, `enabled: true` | reused |

**Prefer `--disable` over remove for a pause.** The cache is retained, so
re-enabling costs no download at all. Removal purges immediately rather than
deferring to a cleanup step — "remove" that leaves the bytes behind is the more
surprising reading.

When the last enabled source goes away, sync reports the project as unconfigured
and **deletes the knowledge index**. A stale index would let an agent keep citing
knowledge the project no longer declares — a silent failure that looks like
success.

## Pinning a revision

Each source may pin a `revision` — a branch, tag, or **full** commit SHA:

```yaml
sources:
  - url: https://github.com/org/payments
    label: payments-v2
    revision: v2.4.1
    path_filter: specs/
```

Omit it and the source tracks the remote's default revision, exactly as before.

- Two revisions of **one** repository can be configured side by side. They hold
  separate caches and cannot contaminate each other.
- Because a URL then no longer identifies one source, **every source carries a
  unique label**, enforced when it is added. The label is what `remove` takes.
- Overlapping file paths between two revisions of the same repository are **not**
  reported as conflicts. Conflicts are reported only between sources whose
  repository identity differs — identity ignores the access protocol, so HTTPS and
  SSH for the same repo are the same repo.
- **Abbreviated SHAs are not supported.** A 7-character prefix is not fetchable and
  is not stable — one that is unique today can become ambiguous as the repo grows.
- **SSH URLs** already contain `@`, so pass the revision with `--revision` rather
  than the `<url>@<rev>` shorthand.

**Known limitation.** A source configured as a local path is not identified with
the remote it was cloned from. If you configure both `~/repos/payments` and
`https://github.com/org/payments`, overlapping paths between them *are* reported
as conflicts. Reading the local clone's `origin` would fix this but adds a failure
mode and a trust question to a purely advisory report, so it is deliberately not
done.

## Cache freshness

Set `max_cache_age` and a sync will skip the network entirely when the cached
content is still current:

```yaml
max_cache_age: 4h        # project-wide

sources:
  - url: https://github.com/org/payments
    label: payments-v2
    max_cache_age: 7d    # overrides the project value for this source
```

Format is `<N><unit>` with unit `m`, `h`, or `d` — `30m`, `4h`, `7d`.

**This is what makes the four automatic hooks affordable.** Without a policy, one
feature cycle (specify → clarify → plan → tasks) refetches every source four
times. With `4h` set and the cycle finished inside that window, it fetches once.

- **Omitted is the default**, and means no policy: every sync fetches, byte-identically to 1.3.0.
- A skipped source is reported as `⏭️ current`, distinct from `fresh`, so you can see no network access happened.
- `--force` ignores the policy. It is **unreachable from an automatic trigger** — the hook entries declare no arguments — so hook-driven syncs always respect the policy.
- **It is a hint, not an expiry.** An over-age cache is still served when its source cannot be reached. Setting a policy never leaves you with less knowledge than you had without one.

## Integration with the spec-kit lifecycle

The hooks declared in [`extension.yml`](extension.yml) are **auto-registered by spec-kit** when the extension is installed via `specify extension add` — no manual edits to `.specify/extensions.yml` are required. See the [spec-kit Extension Development Guide](https://github.com/github/spec-kit/blob/main/extensions/EXTENSION-DEVELOPMENT-GUIDE.md) for the underlying mechanism.

| Hook | Runs before | Why |
|------|-------------|-----|
| `before_specify` | `/speckit-specify` | Spec drafting reflects current contracts |
| `before_clarify` | `/speckit-clarify` | Ambiguities resolved against real decisions |
| `before_plan` | `/speckit-plan` | Planning sees the current architecture |
| `before_tasks` | `/speckit-tasks` | Task breakdown reflects current contracts |

All four are **optional**, so spec-kit prompts before each sync and you can decline. There is no cache TTL yet — every accepted hook refetches — so decline the ones you don't need in a given session.

The AI agent's knowledge-reading behavior is driven by the **Context Output block** emitted at the end of every successful or degraded sync (see [`commands/speckit.knowledge.sync.md`](commands/speckit.knowledge.sync.md) § "10. Emit Context Output for AI Agents block").

> **Migration note**: If you previously followed the prior README and added `knowledge` entries to your project's `.specify/extensions.yml`, you may safely remove them — auto-registration handles them now.

> **No-op when not configured**: If `.specify/extensions/knowledge/knowledge-config.yml` does not exist, all commands exit 0 with a "not configured" message. Projects without the extension are completely unaffected.

## Configuration Reference

See [`config-template.yml`](config-template.yml) for the full annotated configuration schema.

Key fields per source entry:

- `sources[*].url` — **required**. One of:
  - HTTPS Git URL: `https://github.com/your-org/your-repo`
  - SSH Git URL: `git@github.com:your-org/your-repo`
  - **Local absolute path** to a Git repository: `/Users/devuser/repos/your-repo`
  - **Local tilde path** (expanded to `$HOME`): `~/repos/your-repo`
- `sources[*].label` — optional; human-readable name used for attribution. Defaults: for remote URLs, `<host>/<org>/<repo>` derived from the URL; for local paths, the last path component (e.g. `~/repos/payment-service` → `payment-service`).
- `sources[*].path_filter` — optional. Three forms:
  - **Omitted** → every `.md` file in the repo is indexed.
  - **Single string** → `path_filter: specs/` indexes only files under `specs/`.
  - **YAML list** → `path_filter: [specs/, docs/decisions/]` indexes those two trees and nothing else.
- `sources[*].enabled` — optional; default `true`; set `false` to skip a source without removing it from the file.

## .gitignore

The `/speckit.knowledge.configure` command **automatically adds** the required cache exclusion entries to your project's `.gitignore` when you first configure a source — no manual step needed.

If you need to add them by hand (e.g. before running configure for the first time):

```gitignore
# knowledge extension cache (local only; do not commit)
.specify/extensions/knowledge/cache/
.specify/extensions/knowledge/knowledge-index.md
```

The `knowledge-config.yml` config file **should** be committed — it declares your team's knowledge sources and is shared across all developers.

## Troubleshooting

**Source unreachable**: The command falls back to the existing cache and reports `⚠️ cached` with the last-sync timestamp and cache age. The command always exits 0.

**Corrupted cache**: If `.manifest.json` is absent or fails integrity checks, the cache directory is discarded and a fresh sync is attempted. If the fresh sync also fails, the source is marked `❌ unreachable`.

**More than 10 sources**: A soft warning is emitted before the sync loop. The command continues normally — the warning is informational only. Use `path_filter` to reduce per-source clone size.

**Context not appearing in spec output**: Verify both setup steps above are complete. Run `/speckit.knowledge.status` to confirm sources are reachable and `knowledge-index.md` exists.

## Contributing

Contributions are welcome. To propose a change:

1. Open an issue describing the bug or enhancement before sending a PR for non-trivial changes
2. Fork the repo and create a feature branch (`feat/<short-name>` or `fix/<short-name>`)
3. Update `CHANGELOG.md` under `[Unreleased]` with your change
4. Test the change with `specify extension add /path/to/spec-kit-shared-knowledge --dev` against a real spec-kit project
5. Open a pull request and reference the issue

For larger architectural changes, please file a discussion first. See `specs/` for the reverse-engineered specs that document the current behavior.

## License

[MIT](LICENSE) © Raúl Noa Pedroso
