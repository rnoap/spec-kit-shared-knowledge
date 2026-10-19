# Implementation Plan: Shell-Safe Configuration

**Branch**: `007-shell-safe-config` | **Date**: 2026-10-19 | **Spec**: [shell-safe-config.spec.md](./shell-safe-config.spec.md)

**Scale note**: 13 files, though every runtime change is prose in the five command files. Two places need care. The validation block exists in three copies that must stay byte-identical. The local test script matches the snippets' placeholder text letter for letter, so it changes in the same commit as the snippets.

## Summary

The extension already defends against option injection twice: it refuses a value that begins with `-`, and puts `--` before every git operand. This feature adds the same pair for shell syntax. Validation refuses any `url` or `path_filter` value outside a fixed character list. The agent applies that rule itself, so a refused value never reaches a shell, not even to compute a slug or print a message. Every configuration placeholder in a bash block moves into single quotes, a value's own `'` is written `'\''`, and fetched file names travel only through shell variables. A new quote-context-aware static check fails the build when a placeholder is not effectively single-quoted; inert scanner fixtures guard against double-quoted and escaped lookalikes. The configuration schema becomes `1.1`, with a version gate before source use and a documented manual migration from `1.0`; manifest and index formats stay unchanged. The slug procedure gets explicit inputs and loses the comments that break it, and `AGENTS.md` points at this feature. Nothing new is installed: the change is Markdown in the commands, plus two development scripts.

## Project Structure

```text
commands/
├── speckit.knowledge.sync.md        # validation block: character rule + quoting rule; slug procedure; quoted snippets;
│                                    # Indexable Items: ./ starting points, `..` guard; items read via "$file";
│                                    # manifest and index via the file tool; prune guard (8a)
├── speckit.knowledge.status.md      # validation block (identical copy); per-source check before any slug; `invalid` row;
│                                    # quoted reachability checks
├── speckit.knowledge.configure.md   # validation block (identical copy); create/preserve schema 1.1; quoted arguments kept whole;
│                                    # `~/` detection; error rows; unsupported schema stops before source use
├── speckit.knowledge.remove.md      # refused target: entry only, cache left to prune; slug format check before purge
└── speckit.knowledge.search.md      # skip refused sources; read items with the file tool
README.md                            # trust model: two rows + one bullet; accepted characters; manual schema 1.0 -> 1.1 migration
config-template.yml                  # schema_version 1.1; accepted characters in the url and path_filter comments
CHANGELOG.md                         # entries under [Unreleased]
AGENTS.md                            # spec-kit section points at 007
.github/scripts/
├── validate-extension.sh            # check 12: effective single-quote contexts in bash blocks; inert scanner fixtures
└── test-sync-git.sh                 # literal placeholder filling with the quoting rule; hostile values; a path with a space;
                                     # slugs in sh, bash and zsh; hostile file names
.specify/memory/constitution.md      # Quality Gates item 12; version 1.4.0 with rationale
```

**Structure Decision**: Edit in place. The quoting rule sits inside § Configuration Validation Rules, next to the leading-`-` rule it extends. configure, sync and status therefore all carry it, and static check 11 keeps the three copies identical. remove and search reach the rules by reference, as they already reach the slug procedure. Only the command files and the docs ship; `.github/`, `.specify/` and `AGENTS.md` are excluded from the archive.

## Call paths

The block generator could not run (the installed companion lacks its parts files), so this is written as prose.

1. A command reads `knowledge-config.yml` and first checks for schema version `1.1`, in the agent's own reasoning. Any other or missing version produces an escaped migration/error diagnostic and exits 0 without using sources or writing configuration or caches. On `1.1`, the agent applies § Configuration Validation Rules to every source, with no shell involved. A refused source is reported as agent text and goes no further. configure creates and preserves `1.1`; users migrate a legacy file by backing it up and editing only its version scalar.
2. An accepted value enters a bash block only through a single-quoted placeholder: the slug procedure (`url='<url>'`), the clone and fetch tiers, sparse-checkout, Indexable Items, and status's reachability checks. `--` still precedes every git operand, and `with_timeout` hands its arguments on through `"$@"` without re-reading them.
3. Fetched file names leave `find` as text in `$items`, lose any line containing a `..` segment, and are read only as `"$file"` through redirection. The manifest and the index are written with the agent's file-writing tool.
4. sync's prune step, remove and search compute slugs for accepted sources only. While any source is refused, sync prunes nothing. Removing a refused source deletes its entry and leaves its cache to the next prune.

Three checks hold this in place: static check 12 (placeholders quoted), static check 11 (the three blocks identical), and the local behaviour test.

## Constitution Check

| Principle | Assessment |
| --- | --- |
| I. Extension-Package Discipline | PASS. No new runtime dependency and no shared file. The quoting rule lives inside the duplicated validation block, so each command stays self-contained. |
| II. Source-of-Truth Hierarchy | PASS. `config-template.yml` and the README state the accepted characters and configuration schema `1.1` the commands enforce. Narrowing accepted values is a breaking schema change under Principle I; the explicit bump and manual migration respect that rule without amending it ([research § 12](./research.md#12-configuration-schema-11-and-manual-migration)). Manifest and index formats stay unchanged. |
| III. Simplicity (YAGNI) | PASS. No new script or parser dependency. Check 12 is a quote-context scanner with inert fixtures in the existing validation script, and the behaviour test extends the existing local script. The runtime rule and schema gate themselves are Markdown, as §III requires. |
| IV. Conventional Commits | PASS. One commit per concern: `fix(security)`, `fix(sync)`, `docs(readme)`, `chore(ci)`, `test(sync)`, `docs(constitution)`, `chore(agents)`. |
| Naming Conventions | PASS. No new command, id or config key. |
| Code Boundaries | PASS. Only `.specify/memory/constitution.md` changes under `.specify/`. `AGENTS.md` stays hand-maintained, and the agent-context configuration is untouched. |
| Requirements & Compatibility | PASS. The floors are unchanged. Single quotes and `'\''` are POSIX, `sparse-checkout set --` works on git 2.25, and the test script keeps running on bash 3.2. |
| Quality Gates | PASS once amended. Checks 1 to 11 still hold, and check 11 compares the edited blocks. Check 12 is new, so the constitution lists it. |
| Governance | PASS. The amendment lands as a `docs:` commit with a rationale note, constitution 1.3.0 to 1.4.0. |

Re-checked after Phase 1 design: unchanged.
