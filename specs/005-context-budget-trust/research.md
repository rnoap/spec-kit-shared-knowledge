# Phase 0 — Research: Context Budget & Trust Model

**Feature**: [spec.md](spec.md) · **Plan**: [plan.md](plan.md) · **Date**: 2026-09-04

Eight unknowns were extracted from the plan's Technical Context. Each is resolved below with
the decision, its rationale, and the alternatives that were rejected.

Two of them (R5, R8) turned up behaviour that nothing in the specification authorised. Both
have been **promoted to requirements** rather than left as implementation habit, following the
precedent set by feature 004.

---

## R1 — How is item size measured portably?

**Question**: The size ceiling is measured over file contents (FR-010). What tool reports a
file's byte count identically on GNU and BSD systems, given that `extension.yml` declares no
interpreter beyond `git`?

**Decision**: `wc -c < <file>`, summed by the agent.

**Rationale**: `wc -c` is POSIX and reports **bytes**, not blocks, on every platform. Reading
via redirection (`wc -c < file`) rather than as an argument (`wc -c file`) suppresses the
filename from the output, which removes the only formatting difference between implementations
— GNU pads differently from BSD.

**Alternatives rejected**:

- `du` — reports **disk blocks**, and its default unit differs between GNU (1 KiB) and BSD
  (512 B). Two developers would measure the same corpus differently, breaking FR-007's
  determinism requirement outright.
- `stat` — the format flag is `-c%s` on GNU and `-f%z` on BSD. This is the same portability
  trap already documented in feature 004 § R4 for `date`, and rejected for the same reason.
- `ls -l` + field extraction — locale-dependent column layout.

**Consequence**: size is measured in **bytes of file content as stored**, which is what the
agent will actually read. No encoding normalisation is applied, and none is needed: the files
are markdown read verbatim.

---

## R2 — What is the size value's format, and how is it converted to bytes?

**Question**: FR-001 requires a maximum total size. The Assumptions require "a human-readable
value with an explicit unit", following the `max_cache_age` precedent.

**Decision**: `^[0-9]+(kb|mb)$` — `512kb`, `2mb`. Converted with integer arithmetic:
`Nkb → N × 1024`, `Nmb → N × 1048576`.

**Rationale**: This is the exact shape of the existing `max_cache_age` rule
(`^[0-9]+[mhd]$`), so the configuration file carries one convention rather than two. Binary
units are used because the measurement is a byte count; the two-letter suffix keeps `mb`
unambiguous against `m` for minutes, which already means something else in the same file.

**Alternatives rejected**:

- A bare integer byte count (`2097152`) — unreadable in a committed file, and the unit becomes
  a thing you have to remember rather than a thing you can see.
- Single-letter suffixes (`2m`) — collides with `max_cache_age`'s `m` for minutes. A reader
  scanning the file would have to know which key they were looking at to know what `2m` meant.
- Decimal units (`kB` = 1000) — invites an argument about which convention applies, for no
  benefit at this precision.

---

## R3 — How is the fair-share allocation computed deterministically?

**Question**: FR-007a requires equal shares across sources with unused share released to the
others, and FR-007b requires a user to be able to reproduce the result on paper. Constitution
§III forbids adding a script, so the rule must be simple enough to state as prose an agent
follows.

**Decision**: Progressive fill (water-filling), run **independently on each dimension**, with
each source then taking the longest path-ordered prefix of its items that fits within *both*
of its resulting shares.

Per dimension, with `B` = the ceiling and `S` = the set of enabled sources that have items:

```text
1. share = floor(B / |S|)
2. Any source whose total need is <= share is satisfied in full.
   Subtract its need from B, remove it from S, and repeat from step 1.
3. When no source is satisfied in a pass, every source left in S receives `share`.
4. The remainder (B - share × |S|) is distributed one unit each to the sources
   remaining in S, in ascending label order.
```

**Rationale**:

- It terminates in at most `|S|` passes, because each pass either removes a source or exits.
- It is fully determined by the configuration and the corpus — no filesystem order, no sync
  order, no configuration order. Step 4 uses **label** order, and labels are unique by
  construction (feature 004, FR-028), so the tiebreak can never be ambiguous.
- A user can execute it by hand from their own repository contents, which is what FR-007b asks
  for.
- Running the two dimensions independently and intersecting the results guarantees both global
  ceilings hold, because the sum of shares never exceeds the ceiling on either dimension.

**Accepted cost**: intersecting two independently-computed shares can leave capacity unused —
a source may be item-capped well below its byte share, and that byte share is not re-offered to
others. This is deliberate and is the same trade the specification already accepts for conflict
withdrawals (FR-033): a second redistribution pass would recover the slack but would make the
outcome depend on the pass count, which is precisely what FR-007b forbids.

**Alternatives rejected**:

- **Proportional allocation** (share ∝ source size) — gives the largest repository the most
  room, which inverts the intent. A sprawling wiki would crowd out a small, dense decisions
  repo, and FR-008 exists to prevent exactly that.
- **Strict round-robin, one item at a time** — produces the same result as progressive fill in
  the common case but is far harder to execute by hand over a thousand files, failing FR-007b.
- **Joint optimisation across both dimensions** — a knapsack problem. Better packing, not
  reproducible on paper, and non-obvious to explain in a README.

---

## R4 — Where do the budget keys live, and what validates them?

**Question**: FR-019 requires read-time validation for the new fields, extending the existing
rule block.

**Decision**: Two keys, `max_items` and `max_bytes`, valid at the top level and inside each
`sources[]` entry — the same two positions `max_cache_age` already occupies. Two rows are added
to the Configuration Validation Rules table:

| Field | Rule |
|-------|------|
| `max_items` (top level and per source) | Optional. Matches `^[0-9]+$`, and must be `>= 1`. |
| `max_bytes` (top level and per source) | Optional. Matches `^[0-9]+(kb\|mb)$` — `512kb`, `2mb`. |

**Rationale**: `0` is rejected rather than treated as "withhold everything". A budget of zero is
almost certainly a mistake, and honouring it literally would silently strip the entire corpus —
the failure mode the whole reporting half of this feature exists to prevent. Rejecting it routes
the value through FR-020 (skip the source, name the field) or FR-021 (project-level: report and
ignore), both of which are loud.

**Critical constraint**: that rules table is **duplicated verbatim** across
`speckit.knowledge.configure.md`, `speckit.knowledge.sync.md`, and
`speckit.knowledge.status.md`, and Constitution Quality Gate §11 asserts the three copies are
byte-identical on every pull request. Both new rows must be added to all three copies in the
same change, or CI fails.

**Alternatives rejected**: a nested `budget:` block (`budget: {max_items: …}`). Cleaner in
isolation, but `max_cache_age` is already flat at both levels, and mixing flat and nested
scoping in one file is worse than a slightly longer flat list.

---

## R5 — Where in the sync pipeline does the budget apply? *(promoted to FR-035)*

**Question**: The budget must run after conflict detection (FR-033 needs to know which paths are
conflict pairs) and before the index is written. What else does that ordering affect?

**Decision**: A new step between conflict detection and index writing. The per-source
`.manifest.json` files are written **before** it and therefore keep the **complete** item list.

**This exposed a gap that would have made FR-017 unsatisfiable.** `speckit.knowledge.search`
loads `knowledge-index.md` and iterates *"for each item in the index"*. Once the index is
budgeted, a withheld item is absent from the only file search reads — so it could not be found,
directly contradicting FR-017 and SC-006, and collapsing the distinction between "un-injected"
and "unavailable" that the entire Q3 clarification rests on.

The fix is to change search's source of truth from the index to the per-source manifests, which
already hold every item and are written before the budget is applied. **Promoted to FR-035**,
because a requirement guaranteeing withheld items stay findable must be backed by something that
actually makes them findable.

This also supplies FR-034's verbose withheld list at no extra cost: *withheld = manifest items −
indexed items*, both already on disk.

**Alternatives rejected**:

- Applying the budget before manifests are written — would bound the cache, which FR-012a
  forbids.
- Having search rescan the cache directory — duplicates what the manifest already records and
  loses the integrity guarantee the manifest carries.
- Recording withheld paths in the index for search to read — forbidden by FR-014, and for a good
  reason: the index is the one document the agent is told to read in full.

---

## R6 — What are the advisory threshold values?

**Question**: FR-032a requires one fixed built-in threshold per dimension, both named in the
warning.

**Decision**: **200 items** and **2 mb**.

**Rationale**: markdown documents of the kind this extension indexes — specs, decision records,
contracts — run roughly 4–8 KB each. 200 items at ~6 KB averages ≈ 1.2 MB, so the two thresholds
describe approximately the same wall from two directions and neither fires long before the other.
2 MB of markdown is on the order of 500k tokens, comfortably beyond what any current agent holds
alongside a real task. Below these figures, "read every file" is still a defensible instruction;
above them it is not.

**Consequence**: the numbers are a calibration, not a contract. FR-032a fixes their *properties*
— built-in, one per dimension, named in the output — so they can be re-tuned in a later release
without a schema change or a specification amendment.

**Alternatives rejected**: deriving the threshold from a declared agent context size. It varies
per agent and per model revision, would need a new configuration key to express, and would age
badly in a file that has to stay correct across model generations.

---

## R7 — Where do the withholding statements appear?

**Question**: FR-013, FR-014, FR-015, and FR-034 require the same statement on four surfaces with
four different readers.

**Decision**:

| Surface | Content | Why it differs |
|---------|---------|----------------|
| Sync summary (default) | Per-source counts and sizes, the limit applied, plus individually named exceptions — oversized items (FR-009), starved sources (FR-008a), conflict withdrawals (FR-033) | Runs at four automatic points per cycle; must stay readable |
| Sync summary (`--verbose`) | The above, plus every withheld path | FR-034; sits beside the existing per-source file listing |
| `knowledge-index.md` header | Counts and sizes only — **no paths** | FR-014. The agent reads this file in full; naming excluded files there invites it to open them |
| Context Output block | One line stating the corpus is partial | FR-015. The agent must not present a budgeted corpus as complete |

**Rationale**: the three surfaces have genuinely different readers — a human scanning output, a
downstream consumer parsing the index, and an agent about to draft a spec. Emitting one identical
blob to all three would either flood the default output or under-inform the index.

---

## R8 — Which defenses exist today, and which exposures are undefended? *(promoted to FR-026)*

**Question**: FR-028 and FR-031 forbid the trust model from naming any defense the extension does
not actually implement. This required auditing the current command files rather than reasoning
from memory.

**Verified present** (read from `commands/speckit.knowledge.sync.md`):

| Defense | Covers | Does *not* cover |
|---------|--------|------------------|
| Leading-`-` rejection on `url`, `revision`, `path_filter` | Argument injection into `git` | Any value that is legitimately shaped but points somewhere hostile |
| `--` separator before every configuration-derived operand | The same, if validation is bypassed | As above |
| `--no-checkout` and `--filter=blob:none` on clone | Fetching a working tree wholesale | The subsequent `git checkout -- <rev>`, which does write files |
| `timeout 10` / `timeout 30` on every network call | A hung or tarpitting host | A fast host that serves hostile content |
| `path_filter` | Corpus size and blast radius | Anything inside the filtered paths |
| Hooks declared `optional: true` | Unattended fetches — the user is prompted | A user who accepts the prompt |
| Manifest SHA-256 integrity check | Local cache corruption | Content that was hostile when fetched |

**Verified absent** — and therefore stated in the trust model as undefended:

1. **Prompt injection through fetched markdown.** Already anticipated by the specification.
2. **Credential presentation to a configured host.** The local credential helper decides what to
   send; the extension does not scope, filter, or inspect it.
3. **Symlink following.** *Discovered here.* Indexing enumerates `.md` files after checkout, and
   `git checkout` faithfully recreates symlinks. A source repository containing
   `notes.md -> /Users/<user>/.ssh/id_rsa` yields an index entry the agent is instructed to open
   and read into its context — and from there, potentially into a committed specification. No
   step in the current pipeline resolves, rejects, or flags a symlink.

Finding 3 is a genuine data-exfiltration path, reachable by exactly the mechanism the trust model
exists to describe: a merged pull request adding one configuration line. It is **promoted into
FR-026's enumeration**, whose list is explicitly "at minimum".

**Scope note.** Defending against it — refusing to index symlinks that escape the cache root — is
a real fix and a small one, but it is a behavioural change with its own edge cases (legitimate
intra-repository symlinks), and this feature's trust-model half was scoped as documentation. It is
documented as undefended here and recorded in the specification's Assumptions as the strongest
candidate for the next feature. Naming an exposure the project has decided not to fix yet is
exactly what FR-031 demands; quietly omitting it would be the failure FR-031 was written to
prevent.

---

## Summary

| # | Question | Decision |
|---|----------|----------|
| R1 | Portable byte measurement | `wc -c < file`; never `du` or `stat` |
| R2 | Size value format | `^[0-9]+(kb\|mb)$`, binary units, matching the `max_cache_age` shape |
| R3 | Allocation algorithm | Progressive fill per dimension, intersected; label-order tiebreak |
| R4 | Config keys and validation | `max_items`, `max_bytes` at both levels; `0` rejected; three rule copies must stay identical |
| R5 | Pipeline position | After conflict detection, before index write — **exposed FR-035** |
| R6 | Advisory thresholds | 200 items / 2 mb, calibration not contract |
| R7 | Reporting surfaces | Four surfaces, deliberately different content |
| R8 | Trust model audit | Seven defenses verified present; three exposures undefended — **symlink following promoted into FR-026** |

**Output**: all NEEDS CLARIFICATION resolved. Two requirements promoted to [spec.md](spec.md).
