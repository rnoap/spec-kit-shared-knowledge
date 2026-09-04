# Quickstart — manual verification

**Feature**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md) | **Version under test**: 1.4.0

Constitution §III waives an automated test framework for agent prompts, so this walkthrough
**is** the quality gate. Every step maps to a Success Criterion; running all of them exercises
SC-001 … SC-010 plus the two gaps found in [research.md](research.md).

Run in a scratch consumer project, not in this repository.

---

## Setup

```sh
mkdir -p /tmp/kn-test && cd /tmp/kn-test
specify init . --ai copilot
specify extension add /Users/<you>/Walmart/repos/spec-kit-shared-knowledge --dev
```

**Gate 0 — install is clean** *(Constitution Quality Gate §1, §2)*

```sh
specify extension list
```

Expect: `Shared Knowledge (v1.4.0)`, `Commands: 5 | Hooks: 4`, and **no** "Config templates not
scaffolded" warning. Confirm `.specify/extensions/knowledge/knowledge-config.yml` exists.

> This gate is where the 1.2.0 blockers were caught. Do not skip it. In particular, confirm
> `provides.config[].name` still ends in `-config.yml` — spec-kit silently `rmtree`s config
> entries that do not follow that convention.

Prepare two local git repositories to use as sources, so the walkthrough needs no network:

```sh
git init /tmp/src-a && mkdir -p /tmp/src-a/specs && echo '# A' > /tmp/src-a/specs/shared.md
git -C /tmp/src-a add -A && git -C /tmp/src-a commit -qm init && git -C /tmp/src-a tag v1
echo '# A2' > /tmp/src-a/specs/shared.md
git -C /tmp/src-a commit -qam v2 && git -C /tmp/src-a tag v2

git init /tmp/src-b && mkdir -p /tmp/src-b/specs && echo '# B' > /tmp/src-b/specs/shared.md
git -C /tmp/src-b add -A && git -C /tmp/src-b commit -qm init
```

Note that both repositories contain `specs/shared.md` — that overlap is what steps 3 and 9 test.

---

## 1 — Remove purges configuration and cache in one command · **SC-001**

```sh
/speckit.knowledge.configure /tmp/src-a specs/
/speckit.knowledge.sync
ls .specify/extensions/knowledge/cache/          # → one slug directory

/speckit.knowledge.remove src-a
```

**Pass when**: the `sources` entry is gone from `knowledge-config.yml`, the slug directory is
gone from `cache/`, **no file was hand-edited**, and the command exited 0.

---

## 2 — Disable hides a source; re-enable costs no download · **SC-002**

```sh
/speckit.knowledge.configure /tmp/src-a specs/
/speckit.knowledge.sync
/speckit.knowledge.remove src-a --disable
/speckit.knowledge.sync
```

**Pass when**: `enabled: false` is written, `knowledge-index.md` contains **zero** items from
`src-a` (FR-008), and the cache directory **still exists** (FR-004).

```sh
touch /tmp/marker && /speckit.knowledge.remove src-a --enable && /speckit.knowledge.sync
```

**Pass when**: items return to the index and the cache directory's contents were **not
re-cloned** — verify by confirming the directory's mtime predates `/tmp/marker`.

---

## 3 — Two revisions of one repository stay separate and do not conflict · **SC-003**

```sh
/speckit.knowledge.configure /tmp/src-a --revision v1 specs/
/speckit.knowledge.configure /tmp/src-a --revision v2 specs/
/speckit.knowledge.sync
```

**Pass when**, all four:

1. Both sources are written with **distinct labels** (FR-028) — `configure` resolved the
   collision rather than merging or overwriting.
2. `cache/` holds **two** slug directories (FR-011).
3. One holds `# A`, the other `# A2` — no cross-contamination (FR-012).
4. `knowledge-index.md` reports **no conflict** for `specs/shared.md`, even though the path
   appears twice. Same repository identity ⇒ not a conflict (**FR-026**).

---

## 4 — A full SDD cycle performs one fetch per source · **SC-004**

Set a policy longer than the session:

```yaml
# knowledge-config.yml
max_cache_age: 4h
```

```sh
/speckit.knowledge.sync            # fetch #1
/speckit.knowledge.sync            # expect: skipped
/speckit.knowledge.sync            # expect: skipped
/speckit.knowledge.sync            # expect: skipped
```

**Pass when**: runs 2–4 report `⏭️ current` with an explicit "no network" note, and the cache
directory mtime is unchanged after run 1 (FR-018, FR-019).

Then confirm the escape hatch and its hook-unreachability:

```sh
/speckit.knowledge.sync --force    # expect: fetches despite the policy   (FR-021)
grep -A2 'before_specify' extension.yml   # expect: NO argument on the command  (FR-022)
```

---

## 5 — An unchanged project upgrades with zero observable difference · **SC-005**

Starting from a project configured under 1.3.0 with no `revision` and no `max_cache_age`:

```sh
ls .specify/extensions/knowledge/cache/          # record the slug names
specify extension add <repo-path> --dev --force  # upgrade to 1.4.0
/speckit.knowledge.sync
ls .specify/extensions/knowledge/cache/          # compare
```

**Pass when**: the slug names are **identical** — no re-download, no orphaned directory — and
the index contents and sync output match the pre-upgrade run (FR-024). This is the single most
important regression check in the walkthrough; the conditional hash input in
[research.md](research.md) § R2 exists entirely to make it pass.

---

## 6 — Every path exits 0 · **SC-006**

```sh
/speckit.knowledge.remove no-such-label            ; echo "exit=$?"   # FR-007
/speckit.knowledge.configure /tmp/src-a --revision does-not-exist
/speckit.knowledge.sync                            ; echo "exit=$?"   # FR-015
rm -rf .specify/extensions/knowledge/cache/*/.manifest.json
/speckit.knowledge.sync                            ; echo "exit=$?"   # corrupt cache
```

**Pass when**: every `exit=0`, and each failure produced a message naming what went wrong.
For the unresolvable revision, confirm the source is reported `unreachable` and falls back to an
intact cache if one exists (FR-015).

---

## 7 — Emptying the configuration deletes the index · **SC-007**

```sh
/speckit.knowledge.remove src-a
/speckit.knowledge.remove src-b
/speckit.knowledge.sync
```

**Pass when**: `cache/` is empty, `knowledge-index.md` **does not exist**, the output reports
the project as having no configured knowledge, **no Context Output Block is emitted**, and the
exit code is 0 (FR-031).

Repeat with `--disable` instead of removal — disabling every source must produce the same
"no configured knowledge" outcome, while the cache directories survive.

---

## 8 — Freshness never costs availability · **SC-008**

```sh
# with max_cache_age configured and caches populated
mv /tmp/src-a /tmp/src-a-moved      # make every source unreachable
/speckit.knowledge.sync
```

**Pass when**: cached knowledge is still surfaced, each source's staleness is reported, the
Context Output Block **is** emitted, and the exit code is 0 (FR-027). A freshness policy must
never leave the project with less available knowledge than it had before the policy was set.

---

## 9 — Labels are unique; an ambiguous URL is refused · **SC-009**

```sh
mkdir -p /tmp/x/payments /tmp/y/payments
git init /tmp/x/payments && git init /tmp/y/payments
/speckit.knowledge.configure /tmp/x/payments
/speckit.knowledge.configure /tmp/y/payments        # same derived label "payments"
```

**Pass when**: the collision is resolved before writing and the file contains **two distinct
labels** (FR-028).

```sh
/speckit.knowledge.remove /tmp/src-a                 # URL matching two pinned revisions
```

**Pass when**: the command lists both candidates, changes nothing, and exits 0 (FR-001).

---

## 10 — Invalid configuration is caught on read, from any origin · **SC-010**

Hand-edit `knowledge-config.yml` — this is the point, the value must never have passed through
`configure`:

```yaml
sources:
  - url: /tmp/src-a
    label: evil
    revision: "--upload-pack=touch /tmp/pwned"
  - url: /tmp/src-b
    label: good
    path_filter: specs/
```

```sh
/speckit.knowledge.sync ; echo "exit=$?"
test -e /tmp/pwned && echo "FAIL: argument injection succeeded"
```

**Pass when**: `evil` is skipped with a message naming the field and the value, `good`
synchronizes normally, `/tmp/pwned` **does not exist**, and the exit code is 0
(FR-029, FR-030).

Repeat with `path_filter: ../../etc` and `max_cache_age: 4 hours` — each must skip only its own
source.

---

## 11 — Orphaned caches are pruned · **gap G1**

```sh
/speckit.knowledge.configure /tmp/src-a --revision v1 specs/
/speckit.knowledge.sync
ls .specify/extensions/knowledge/cache/          # note the slug
# edit knowledge-config.yml: change revision v1 → v2
/speckit.knowledge.sync
ls .specify/extensions/knowledge/cache/
```

**Pass when**: exactly **one** directory remains — the new revision's — and the old one was
pruned with a reported line. Then confirm the guard rail:

```sh
/speckit.knowledge.remove src-a --disable && /speckit.knowledge.sync
ls .specify/extensions/knowledge/cache/
```

**Pass when**: the disabled source's cache **survives** pruning. Computing the prune set over
enabled sources only would delete exactly the caches FR-004 promises to keep.

---

## 12 — `status` labels agree with policy · **gap G2**

```sh
# a source with max_cache_age: 7d whose cache is 3 days old
/speckit.knowledge.status
```

**Pass when**: the source is labelled **fresh** (policy: 7d), not `cached` by the legacy 24-hour
heuristic, and the rendered output states which threshold it used. Then remove the policy and
confirm the 24-hour default returns, per FR-024.

---

## Pre-release checklist

*Constitution § Quality Gates — all five must pass before tagging `v1.4.0`.*

- [ ] §1 `specify extension add <path> --dev` completes with no errors and no scaffold warning
- [ ] §2 **five** commands registered and visible in `specify extension list`
- [ ] §3 `extension.yml` `version` is `1.4.0` and matches the intended git tag
- [ ] §4 `CHANGELOG.md` has a `## [1.4.0]` entry
- [ ] §5 `README.md` command table lists all five commands, matching `provides.commands`
- [ ] Constitution Quality Gate §2 amended from "four commands" to "five" (`docs:` commit)
- [ ] `git archive` of the tag contains only the publishable file set — the `.gitattributes`
      `export-ignore` rules added in 1.2.0 still hold
