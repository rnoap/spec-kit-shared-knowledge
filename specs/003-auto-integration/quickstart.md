# Quickstart: Auto-Integration with /speckit-specify and /speckit-plan

**Date**: 2026-06-17 | **Branch**: `003-auto-integration` | **Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

---

## Purpose

End-to-end manual validation that the v1.1.0 Auto-Integration feature works as designed. Six runnable steps map directly to spec § Success Criteria SC-001…SC-006 and to the literal **Contract: Context Output Block** section in [plan.md](plan.md).

This is a **manual smoke test** — same approach as features 001 and 002. There is no automated test framework (Constitution §III).

---

## Prerequisites

| Tool | Version | Verify |
|------|---------|--------|
| spec-kit | `>= 0.10.0` | `specify --version` |
| git | `>= 2.25` | `git --version` |
| python3 | any 3.x | `python3 --version` |
| A consuming AI agent | Claude Code, GitHub Copilot, or Cursor | (per-agent — must honor `before_*` hook stdout in context) |

You also need:

- A **fresh test project** directory (a scratch spec-kit project — empty or near-empty `specs/` is fine).
- A **fixture knowledge source** repo on disk with at least one `.md` file at a known relative path. A trivial fixture:

  ```bash
  mkdir -p /tmp/fixture-payment-service/specs/events
  cat > /tmp/fixture-payment-service/specs/events/payment-completed.md <<'EOF'
  # payment.completed event

  Fired after a successful charge. Schema:
  - `payment_id` (uuid)
  - `amount_cents` (int)
  - `currency` (ISO 4217)
  EOF
  cd /tmp/fixture-payment-service && git init -q && git add -A && git commit -qm "fixture"
  ```

---

## Step 1 — Install the extension into a fresh test project

```bash
specify extension add knowledge --dev /path/to/spec-kit-shared-knowledge
```

**Expected**:

- spec-kit copies the extension into `<test-project>/.specify/extensions/knowledge/` (manifest, command files, config template) per the official [Extension Development Guide](https://github.com/github/spec-kit/blob/main/extensions/EXTENSION-DEVELOPMENT-GUIDE.md).
- spec-kit auto-registers the `before_specify` and `before_plan` hooks declared under the top-level `hooks:` key in [extension.yml](../../extension.yml) (per FR-003, research § R1).
- `<test-project>/.specify/extensions/knowledge/knowledge.yml` is created (template copy) with `sources: []`.
- The CLI exits 0.

**Verify install + auto-registration** (assertive checks — do NOT swallow failures):

```bash
cd /path/to/test-project
specify extension list | grep -E "^\s*knowledge\s+1\.1\.0" \
  || { echo "❌ FR-003 failed: knowledge 1.1.0 not registered"; exit 1; }

# Confirm hooks were auto-registered (one of two equivalent signals must succeed):
specify extension list --verbose 2>/dev/null | grep -E "before_(specify|plan).*speckit\.knowledge\.sync" \
  || grep -E "speckit\.knowledge\.sync" .specify/extensions.yml \
  || { echo "❌ FR-003 failed: hooks not auto-registered"; exit 1; }
echo "✅ hooks auto-registered"
```

> Maps to: **SC-005** (install → first cited spec under 2 minutes), **FR-003**, **C1/C2** verification depth.

---

## Step 2 — Configure one local-path knowledge source

```bash
cd /path/to/test-project
/speckit-knowledge-configure /tmp/fixture-payment-service specs/
```

**Expected stdout**:

```
✅ knowledge.yml updated.

Configured sources:
  1. fixture-payment-service  →  /tmp/fixture-payment-service  (path: specs/)
```

**Verify**:

```bash
cat .specify/extensions/knowledge/knowledge.yml
# sources:
#   - label: fixture-payment-service
#     url: /tmp/fixture-payment-service
#     path_filter: specs/
#     enabled: true
```

Exit 0 in all branches.

---

## Step 3 — Run sync and verify the Context Output block

```bash
/speckit-knowledge-sync
```

**Expected stdout (tail)** — must end exactly like this (per [plan.md](plan.md) § Contract):

```
🔄 Syncing cross-repo knowledge sources...

  fixture-payment-service    ✅ fresh    1 items   (synced 2026-06-17T...)

✅ Knowledge index updated: 1 items from 1 source.
   → .specify/extensions/knowledge/knowledge-index.md

══════════════════════════════════════════════════════════════════════
📚 SHARED KNOWLEDGE CONTEXT (for the AI agent)

You are about to draft a spec or plan in this project. Before you do:

1. Read `.specify/extensions/knowledge/knowledge-index.md` in full.
2. Open every `.md` file referenced by that index from
   `.specify/extensions/knowledge/cache/<slug>/...`.
3. When you cite borrowed information, use the format
   `<source-label> › <relative-path>` (example:
   `payment-service › specs/events/payment-completed.md`).
4. When the index annotates an item with `⚠️ CONFLICT`, surface every
   version present and flag the conflict to the human user.
══════════════════════════════════════════════════════════════════════
```

**Verify**:

- The block appears as the LAST section of stdout (nothing after the bottom rule).
- Top and bottom rules are 70 × `══` (U+2550) on their own lines.
- Banner line carries `📚 SHARED KNOWLEDGE CONTEXT (for the AI agent)`.
- All four directives are present and addressed in second person.
- Citation example uses `›` (U+203A), not `>` or `/`.
- Exit code is 0: `echo $?` prints `0`.

> Maps to: **SC-003** (default-emit on success), **FR-006…FR-013**, plan § Contract.

---

## Step 4 — Run /speckit-specify and verify cross-repo citations

```bash
/speckit-specify "Add a checkout flow that emits a payment.completed event when the charge succeeds"
```

**Expected**:

- The `before_specify` hook auto-fires `speckit.knowledge.sync` first (per FR-003, research § R2). You should see the sync output (including the Context Output block) in your agent's session log.
- The agent reads `.specify/extensions/knowledge/knowledge-index.md` and the referenced cache file.
- The generated `specs/NNN-checkout-flow/spec.md` contains **at least one citation** in the form `<source-label> › <relative-path>`, e.g. `fixture-payment-service › specs/events/payment-completed.md`.

**Verify**:

```bash
grep -E "fixture-payment-service\s*›" specs/*/spec.md
# Expect: ≥ 1 match
```

If zero matches but the sync block was visible in the agent log, the issue is on the agent side (non-compliant or block lost in context); see [research.md](research.md) § R2 — this falls back to today's "no knowledge in spec" behavior, no regression.

> Maps to: **SC-001** (zero-config citation), **US-1**, **FR-001…FR-005**.

---

## Step 5 — Run sync with `--no-context-output` and verify suppression

```bash
/speckit-knowledge-sync --no-context-output
```

**Expected**:

- Per-source status table prints exactly as in step 3.
- Summary line `✅ Knowledge index updated: …` prints exactly as in step 3.
- Pointer line `   → .specify/extensions/knowledge/knowledge-index.md` prints exactly as in step 3.
- **The Context Output block is absent** — no top rule, no banner, no directives, no bottom rule.
- Exit code is 0.

Then re-run **without** the flag:

```bash
/speckit-knowledge-sync
```

The block reappears identically to step 3.

**Combined-flag check** (US-4 scenario 3):

```bash
/speckit-knowledge-sync --verbose --no-context-output
```

**Expected**: per-source verbose file lists print, but the Context Output block is suppressed. The two flags compose orthogonally.

> Maps to: **SC-003** (suppression respected), **US-4**, **FR-014**.

---

## Step 6 — Verify degraded-mode behavior (FR-016 / FR-013)

### 6a. All sources unreachable, prior cache exists → block IS emitted

Make the source unreachable, then sync (the cache from step 3 is still on disk):

```bash
mv /tmp/fixture-payment-service /tmp/fixture-payment-service.HIDDEN
/speckit-knowledge-sync
```

**Expected stdout (tail)**:

```
  fixture-payment-service    ⚠️  cached   1 items   (last synced 2026-06-17T... — Xm ago)
                             Could not reach /tmp/fixture-payment-service (...)

✅ Knowledge index updated: 1 items from 1 source.
   → .specify/extensions/knowledge/knowledge-index.md

══════════════════════════════════════════════════════════════════════
📚 SHARED KNOWLEDGE CONTEXT (for the AI agent)
...
══════════════════════════════════════════════════════════════════════
```

The block IS emitted — the cached `knowledge-index.md` is still valid context. Exit 0.

### 6b. All sources unreachable AND no prior `knowledge-index.md` → block is OMITTED + soft warning

Restore reachability and reset state, then re-break:

```bash
mv /tmp/fixture-payment-service.HIDDEN /tmp/fixture-payment-service
rm -rf .specify/extensions/knowledge/cache .specify/extensions/knowledge/knowledge-index.md
mv /tmp/fixture-payment-service /tmp/fixture-payment-service.HIDDEN
/speckit-knowledge-sync
```

**Expected stdout (tail)**:

```
  fixture-payment-service    ❌  unreachable — no cache available; source skipped

✅ Knowledge index updated: 0 items from 0 sources.

⚠️  No knowledge-index.md found yet. Run /speckit-knowledge-sync once when sources are reachable.
```

- Exit code is 0.
- The Context Output block is **NOT** emitted (no index file exists to point the agent at).

### 6c. `knowledge.yml` absent → block is OMITTED silently (FR-015)

```bash
mv .specify/extensions/knowledge/knowledge.yml /tmp/knowledge.yml.bak
/speckit-knowledge-sync
```

**Expected stdout** (existing behavior, unchanged):

```
❌ Error: knowledge.yml not found. Run /speckit-knowledge-configure to initialize.
```

- Exit code is 0.
- No Context Output block.
- No "no knowledge-index.md yet" warning (this path is for unconfigured projects, not degraded sources).

Restore for cleanup:

```bash
mv /tmp/knowledge.yml.bak .specify/extensions/knowledge/knowledge.yml
mv /tmp/fixture-payment-service.HIDDEN /tmp/fixture-payment-service
```

> Maps to: **SC-004** (early-exit paths emit zero blocks), **FR-013**, **FR-015**, plan § Contract suppression tables.

---

## Pass criteria

All six steps pass when:

- [x] Step 1 — extension installs into a clean project; 4 commands listed; exit 0.
- [x] Step 2 — `knowledge.yml` shows the configured source.
- [x] Step 3 — Context Output block appears at the tail of sync stdout with the exact format defined in [plan.md](plan.md) § Contract.
- [x] Step 4 — generated `spec.md` contains ≥ 1 citation in `<source-label> › <relative-path>` form.
- [x] Step 5 — `--no-context-output` suppresses ONLY the block; runs again without the flag and the block returns; composes with `--verbose`.
- [x] Step 6 — degraded mode with cache emits the block; degraded mode without any prior index omits the block and prints the soft warning; unconfigured project omits the block silently.
- [x] Every command in every step exits 0.

If all six pass, the feature satisfies all 17 functional requirements (FR-001…FR-017) and all six measurable success criteria (SC-001…SC-006).
