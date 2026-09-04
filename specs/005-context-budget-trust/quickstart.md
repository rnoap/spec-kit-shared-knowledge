# Phase 1 — Quickstart: Manual Verification

**Feature**: [spec.md](spec.md) · **Plan**: [plan.md](plan.md) · **Contracts**: [config schema](contracts/knowledge-config.schema.md) · [commands](contracts/commands.md)

Constitution §III waives an automated test framework for agent prompts — a model interprets them
at runtime, so nothing mechanical can assert what a command *does*. CI guards the package; this
walkthrough is the only check on behaviour.

Every one of SC-001 … SC-020 is exercised below.

---

## Setup

```bash
# A clean consumer project
mkdir -p /tmp/kb-005 && cd /tmp/kb-005 && git init
specify init --here --ai copilot
specify extension add /path/to/spec-kit-shared-knowledge --dev
```

Build three source repositories with known, asymmetric contents so allocation is observable:

```bash
# base corpus, before the two additions below
# big-docs:  300 files, ~6kb each  (~1.8mb)  — will be trimmed hard
# adr-repo:   55 files, ~3kb each  (~165kb)  — trimmed lightly
# tiny-repo:   4 files, ~2kb each  (~8kb)    — fits entirely, releases its share
for r in big-docs adr-repo tiny-repo; do
  mkdir -p /tmp/src/$r && (cd /tmp/src/$r && git init)
done
```

Add one oversized file and one deliberately shared path:

```bash
# exactly 2.4 MiB (2516582 bytes) — larger than the whole size ceiling used below.
# `yes | head -c` rather than `base64`, which inflates its input by 4/3 and would
# produce a file 1.37x the size requested.
yes x | head -c 2516582 > /tmp/src/big-docs/huge.md

# same relative path in two DIFFERENT repositories → a real conflict
mkdir -p /tmp/src/big-docs/events /tmp/src/adr-repo/events
echo "payment completed, v1" > /tmp/src/big-docs/events/payment-completed.md
echo "payment completed, v2" > /tmp/src/adr-repo/events/payment-completed.md
```

**Corpus after setup**: big-docs 302 + adr-repo 56 + tiny-repo 4 = **362 items**, ≈ **4.4 mb**
(1.8 mb + 165 kb + 8 kb + 2.4 mb). Every figure quoted below derives from these.

Two shell helpers are used throughout. The index carries a generation timestamp that changes on
every run, and its links embed a cache slug derived from each machine's own source paths — so a
raw `diff` of two indexes is **never** empty, even when both selected exactly the same items.
Compare content, not bytes:

```bash
# same-machine: ignore the two generated timestamp lines
idx()   { grep -v 'generated_at=\|^> Generated:' "$1"; }

# cross-machine: compare only the indexed item paths, stripping the local cache slug
items() { grep -o '](cache/[^)]*)' "$1" | sed 's|](cache/[^/]*/||; s|)$||' | sort; }
```

Commit all three, then configure and sync **with no budget** to establish a baseline.

---

## Step 0 — Baseline (SC-004)

```bash
/speckit.knowledge.configure /tmp/src/big-docs
/speckit.knowledge.configure /tmp/src/adr-repo
/speckit.knowledge.configure /tmp/src/tiny-repo
/speckit.knowledge.sync
cp .specify/extensions/knowledge/knowledge-index.md /tmp/baseline-index.md
```

**Expect**: all **362** items indexed. No withholding output. Existing configuration valid with no
edits.

✅ **SC-004** — an upgraded, unbudgeted project behaves exactly as before.

---

## Step 1 — Advisory warning (SC-015, SC-017)

The baseline corpus is already past 200 items / 2 mb.

**Expect** on that same sync:

```
⚠️  This project's knowledge corpus is 362 items / 4.4mb, past the advisory
    threshold of 200 items / 2mb. ...
```

```bash
diff <(idx /tmp/baseline-index.md) <(idx .specify/extensions/knowledge/knowledge-index.md)
# must be empty
```

✅ **SC-015** — the warning changes nothing it reports on.
✅ **SC-017** — both the measured value and the threshold are named.

---

## Step 2 — Non-binding budget (SC-011)

```yaml
max_items: 1000
max_bytes: 10mb
```

```bash
/speckit.knowledge.sync
diff <(idx /tmp/baseline-index.md) <(idx .specify/extensions/knowledge/knowledge-index.md)
# must be empty
```

**Expect**: no withholding lines, no `⚠️ Partial` in the index, no `withheld_*` header fields.

✅ **SC-011** — a budget the corpus does not exceed is invisible.

---

## Step 3 — Binding budget (SC-001, SC-005, SC-012)

```yaml
max_items: 120
max_bytes: 1mb
```

```bash
/speckit.knowledge.sync
grep -c '^- \[' .specify/extensions/knowledge/knowledge-index.md    # <= 120
```

**Expect** by progressive fill: `tiny-repo` takes all 4 and releases its remaining share;
`adr-repo` takes all 56 and releases 2; `big-docs` takes the remaining 60. No source is starved —
120 ≥ 3 sources, so FR-008a does not apply.

Re-run against a policy-fresh cache and against an unreachable source (rename `/tmp/src/big-docs`
temporarily). The ceiling must hold on all three provenance paths.

✅ **SC-001** — neither ceiling is exceeded.
✅ **SC-005** — every source with items contributes at least one.
✅ **SC-012** — the budget holds regardless of how content was obtained.

---

## Step 4 — Determinism (SC-002, SC-016)

```bash
cp .specify/extensions/knowledge/knowledge-index.md /tmp/run-a.md
/speckit.knowledge.sync
diff <(idx /tmp/run-a.md) <(idx .specify/extensions/knowledge/knowledge-index.md)
# must be empty
```

Then repeat the whole setup in a second directory and compare the **item lists**, not the files —
the link targets embed a cache slug derived from each machine's own source paths, so the raw
indexes legitimately differ:

```bash
diff <(items /tmp/run-a.md) <(items /tmp/machine-b/.specify/extensions/knowledge/knowledge-index.md)
# must be empty
```

Before running, compute the expected set **by hand** from § 2.2 of
[data-model.md](data-model.md) and compare. With `max_items: 120` and needs of 301 / 56 / 4
(`huge.md` already removed as oversized): share `⌊120/3⌋ = 40`, tiny-repo takes 4 and releases 36,
`⌊116/2⌋ = 58`, adr-repo takes all 56 and releases 2, then big-docs takes the remaining 60.
**60 + 56 + 4 = 120.**

✅ **SC-002** — identical config plus identical content selects an identical item set.
✅ **SC-016** — the outcome is predictable on paper.

---

## Step 5 — Withholding report (SC-003, SC-020)

**Expect** in default output: per-source injected-vs-total counts and sizes, the limit applied,
and nothing else per item. Then:

```bash
/speckit.knowledge.sync --verbose    # lists every withheld path
grep -c 'withheld_items' .specify/extensions/knowledge/knowledge-index.md   # header carries counts
grep 'events/refund-issued' .specify/extensions/knowledge/knowledge-index.md # MUST NOT match
```

The `⚠️ Partial` line must appear in the index, and the partial-corpus line in the Context Output
block.

✅ **SC-003** — counts obtainable from output alone; the statement reaches all three surfaces.
✅ **SC-020** — identities available on demand; default output stays short; the index names none.

---

## Step 6 — Oversized item (SC-008, part 1)

`huge.md` is exactly 2.4 MiB against a 1 mb ceiling.

**Expect**:

```
⚠️  Withheld: big-docs › huge.md (2.4mb) exceeds the 1mb size ceiling on its own;
    excluded without consuming the budget.
```

It must not consume or block the budget available to other items, and the exit code must be 0.

✅ **SC-008** — a budget smaller than a single item is survivable and explained.

---

## Step 7 — Conflict atomicity (SC-007, SC-018)

`events/payment-completed.md` exists in `big-docs` and `adr-repo` — different repository
identities, so a real conflict.

Tighten `max_items` until one side would fall outside its source's allocation.

**Expect**: *neither* version in the index, reported as one conflict withdrawal — not two
unrelated exclusions. The freed capacity must **not** be given to other items, so the index is one
item shorter than the ceiling allows.

✅ **SC-007** — both present or both absent; never a silent winner.
✅ **SC-018** — freed capacity is not reallocated, so the result is pass-count independent.

---

## Step 8 — Starved sources (SC-005 boundary, SC-008 part 2)

```yaml
max_items: 2      # below the source count of 3
```

**Expect**: one source contributes nothing and is **named**, with the reason stated. Exit 0.

✅ **SC-008** — a budget below the source count is survivable and explained.

---

## Step 9 — Clamp vs. skip (SC-019)

```yaml
max_items: 120
sources:
  - url: /tmp/src/adr-repo
    max_items: 400        # exceeds the project ceiling
```

**Expect**: clamped to 120, clamp reported, **source still contributes**. Then replace with
`max_items: banana`.

**Expect**: that source skipped with the field and value named; the other two sync normally.
Then set a malformed *project-wide* value.

**Expect**: reported and ignored; per-source values still apply; nothing is stripped.

✅ **SC-019** — only an uninterpretable value costs a source its place.
✅ **SC-008** — malformed values arriving by hand-edit are survivable.

---

## Step 10 — Search reaches withheld items (SC-006)

Pick a path confirmed **absent** from the index in Step 5.

```bash
/speckit.knowledge.search refund-issued
```

**Expect**: found. This is the check that FR-035 actually landed — if search still reads
`knowledge-index.md`, this step fails and the "un-injected, not unavailable" guarantee is false.

```bash
ls .specify/extensions/knowledge/cache/*/    # withheld files still on disk
```

✅ **SC-006** — the search result set is unaffected by the budget.

---

## Step 11 — Status (SC-013)

```bash
/speckit.knowledge.status
```

**Expect**: a Budget column showing contributed-of-total per source, and the limit applied to
each named — share, per-source value, or none.

✅ **SC-013** — a reported contribution is never unexplained.

---

## Step 12 — Trust model (SC-009, SC-010, SC-014)

Read the README's trust model section **without** consulting the source.

Answer: (a) what does merging a one-line config change cause on my machine? (b) what is and is not
executed? (c) name one exposure the extension does not defend against.

```bash
grep -n 'symlink\|symbolic link' README.md    # exposure 3 must be present
grep -n 'Trust' config-template.yml           # template must point at it (FR-030)
```

Then audit each named defense against `commands/speckit.knowledge.sync.md`. Every one must be
real; every exposure named as undefended must have no defense claimed.

✅ **SC-009** — all three questions answerable from the README alone.
✅ **SC-010** — reviewer checks are stated, not inferred.
✅ **SC-014** — no defense is claimed that the extension does not implement.

---

## Step 13 — Packaging gates

```bash
.github/scripts/validate-extension.sh
```

Must pass, in particular:

- **§11** — the Validation Rules block is byte-identical across `configure`, `sync`, and `status`.
  Both new rows must land in all three copies or this fails.
- **§6** — README badge matches `extension.yml` version (`1.5.0`).
- **§7** — CHANGELOG has a `[1.5.0]` entry.
- **§10** — no hook declares arguments.

Then a real install into a clean project: five commands registered, config scaffolded, four hooks
auto-registered.

---

## Coverage

| SC | Step | | SC | Step |
|----|------|-|----|------|
| SC-001 | 3 | | SC-011 | 2 |
| SC-002 | 4 | | SC-012 | 3 |
| SC-003 | 5 | | SC-013 | 11 |
| SC-004 | 0 | | SC-014 | 12 |
| SC-005 | 3, 8 | | SC-015 | 1 |
| SC-006 | 10 | | SC-016 | 4 |
| SC-007 | 7 | | SC-017 | 1 |
| SC-008 | 6, 8, 9 | | SC-018 | 7 |
| SC-009 | 12 | | SC-019 | 9 |
| SC-010 | 12 | | SC-020 | 5 |

**Exit code must be 0 at every step above**, including 6, 8, and 9 (FR-022).
