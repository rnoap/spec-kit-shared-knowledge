# Specification Quality Checklist: Source Lifecycle & Cache Policy

**Purpose**: Validate turbo specification completeness before planning
**Created**: 2026-09-04
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user/business value and the change's intent
- [x] Overview states what is delivered and why in 1–3 sentences
- [x] All four sections present (Overview, Functional Requirements, Success Criteria, Assumptions)

## Requirement Completeness

- [x] Any [NEEDS CLARIFICATION] markers are genuine ambiguities (≤3) deferred to clarify — not unresolved guesses
- [x] Each Functional Requirement is a single, testable MUST/SHOULD statement
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] Edge cases are folded into Functional Requirements or Assumptions
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] Every Functional Requirement maps to at least one Success Criterion
- [x] Overview intent is reflected by the FR list (no orphan goals)
- [x] No implementation details leak into the specification

## Notes

- **Post-clarify state.** `/speckit.clarify` ran on 2026-09-04 and asked its full
  quota of 5 questions. All five were answered and integrated; see
  [spec.md](../spec.md) § Clarifications. The specification still carries zero
  `[NEEDS CLARIFICATION]` markers.
- The three design questions raised during classification — cache identity versus
  revision, the status of a freshness-skipped source under the existing emission
  contract, and the need for a forced-fetch escape hatch — were resolved as
  informed defaults at specify time and were **not** overturned by clarify.
- Clarify surfaced two problems the self-check had missed, both now fixed in the
  spec:
  - **FR-001 was incorrect.** It identified a source "by its label or its URL",
    but FR-009 (revision pinning) makes a URL non-unique. Rewritten, with
    FR-028 added to guarantee label uniqueness at configure time.
  - **Validation sat at the wrong boundary.** The inherited path-filter checks run
    only when the configure command writes, so hand-edited, pull-requested, or
    older-version configuration was consumed unchecked. FR-029/FR-030 move the
    guarantee to the read path.
- One fail was found and fixed during the original self-check pass: FR-008
  (disabled sources contribute nothing to the index) had no covering Success
  Criterion. SC-002 was widened to assert it.
- **Structural deviation, deliberate.** Clarify normally adds only the
  `## Clarifications` and `### Session` headings. Two further subsections were
  added under Functional Requirements — `Conflict reporting` and
  `Configuration validation` — because that section was already organised into
  subsections and the new requirements belonged to neither of the existing four.
  They are peers of the originals, so the heading hierarchy is unchanged.
- **FR numbering is intentionally non-contiguous.** FR-026 through FR-031 were
  appended by clarify and placed in the subsection they belong to rather than
  renumbered into sequence, so that existing references stay valid.
- Coverage spot-checks: FR-022 (hook-driven runs cannot force a fetch) is
  verified by SC-004 — if the four synchronization points could force, the cycle
  would perform four fetches per source rather than one. Every FR added by
  clarify maps to a Success Criterion: FR-026→SC-003, FR-027→SC-008,
  FR-028→SC-009, FR-029/030→SC-010, FR-031→SC-007.
