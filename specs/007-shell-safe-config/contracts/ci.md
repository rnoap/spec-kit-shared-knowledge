# Contract: Static check 12 and the behaviour test

**Feature**: [../shell-safe-config.spec.md](../shell-safe-config.spec.md) · **Plan**: [../plan.md](../plan.md) · **Research**: [../research.md](../research.md)

Two checks hold the quoting rule in place. Static check 12 runs on every pull request, inside the
existing `Static validation` check. The behaviour test stays local: the constitution keeps CI on
the package, not the prose, and running the shell steps in CI is out of scope.

---

## 1. Static check 12

`.github/scripts/validate-extension.sh`, under `Repository invariants`, after check 11 (FR-007). No
workflow, job or check name changes, so the `main` ruleset needs no edit.

### 1.1 What it reads

1. Every ```` ```bash ```` block in `commands/*.md`: from a line that is exactly ```` ```bash ````,
   trailing spaces allowed, to the next line that is exactly ```` ``` ````.
2. Every line in those blocks except comment lines, whose first non-blank character is `#`.
3. Each line with every pair of single quotes, and what they enclose, removed. An unpaired `'`
   removes nothing.
4. What is left, searched for placeholders: `<`, a letter, any letters, digits, `_` or `-`, then
   `>`.

### 1.2 Result

Passes when no placeholder but `<slug>` is left. Otherwise it fails, naming each line:

```text
  PASS  every configuration placeholder in a bash block is single-quoted
```

```text
  FAIL  configuration placeholders reach the shell unquoted (2 lines)
        commands/speckit.knowledge.status.md:131: <url>
        commands/speckit.knowledge.status.md:138: <expanded-path> <expanded-path>
        quote each one: '<name>' (007 FR-006)
```

- A double-quoted placeholder fails: `$(…)` and backticks still run inside double quotes.
- `<slug>` is exempt by exact name, and nothing else is. A placeholder added later is checked
  without anyone listing it ([research § 10](../research.md#10-static-check-12)).
- The check reads text, not shell grammar. A single-quoted segment inside double quotes counts as
  quoted, and inline code outside ```` ```bash ```` blocks is not read. Review covers both.

### 1.3 Baseline

On `b9ffaee` (v1.6.0) the check fails at 18 lines holding 23 placeholders, every one a site this
feature quotes:

| File | Lines | Steps |
| --- | --- | --- |
| `commands/speckit.knowledge.status.md` | 131, 138 | § 3 Check reachability: remote, local |
| `commands/speckit.knowledge.sync.md` | 284, 286 | § Indexable Items |
| `commands/speckit.knowledge.sync.md` | 574, 575, 585, 588, 608 | Cold path, Tiers 1 to 3 |
| `commands/speckit.knowledge.sync.md` | 641, 642, 659 | Cold path: local clone, sparse-checkout |
| `commands/speckit.knowledge.sync.md` | 677, 681, 695, 699, 709, 713 | Warm path: sparse-checkout, remote, local |

The slug procedure is not listed. It holds no placeholder today, reading `url` and `revision` from
the calling shell instead; after the change it holds two, both quoted.

Run the new check against this baseline before editing the commands: it must name exactly these
lines. After the change it passes, and re-seeding one unquoted placeholder fails it, naming that
file and line (SC-006).

---

## 2. Static check 11, unchanged

The three copies of § Configuration Validation Rules stay byte-identical, compared between the
lines `## Configuration Validation Rules` and `## Behavior`. This feature edits all three copies in
the same commit.

---

## 3. The behaviour test

`bash .github/scripts/test-sync-git.sh`: offline, writing only to a scratch directory, one `PASS` or
`FAIL` line per check, exit 0 when every check passes. Not run in CI.

### 3.1 Filling placeholders

`render()` fills the placeholders of [commands.md § 3.2](./commands.md#32-placeholders) by literal
substitution under the quoting rule: each value is copied byte for byte, with every `'` written
`'\''`. The `sed` it replaces read `|`, `&`, `\` and line breaks in a value as syntax, so three of
the eight seeds would have broken the substitution and passed for the wrong reason
([research § 11](../research.md#11-the-behaviour-test)).

### 3.2 Seeds

The eight hostile values of SC-001 and SC-004. `MARKER` is a fresh path in the scratch directory;
a seed ran if `MARKER` exists afterwards.

| # | Kind | Seed |
| --- | --- | --- |
| 1 | Command substitution | `$(touch MARKER)` |
| 2 | Backticks | `` `touch MARKER` `` |
| 3 | `;` | `x;touch MARKER` |
| 4 | `&&` | `x&&touch MARKER` |
| 5 | `\|` | `x\|touch MARKER` |
| 6 | Redirection | `x>MARKER` |
| 7 | Single-quote break-out | `x';touch MARKER;'` |
| 8 | Line break | `x`, a line feed, `touch MARKER` |

In a `url` the seed follows `https://example.invalid/`; in a local path it follows the scratch
directory and `/`. Every other placeholder takes the seed as it is.

### 3.3 Sections added

| Section | Runs | Passes when |
| --- | --- | --- |
| Hostile values, validation bypassed (SC-004) | Every seed in every configuration placeholder of: the slug procedure, Tiers 1 to 3, the local cold path, sparse-checkout cold and warm, the two warm paths, § Indexable Items, and status's two reachability checks. A recording `git` stand-in comes first on `PATH` | `MARKER` never exists, and the stand-in received each value as one argument, byte for byte |
| A local path containing a space (SC-005) | A source at `~/My Repos/kb` under the test's `HOME`: cold sync, warm sync, then status's local check | The cache holds the source's items, and the local check exits 0, which status reports as `✅ reachable (local)` |
| The slug procedure in three shells (SC-007) | The block, filled for each row of [commands.md § 4.3](./commands.md#43-reference-values), run as a script by `sh`, `bash` and `zsh` | stdout is the row's slug and a line feed, stderr is empty, exit is 0. A shell missing from `PATH` fails the section, naming it |
| Hostile file names (SC-004) | A source holding `$(touch pwned).md`, a file whose name begins with `-`, and a directory whose name holds a line break followed by `..`; then § Indexable Items, measurement and hashing through `"$file"` | No file named `pwned` appears in the scratch directory; the `-` file is measured and hashed; no item path has a `..` segment; no item's content comes from outside the cache |

search reads items with the agent's file-reading tool, so the search half of SC-004 stays a manual
check.

### 3.4 Linux run

The same script on git 2.25 with GNU `timeout`, where `sh` is dash. After `podman machine start`,
from the repository root, which must lie under `$HOME`:

```bash
podman run --rm -v "$PWD":/w -w /w docker.io/library/ubuntu:20.04 sh -c 'apt-get update -qq && apt-get install -yqq git perl procps zsh && bash .github/scripts/test-sync-git.sh'
```

---

## 4. Constitution

`.specify/memory/constitution.md` § Quality Gates gains item 12, and its version goes from 1.3.0 to
1.4.0, in a `docs:` commit with a rationale note. Item 12 reads:

> Every configuration placeholder in a ```` ```bash ```` block under `commands/` sits inside single
> quotes, so a configured value reaches the shell as one literal argument. `<slug>`, which the
> extension computes, is the only exemption.

The paragraph `Still manual, and honestly so` stays true: check 12 reads text and runs nothing.
