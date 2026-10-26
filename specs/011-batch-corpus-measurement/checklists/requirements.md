# Specification Quality Checklist: Shell-recorded manifests, so a full knowledge sync fits in one turn

**Purpose**: Validate Companion specification completeness before planning
**Created**: 2026-10-26
**Feature**: [batch-corpus-measurement.spec.md](../batch-corpus-measurement.spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed (User Scenarios, Requirements, Success Criteria)

## Requirement Completeness

- [x] Any [NEEDS CLARIFICATION] markers are genuine ambiguities (≤3) deferred to clarify — not unresolved guesses
- [x] Each Functional Requirement is a single, testable MUST/SHOULD statement
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into the specification

## Notes

- One marker remains, FR-006: how sync reports a name that is not valid UTF-8. The assessment carried it forward as open, and both answers are viable. Resolve it in clarify.
- JSON, SHA-256 and the manifest keys come from the existing manifest format, which the request pins. The shells and platforms in FR-016 describe where the feature must run, not how it is built. Tool names (the awk variants, JSON::PP) appear only in Assumptions, as the decision's spike matrix.
- The readers are the extension's developers and its maintainer, so the spec uses their terms (sync, cache, manifest) in plain language.
- FR-009, FR-015 and FR-019 are checked by inspection (write order, declared tools, the 007 record), not by a user scenario.
- Open evidence questions (where the failed run's 23 steps went, whether that stop repeats) are not spec choices. Assumptions has them answered by a recorded cold baseline run before release.
