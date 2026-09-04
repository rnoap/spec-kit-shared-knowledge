# Feature Specification: Source Lifecycle & Cache Policy

**Feature Branch**: `main`
**Created**: 2026-09-04
**Status**: Draft

## Overview

Knowledge sources today can only be added: removing or pausing one means hand-editing YAML, every source is pinned to whatever the remote's default branch happens to be, and every hook invocation refetches over the network. This feature gives sources a full lifecycle (add / disable / re-enable / remove), lets each source pin a specific branch, tag, or commit, and adds a cache freshness policy so a sync can no-op when the cached content is still current.

## Functional Requirements

### Source lifecycle

- **FR-001**: The extension MUST provide a command that removes a configured knowledge source, identified by its label or its URL, without the user editing configuration by hand.
- **FR-002**: The remove command MUST support a disable mode that marks a source inactive while leaving its entry in the configuration file.
- **FR-003**: Removing a source MUST also delete that source's cached content, so no orphaned cache directories accumulate.
- **FR-004**: Disabling a source MUST retain its cached content, so re-enabling does not require a full re-download.
- **FR-005**: The extension MUST provide a way to re-enable a previously disabled source.
- **FR-006**: When invoked with no source identifier, the command MUST list the configured sources and let the user pick one.
- **FR-007**: When the supplied identifier matches no configured source, the command MUST report that clearly and leave the configuration unchanged.
- **FR-008**: Disabled sources MUST be skipped during synchronization and MUST NOT contribute items to the knowledge index.

### Per-source revision pinning

- **FR-009**: A source MUST be able to declare a specific revision — a branch, tag, or commit identifier — to read from.
- **FR-010**: When a source declares no revision, its content MUST come from the remote's default revision, matching current behavior.
- **FR-011**: Two sources that reference the same repository at different revisions MUST NOT share cached content.
- **FR-012**: Changing a source's revision MUST cause the next synchronization to serve content from the new revision, never stale content from the previous one.
- **FR-013**: The configure command MUST accept a revision when a source is added or updated.
- **FR-014**: The status command MUST display each source's effective revision.
- **FR-015**: When a declared revision cannot be resolved on the remote, that source MUST be reported as unreachable and fall back to its existing cache if one is intact.

### Cache freshness policy

- **FR-016**: The configuration MUST support a maximum cache age, settable once for all sources and overridable per source.
- **FR-017**: When no maximum cache age is configured, every synchronization MUST fetch, matching current behavior.
- **FR-018**: When a source's cache is younger than its maximum age, synchronization MUST skip the network for that source and reuse the cached content.
- **FR-019**: A source skipped for freshness MUST be reported distinctly from one that was fetched, so the user can tell no network access occurred.
- **FR-020**: A source skipped for freshness MUST count as usable knowledge, so the agent-facing context instructions are still emitted.
- **FR-021**: The sync command MUST provide a way to force a fetch that ignores the freshness policy.
- **FR-022**: Automatically triggered synchronizations MUST NOT be able to force a fetch, so the freshness policy always applies to hook-driven runs.

### Compatibility

- **FR-023**: All commands MUST continue to report failures as messages rather than process errors, on every path introduced here.
- **FR-024**: A project upgrading to this version without changing its configuration MUST observe unchanged behavior.
- **FR-025**: The configuration schema version MUST remain unchanged, as every new field is optional.

## Success Criteria

- **SC-001**: A user removes a source and its cached content with a single command and zero manual edits to any configuration file.
- **SC-002**: While a source is disabled it contributes no items to the knowledge index, and a subsequent re-enable restores it to full use without re-downloading its content.
- **SC-003**: Two sources pointing at the same repository at different revisions each surface the content of their own revision, with no cross-contamination.
- **SC-004**: With a maximum cache age configured that exceeds the length of a working session, a full feature cycle that triggers all four synchronization points performs at most one network fetch per source.
- **SC-005**: An existing project that upgrades and changes nothing produces the same synchronization results, the same index contents, and the same agent-facing output as before the upgrade.
- **SC-006**: Every command exits successfully on every path exercised here, including unknown source identifiers, unresolvable revisions, and expired or missing caches.
- **SC-007**: Removing every source leaves no cached content behind on disk.

## Assumptions

- **Cache identity includes the revision, but only when one is set.** A source with no declared revision keeps the cache identity it has today, so upgrading does not invalidate existing caches. A source that declares a revision derives a distinct identity, which satisfies FR-011 and FR-012 without a migration step.
- **Freshness is opt-in and defaults to off.** With no maximum cache age configured, behavior is byte-identical to the current release. Users who added the clarify and tasks hooks in 1.3.0 are the ones who need it, and they opt in deliberately.
- **A freshness-skipped source is treated as current knowledge.** The existing emission contract keys off whether at least one source has usable content; a cache that is fresh by policy qualifies. It is displayed under its own label so the distinction stays visible to the user.
- **Removal purges the cache immediately** rather than deferring to a separate cleanup step. This is the least surprising reading of "remove" and avoids introducing a garbage-collection concept.
- **Maximum cache age is expressed as a human-readable duration** rather than a raw number, so the unit is unambiguous in a committed configuration file.
- **Disable is preferred over remove for temporary pauses.** The configuration format already carries an enabled flag; this feature exposes it through a command rather than introducing a parallel mechanism.
- **The three capabilities ship together.** The freshness policy is what makes the four synchronization points introduced in 1.3.0 affordable, and revision pinning is what makes a long-lived cache safe to trust. Shipping them separately leaves the extension in a worse state than shipping none of them.
