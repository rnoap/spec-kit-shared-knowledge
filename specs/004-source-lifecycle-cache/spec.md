# Feature Specification: Source Lifecycle & Cache Policy

**Feature Branch**: `main`
**Created**: 2026-09-04
**Status**: Draft

## Overview

Knowledge sources today can only be added: removing or pausing one means hand-editing YAML, every source is pinned to whatever the remote's default branch happens to be, and every hook invocation refetches over the network. This feature gives sources a full lifecycle (add / disable / re-enable / remove), lets each source pin a specific branch, tag, or commit, and adds a cache freshness policy so a sync can no-op when the cached content is still current.

## Clarifications

### Session 2026-09-04

- Q: When two sources reference the same repository at different revisions, should their overlapping file paths be reported as conflicts? → A: No — conflicts are reported only between sources whose repository identity differs. Two revisions of one repository are the same source seen at two points in time, not a disagreement between teams.
- Q: Is the maximum cache age a hint that gates fetching, or a hard expiry that makes over-age content unusable? → A: A hint. It governs only whether a refresh is attempted; an over-age cache is still served when the source cannot be reached.
- Q: How is a source identified when removing or disabling it, given that revision pinning lets two sources share a URL and derived labels can collide? → A: The label is the stable identity and is unique by construction — uniqueness is enforced when the source is added. A URL is accepted only when it resolves to exactly one source.
- Q: What is validated in the project configuration, and at which point? → A: One documented rule per field, covering every configuration value, applied when the configuration is read rather than only when it is written.
- Q: What happens to the knowledge index and the agent-facing context instructions once no enabled sources remain? → A: The index is deleted and the context instructions are not emitted — a stale index would let an agent keep citing knowledge the project no longer declares.

## Functional Requirements

### Source lifecycle

- **FR-001**: The extension MUST provide a command that removes a configured knowledge source, identified by its label, without the user editing configuration by hand. A repository URL MAY also be accepted, but only when it resolves to exactly one configured source; when it matches several — as it can once revisions are pinned — the command MUST report the ambiguity and list the candidates rather than guessing.
- **FR-002**: The remove command MUST support a disable mode that marks a source inactive while leaving its entry in the configuration file.
- **FR-003**: Removing a source MUST also delete that source's cached content, so no orphaned cache directories accumulate.
- **FR-004**: Disabling a source MUST retain its cached content, so re-enabling does not require a full re-download.
- **FR-005**: The extension MUST provide a way to re-enable a previously disabled source.
- **FR-006**: When invoked with no source identifier, the command MUST list the configured sources and let the user pick one.
- **FR-007**: When the supplied identifier matches no configured source, the command MUST report that clearly and leave the configuration unchanged.
- **FR-008**: Disabled sources MUST be skipped during synchronization and MUST NOT contribute items to the knowledge index.
- **FR-028**: Every configured source MUST carry a label that is unique within the project. When adding a source would produce a label that already exists — whether because two locations share a final path component or because the same repository is added twice at different revisions — the configure command MUST resolve the collision before writing, so that no two sources can ever share a label.
- **FR-031**: When no enabled sources remain — whether because every source was removed or every source was disabled — synchronization MUST report the project as having no configured knowledge, MUST delete any existing knowledge index so that unconfigured content stops being readable, and MUST NOT emit the agent-facing context instructions. The command MUST still complete successfully.

### Per-source revision pinning

- **FR-009**: A source MUST be able to declare a specific revision — a branch, tag, or commit identifier — to read from.
- **FR-010**: When a source declares no revision, its content MUST come from the remote's default revision, matching current behavior.
- **FR-011**: Two sources that reference the same repository at different revisions MUST NOT share cached content.
- **FR-012**: Changing a source's revision MUST cause the next synchronization to serve content from the new revision, never stale content from the previous one.
- **FR-013**: The configure command MUST accept a revision when a source is added or updated.
- **FR-014**: The status command MUST display each source's effective revision.
- **FR-015**: When a declared revision cannot be resolved on the remote, that source MUST be reported as unreachable and fall back to its existing cache if one is intact.

### Conflict reporting

- **FR-026**: A shared file path MUST be reported as a conflict only when it appears in two or more sources whose **repository identity differs**. Overlapping paths between two revisions of the same repository MUST NOT be reported as conflicts, since revision pinning makes identical paths the normal case rather than a signal of disagreement.

### Configuration validation

- **FR-029**: Every value read from the project configuration — repository location, revision, path filter, and maximum cache age — MUST be checked against a documented rule for its field **each time the configuration is read**, not only when a command writes it. Configuration reaches a project by hand-editing, by pull request, and from earlier versions of the extension; validating only on write leaves all three routes unchecked.
- **FR-030**: A value that fails its field rule MUST cause only its own source to be skipped, with a message naming the offending field and value. Remaining sources MUST continue to be processed, and the command MUST still complete successfully.

### Cache freshness policy

- **FR-016**: The configuration MUST support a maximum cache age, settable once for all sources and overridable per source.
- **FR-017**: When no maximum cache age is configured, every synchronization MUST fetch, matching current behavior.
- **FR-018**: When a source's cache is younger than its maximum age, synchronization MUST skip the network for that source and reuse the cached content.
- **FR-019**: A source skipped for freshness MUST be reported distinctly from one that was fetched, so the user can tell no network access occurred.
- **FR-020**: A source skipped for freshness MUST count as usable knowledge, so the agent-facing context instructions are still emitted.
- **FR-021**: The sync command MUST provide a way to force a fetch that ignores the freshness policy.
- **FR-022**: Automatically triggered synchronizations MUST NOT be able to force a fetch, so the freshness policy always applies to hook-driven runs.
- **FR-027**: A cache older than its maximum age MUST remain usable when its source cannot be reached. The maximum age governs only whether a refresh is *attempted*, never whether cached content may be *served*: a source whose refresh fails MUST fall back to its existing cache and report its staleness, exactly as it does today.

### Compatibility

- **FR-023**: All commands MUST continue to report failures as messages rather than process errors, on every path introduced here.
- **FR-024**: A project upgrading to this version without changing its configuration MUST observe unchanged behavior.
- **FR-025**: The configuration schema version MUST remain unchanged, as every new field is optional.

## Success Criteria

- **SC-001**: A user removes a source and its cached content with a single command and zero manual edits to any configuration file.
- **SC-002**: While a source is disabled it contributes no items to the knowledge index, and a subsequent re-enable restores it to full use without re-downloading its content.
- **SC-003**: Two sources pointing at the same repository at different revisions each surface the content of their own revision, with no cross-contamination and without either revision's files being reported as conflicting with the other's.
- **SC-004**: With a maximum cache age configured that exceeds the length of a working session, a full feature cycle that triggers all four synchronization points performs at most one network fetch per source.
- **SC-005**: An existing project that upgrades and changes nothing produces the same synchronization results, the same index contents, and the same agent-facing output as before the upgrade.
- **SC-006**: Every command exits successfully on every path exercised here, including unknown source identifiers, unresolvable revisions, and expired or missing caches.
- **SC-007**: Removing every source leaves no cached content and no knowledge index behind on disk, and the next synchronization reports the project as unconfigured rather than pointing an agent at knowledge the project no longer declares.
- **SC-008**: With a maximum cache age configured and every source unreachable, a synchronization still surfaces the cached knowledge and reports each source's staleness — configuring a freshness policy never leaves a project with less available knowledge than it had before the policy was set.
- **SC-009**: No two configured sources share a label, including when the same repository is added twice at different revisions or when two local locations share a final path component; and removing by a repository URL that matches more than one source reports the ambiguity instead of removing the wrong one.
- **SC-010**: A configuration value that violates its field rule is rejected before it reaches any external tool — regardless of how it got into the file — the affected source is skipped with a message naming the field, and every other source still synchronizes.

## Assumptions

- **Cache identity includes the revision, but only when one is set.** A source with no declared revision keeps the cache identity it has today, so upgrading does not invalidate existing caches. A source that declares a revision derives a distinct identity, which satisfies FR-011 and FR-012 without a migration step.
- **Repository identity ignores the access protocol.** Two sources that reach the same host, organization, and repository are the same repository for the purposes of FR-026, whether they are declared over HTTPS or SSH. Without this, the same repository reached two ways would report every shared file as a conflict — precisely the noise FR-026 exists to remove.
- **Freshness is opt-in and defaults to off.** With no maximum cache age configured, behavior is byte-identical to the current release. Users who added the clarify and tasks hooks in 1.3.0 are the ones who need it, and they opt in deliberately.
- **A freshness-skipped source is treated as current knowledge.** The existing emission contract keys off whether at least one source has usable content; a cache that is fresh by policy qualifies. It is displayed under its own label so the distinction stays visible to the user.
- **Freshness never blocks access to cached knowledge.** A hard expiry — treating an over-age cache as unusable — was considered and rejected: it would turn a performance optimization into an availability cliff, silently stripping all cross-repo context from a developer working offline. Staleness is surfaced in the status output so the user can judge for themselves.
- **Removal purges the cache immediately** rather than deferring to a separate cleanup step. This is the least surprising reading of "remove" and avoids introducing a garbage-collection concept.
- **Maximum cache age is expressed as a human-readable duration** rather than a raw number, so the unit is unambiguous in a committed configuration file.
- **Disable is preferred over remove for temporary pauses.** The configuration format already carries an enabled flag; this feature exposes it through a command rather than introducing a parallel mechanism.
- **The label is the stable identity of a source.** A repository URL stopped being a unique key the moment revisions became pinnable, so uniqueness is enforced on the label when a source is added rather than resolved separately by every command that consumes one. That keeps the ergonomic form working and means each future source-taking command inherits unambiguous resolution for free.
- **Validation belongs at the read boundary, not the write boundary.** Today's path-filter checks run only inside the configure command, so a value arriving by hand-edit, by pull request, or from an older version of the extension is consumed unchecked. Moving the guarantee to the read path covers every route into the file at once — which matters more now that the configuration is committed, shared across a team, and consumed by four automatic hooks per feature cycle.
- **A stale index is worse than no index.** Leaving the previous index in place after the last source is removed would let an agent keep reading and citing knowledge the project no longer declares — a silent failure that looks like success. Deleting it also costs nothing in interface terms, because the status command already reports and explains the missing-index state.
- **The three capabilities ship together.** The freshness policy is what makes the four synchronization points introduced in 1.3.0 affordable, and revision pinning is what makes a long-lived cache safe to trust. Shipping them separately leaves the extension in a worse state than shipping none of them.
