# Contract — command surface

**Status**: normative for extension version 1.4.0 | **Command count**: 4 → **5**
**Feature**: [../spec.md](../spec.md) | **Plan**: [../plan.md](../plan.md)

The commands spec-kit registers in a consumer project from `extension.yml#provides.commands`.
This contract governs argument shape, flags, and output guarantees — not implementation prose,
which lives in `commands/*.md`.

---

## Universal invariants

These hold for every command, every path, without exception.

| Invariant | Detail |
|-----------|--------|
| **Exit 0 always** | Validation errors, unknown labels, ambiguous identifiers, unreachable remotes, unresolvable revisions and corrupt caches are all reported as **messages**. No command ever exits non-zero (FR-023). |
| **No hidden dependencies** | Each command file is self-contained Markdown. Nothing instructs the agent to read a file that `extension.yml` does not install (Constitution §I). |
| **Hooks pass no arguments** | Every entry in `extension.yml#hooks` invokes a bare command. Any flag is therefore structurally unreachable from an automatic trigger — which is how FR-022 is satisfied, and how 003's FR-016 was satisfied before it. **Do not add arguments to a hook entry.** |
| **Config is validated on read** | Every command that reads `knowledge-config.yml` applies the full rule set in [knowledge-config.schema.md](knowledge-config.schema.md) first (FR-029). |

---

## Registered commands

| # | Command | Status | Purpose |
|---|---------|--------|---------|
| 1 | `speckit.knowledge.configure` | modified | Initialize or edit the knowledge source configuration |
| 2 | `speckit.knowledge.sync` | modified | Refresh the local cache for all configured, enabled sources |
| 3 | `speckit.knowledge.search` | unchanged | Browse and search the knowledge corpus |
| 4 | `speckit.knowledge.status` | modified | Show reachability, revision, last sync, item count, and cache age |
| 5 | **`speckit.knowledge.remove`** | **new** | Remove, disable, or re-enable a configured source |

---

## 5 — `speckit.knowledge.remove` *(new)*

> `description:` **"Remove, disable, or re-enable a configured knowledge source"**
>
> The description carries all three verbs deliberately: the command name says only "remove",
> so the full lifecycle would otherwise be invisible in `specify extension list` and in the
> README table. See [../research.md](../research.md) § R1.

**Arguments**: `$ARGUMENTS` — an optional source identifier, plus optional flags.

| Form | Behavior | Requirement |
|------|----------|-------------|
| `<label>` | Delete the entry **and purge its cache** | FR-001, FR-003 |
| `<label> --disable` | Set `enabled: false`; entry and cache both retained | FR-002, FR-004 |
| `<label> --enable` | Set `enabled: true` | FR-005 |
| `<url>` | Same as `<label>`, **only if the URL resolves to exactly one source** | FR-001 |
| *(no identifier)* | List configured sources with their state; prompt for a selection | FR-006 |
| `--verbose` | Print the resulting YAML after write | house convention |

**Resolution order**: match `label` exactly first. Only if no label matches, match `url`. A URL
matching two or more sources is **ambiguous** — the command lists the candidates and changes
nothing.

**Output contracts**

Ambiguous URL (FR-001, SC-009):

```text
❌ "https://github.com/org/payments" matches 2 configured sources:
     payments-v2   (revision: v2.4.1)
     payments-main (revision: main)
   Re-run with a label to disambiguate. Nothing was changed.
```

Unknown identifier (FR-007):

```text
❌ No configured source matches "paymnets". Nothing was changed.
   Configured sources: payments-v2, identity-service, shared-contracts
```

Successful removal (FR-001, FR-003, SC-001):

```text
✅ Removed source "payments-v2" from knowledge-config.yml
✅ Purged cache directory .specify/extensions/knowledge/cache/abc123def456/
   Run /speckit.knowledge.sync to rebuild the index.
```

Successful disable (FR-002, FR-004):

```text
✅ Disabled source "payments-v2". Its cache is retained — re-enabling will not re-download.
   Run /speckit.knowledge.sync to rebuild the index without it.
```

**Side effects**

- Modifies `knowledge-config.yml`.
- Deletes `cache/<slug>/` on removal only. **Never** on disable.
- Does **not** run sync, and does **not** modify `knowledge-index.md` — the index is rebuilt on
  the next sync. This keeps the command's failure surface to a single file.
- Does **not** modify `.specify/extensions.yml`.

---

## 1 — `speckit.knowledge.configure` *(modified)*

**New argument**: an optional revision, accepted as `@<revision>` appended to the URL token or
as a separate `--revision <rev>` flag.

```text
/speckit.knowledge.configure https://github.com/org/payments@v2.4.1 specs/
/speckit.knowledge.configure https://github.com/org/payments --revision v2.4.1 specs/
```

The `@` form is offered because it is the notation developers already know from package
managers. It is parsed by splitting on the **last** `@` in the token, which is unambiguous for
HTTPS URLs and local paths. For SSH URLs — which already contain `@` — the `--revision` flag is
required, and the command says so rather than guessing.

**New behavior**

| Behavior | Requirement |
|----------|-------------|
| Enforce label uniqueness before writing; resolve any collision (never write a duplicate) | FR-028 |
| Accept and persist `revision` | FR-013 |
| Apply the full read-time validation rule set, not just the two legacy `path_filter` checks | FR-029 |
| Same-URL sources are **no longer** silently merged — with different revisions they are distinct sources and must both be written | FR-009, FR-011 |

That last row is a behavior change worth calling out: 1.3.0 updated an existing entry when a
source with the same `url` was added again. Under revision pinning that would make it impossible
to configure two revisions of one repository. The merge now applies only when the URL **and**
the revision both match.

---

## 2 — `speckit.knowledge.sync` *(modified)*

**New flag**: `--force` — ignore the freshness policy and fetch every enabled source (FR-021).
Composes orthogonally with the existing `--verbose` and `--no-context-output`. Structurally
unreachable from a hook (FR-022).

**New status value**: `current` — the source was skipped because its cache is fresh by policy;
no network access occurred (FR-018, FR-019).

```text
  payments-v2        ✅ fresh    12 items  (synced 2026-09-04T14:00:00Z)
  identity-service   ⏭️  current  8 items   (cached 12m ago; policy 4h — no network)
  shared-contracts   ⚠️  cached   5 items   (last synced 2026-09-01T09:00:00Z — 3d ago)
```

**New behavior**

| Behavior | Requirement |
|----------|-------------|
| Revision-aware slug derivation | FR-011, FR-012 |
| Freshness gate before any network access | FR-018 |
| Report freshness-skipped sources as `current`, counted as usable knowledge | FR-019, FR-020 |
| Scope conflict detection by repository identity | FR-026 |
| Serve an over-age cache when the source is unreachable | FR-027 |
| Read-time validation; a bad field skips only its own source | FR-029, FR-030 |
| Delete `knowledge-index.md` and emit no context block when no enabled sources remain | FR-031 |
| Prune cache directories matching no configured source (enabled **or** disabled) | gap G1 |

**Unchanged and load-bearing**: the Context Output Block, its emission gate, its exact 70×`═`
rules, and the exit-0 contract — all inherited from 003. The two new emission states are
resolved in [../data-model.md](../data-model.md) § 5.

---

## 4 — `speckit.knowledge.status` *(modified)*

**New column**: effective revision per source (FR-014), showing `default` when none is pinned.

**Reconciled labels**: `status` currently hard-codes "fresh = synced within 24h". Once a policy
exists, **the policy determines the label**; the 24-hour heuristic survives only as the default
for sources with no policy, which FR-024 requires for projects that upgrade and change nothing.
The threshold actually used is rendered, so a label is never unexplained. This is gap G2 in
[../research.md](../research.md).

---

## 3 — `speckit.knowledge.search` *(unchanged)*

`search` reads `knowledge-index.md`, not `knowledge-config.yml`, so it inherits validation
transitively and needs no change. **Confirm this during `/speckit.tasks`** — if it turns out to
read the config directly, it must adopt the read-time rule set like the other three.

---

## `extension.yml` deltas

```yaml
extension:
  version: "1.4.0"                      # was 1.3.0 — minor: additive, backward-compatible

provides:
  commands:
    # … four existing entries unchanged …
    - name: speckit.knowledge.remove
      file: commands/speckit.knowledge.remove.md
      description: "Remove, disable, or re-enable a configured knowledge source"

hooks:                                   # UNCHANGED — all four, still argument-free
```

The hooks block must not gain arguments. It is the mechanism that makes `--force` unreachable
from an automatic trigger (FR-022).
