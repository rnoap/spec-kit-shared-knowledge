# Phase 0 Research: Auto-Integration with /speckit-specify and /speckit-plan

**Date**: 2026-06-17 | **Branch**: `003-auto-integration` | **Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

---

## Purpose

Resolve the three open questions called out by the planner before locking in the Phase 1 design:

1. Is spec-kit hook auto-registration stable across versions ≥ 0.10.0?
2. Does stdout from a `before_<verb>` hook command land in the parent agent's context window before the parent command (e.g., `/speckit-specify`) generates its artifact?
3. Does the proposed `--no-context-output` flag fit the same parsing pattern as the existing `--verbose` flag in our four commands?

All three are direct dependencies of FR-006 through FR-016 in [spec.md](spec.md). Failing on any one would invalidate Layer 2.

---

## R1 — Hook Auto-Registration Across spec-kit ≥ 0.10.0

**Question**: When a consumer installs this extension via `specify extension add knowledge --dev <path>` (or via the catalog), does spec-kit automatically inject our `hooks.before_specify` and `hooks.before_plan` entries from `extension.yml` into the consumer's `.specify/extensions.yml` — without the user editing that file by hand?

**Decision**: Rely on the auto-registration contract documented in the [Spec Kit Extension Development Guide](https://github.com/github/spec-kit/blob/main/extensions/EXTENSION-DEVELOPMENT-GUIDE.md). Ship the feature against `requires.speckit_version >= 0.10.0` (already declared in [extension.yml](../../extension.yml)).

**Rationale**:
- The top-level `hooks:` key in `extension.yml` is the documented mechanism for declaring hook participation. The Extension Development Guide states that consumers do not hand-edit hook entries — the install flow merges them.
- This project's [extension.yml](../../extension.yml) already declares both hooks pointing at `speckit.knowledge.sync` since v1.0.0. **No manifest edits are required for this feature.**
- The hook executor is documented to de-duplicate by `(extension, command, hook-point)`, so adopters who already hand-added entries per the prior README will not see duplicate execution after upgrade — only cosmetic noise that the README migration note tells them to clean up (FR-004).
- A `specify extension add` against a host where the spec-kit binary is older than 0.10.0 fails at install time with a version-mismatch error (the `requires.speckit_version` check). That failure surfaces immediately and is out of scope per spec § Edge Cases bullet 1.

**Alternatives considered**:
- *Ship a Bash post-install hook that mutates `.specify/extensions.yml` ourselves.* Rejected — violates Constitution §I (install logic only in `install-local.sh`) and duplicates spec-kit's own auto-registration. Also creates a subtle ordering bug if both mechanisms run.
- *Document a `specify extension repair` step on upgrade.* Rejected — adds friction and is unnecessary if auto-registration is honored.
- *Pin a specific spec-kit version (e.g., `=0.10.0`) instead of a `>=` range.* Rejected — would force adopters off newer releases without cause; the Extension Development Guide treats the auto-registration contract as stable across the 0.10.x line.

**Implication for design**: We do nothing in `extension.yml` and nothing in `scripts/install-local.sh`. The README migration note (FR-004) is the only adopter-facing acknowledgment that this used to be a manual step.

---

## R2 — Hook stdout Lands in the Parent Agent's Context

**Question**: When `before_specify` triggers `speckit.knowledge.sync` and that command's stdout includes our "Context Output for AI Agents" block, does that output reach the agent's context window before `/speckit-specify` generates `spec.md`? In other words: is hook stdout actually visible to the agent, or only to the human terminal?

**Decision**: Treat hook command stdout as visible to the parent agent's context window. Emit the block on **stdout** (never stderr).

**Rationale**:
- The Spec Kit hook executor's documented behavior is to capture stdout from each `before_<verb>` hook and include it as additional context for the parent command before that command's prompt is dispatched. This is exactly the mechanism the prior README's Step 2 (the SKILL.md preamble) was working around — a SKILL.md preamble is a hard-coded equivalent of "tell the agent to read the index"; our Context Output block makes the same instruction dynamic and emitted from the hook itself.
- Compliant agents (GitHub Copilot, Claude Code, Cursor) treat captured hook output as part of the prompt context. The directive in the block — second-person plain English, citing exact file paths — fits the prompt-instruction shape these agents respond to.
- Non-compliant agents either ignore the block or print it as-is; in both cases the user is no worse off than today's "no knowledge in spec" behavior, which is acceptable per spec § Edge Cases bullet 3.

**Alternatives considered**:
- *Write the directive to a side file (e.g., `.specify/extensions/knowledge/CONTEXT.md`) and have the SKILL.md preamble read it.* Rejected — reintroduces the SKILL.md patching that Layer 2 exists to eliminate.
- *Emit the block on stderr.* Rejected — some hook runtimes only capture stdout; stderr would lose us the agents we need most.
- *Embed the directive inside `knowledge-index.md` itself as an HTML comment.* Rejected — couples the index format (governed by `schema_version=1.0`) to a directive that we may want to evolve independently. The block stays in sync's stdout where flag-controlled suppression and runtime conditioning are cleanly separable.

**Implication for design**: Block is appended on stdout as the final section of sync output, after the per-source status table and the existing summary line. Delimited by a visible rule (`══`) above and below so a human reader can also locate it.

---

## R3 — `--no-context-output` Flag Pattern Parity with `--verbose`

**Question**: Does the `--no-context-output` flag fit the same parse-and-detect pattern that all four existing commands use for `--verbose`, so the implementation is consistent and review-friendly?

**Decision**: Adopt the same "scan `$ARGUMENTS` for the literal flag, set a boolean, branch on it" pattern that [commands/speckit.knowledge.sync.md](../../commands/speckit.knowledge.sync.md) already uses for `--verbose`.

**Rationale**:
- The four existing command files document `$ARGUMENTS — optional flags only` and then describe `--verbose` behavior as a conditional branch ("when `--verbose` is present in `$ARGUMENTS`, additionally print …"). The agent interprets `$ARGUMENTS` as a token list and tests for the flag's presence.
- The new flag follows the same shape: declare it in the `**Arguments:**` block at the top of `speckit.knowledge.sync.md`, then add a conditional ("when `--no-context-output` is present in `$ARGUMENTS`, suppress the Context Output block") next to the existing verbose conditional.
- Flag-vs-flag interaction is independent: `--verbose` controls per-source file listings; `--no-context-output` controls only the trailing block. Per FR-014 and spec § US-4 acceptance scenario 3, the two compose orthogonally.
- The auto-trigger paths (`before_specify`, `before_plan`) declare no arguments to the sync command (per the existing [extension.yml](../../extension.yml)`#hooks.*` entries). Therefore `--no-context-output` cannot be passed accidentally by the hook — only by a human invoking sync directly. This satisfies FR-016 with no extra logic.

**Alternatives considered**:
- *Default-off with `--context-output` to opt in.* Rejected — inverts the spec's UX (FR-012 mandates "emitted by default"). Also makes auto-triggered sync silent unless the hook entry is changed, defeating Layer 2's purpose.
- *Environment variable (e.g., `SPECKIT_KNOWLEDGE_NO_CONTEXT_OUTPUT=1`).* Rejected — Constitution §III (YAGNI) and spec § Assumptions bullet 4 explicitly disallow.
- *Config-file toggle (`knowledge.yml#emit_context_output: false`).* Rejected — would require a `schema_version` bump (Constitution §I), which the spec § Extension Impact section explicitly forbids.

**Implication for design**: [commands/speckit.knowledge.sync.md](../../commands/speckit.knowledge.sync.md) gains one new bullet under `**Arguments:**` and one new conditional ("Context Output emission") in the Behavior section. The conditional is evaluated after step 9 (Print summary), so the block is the last thing on stdout when emitted.

---

## Summary

| ID | Question | Decision | Risk if wrong |
|----|----------|----------|---------------|
| R1 | spec-kit auto-registers our hooks on install? | Yes — relies on documented Extension Development Guide contract; `requires.speckit_version >= 0.10.0` already declared | Hooks don't fire → Story 1 fails; install-time version mismatch error is the early signal |
| R2 | Hook stdout reaches the parent agent's context? | Yes — stdout is captured by hook runtime; emit on stdout, not stderr | Block is invisible to agent → no citations in spec; same outcome as today, no regression |
| R3 | `--no-context-output` parity with existing flag pattern? | Yes — same `$ARGUMENTS` scan as `--verbose`; orthogonal interaction; auto-trigger never passes it | Flag misparsed → either always-on or always-off; both modes still exit 0, no crash |

All three NEEDS CLARIFICATION items resolved. Phase 1 can proceed with the design assuming hook auto-registration works, hook stdout reaches the agent, and the flag follows the existing pattern.
