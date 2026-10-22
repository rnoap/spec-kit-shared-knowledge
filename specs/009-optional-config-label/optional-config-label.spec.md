# Optional Label for Knowledge Sources

**Date**: 2026-10-22

## User Scenarios & Testing

### User Story 1 - Choose a source label when configuring it (Priority: P1)

As a developer adding a knowledge source, I want to provide its label together with its URL or path and optional folder filters, so the source appears under a useful name from the start.

**Why this priority**: A chosen label is the core of the request and avoids manually editing the configuration after adding a source.

**Independent Test**: Configure a source with a label and one or more folder filters, then confirm the saved configuration and displayed source list use the chosen label and retain the filters.

**Acceptance Scenarios**:

1. **Given** a valid source URL, label, and folder filters, **When** the developer configures the source, **Then** the saved source uses the provided label and filters.
2. **Given** an existing source with the same URL and revision, **When** the developer configures it with a different explicit label, **Then** that source is updated with the chosen label without creating a duplicate entry.
3. **Given** a label that is already used by a different source, **When** the developer configures the source, **Then** the command identifies the conflict and requires a unique label before writing.
4. **Given** an explicit label is missing its value, empty, or contains whitespace, **When** the developer configures the source, **Then** the command reports the invalid input and writes no changes.

### User Story 2 - Keep label selection optional (Priority: P1)

As a developer who does not need a custom label, I want the command to keep deriving one automatically, so existing configure usage continues to work unchanged.

**Why this priority**: Existing users must not need to change their commands or configuration.

**Independent Test**: Configure sources using existing URL/path and filter forms without a label option, then confirm the derived labels and source configuration remain unchanged.

**Acceptance Scenarios**:

1. **Given** a valid source and no explicit label, **When** the developer configures it, **Then** the command derives the label using the existing rules.
2. **Given** a valid source with revision and folder filters, **When** the developer omits the label option, **Then** revision and filters are parsed and stored as before.
3. **Given** the command documentation, **When** a developer looks for usage examples, **Then** it shows how to provide a label with and without folder filters, and makes clear that the label is optional.

## Edge Cases

- The label option has no following value, has an empty value, or is repeated.
- The label value is whitespace-only or contains any whitespace.
- The chosen label conflicts with another source, including another revision of the same repository.
- An explicit label is supplied while updating a source with a matching URL and revision; it replaces that source's prior label if the chosen label remains unique.
- The label option appears before or after the URL/path and folder filters, without consuming a folder filter as its value.
- Existing commands omit the label option and continue using derived labels.

## Requirements

### Functional Requirements

- **FR-001**: The configure command MUST accept an optional `--label <label>` argument alongside a source URL or path and zero or more folder filters.
- **FR-002**: The configure command MUST use a supplied label for the new or matching source instead of deriving one.
- **FR-003**: The configure command MUST retain the existing label derivation behavior when the label option is omitted.
- **FR-004**: The configure command MUST validate a supplied label as non-empty, free of whitespace, and unique across configured sources before writing.
- **FR-005**: The configure command MUST report a missing, empty, whitespace-containing, repeated, or conflicting label and make no configuration changes until the input is resolved.
- **FR-006**: The configure command MUST parse the label option without changing the interpretation of the URL/path, revision, or folder filters.
- **FR-007**: The command documentation MUST explain that a label is optional and include examples of passing one with a source and with folder filters.

## Key Entities

- **Knowledge source**: A configured repository with a URL or local path, an optional revision, zero or more folder filters, and a unique label used to identify and display it.

## Success Criteria

### Measurable Outcomes

- **SC-001**: In all valid-label configure scenarios, the saved source label exactly matches the value provided by the developer.
- **SC-002**: In all existing configure scenarios without an explicit label, the derived label and stored source fields remain unchanged.
- **SC-003**: Every invalid or conflicting label scenario produces an actionable diagnostic and leaves the configuration unchanged.
- **SC-004**: The usage documentation includes at least one explicit-label example with folder filters and at least one example that omits the optional label.

## Assumptions

- The option spelling is `--label <label>`. It may appear among the URL/path, revision option, and folder filters.
- An explicit label takes precedence when updating a source with the same URL and revision; it does not rename any other source.
- Label collisions use the existing uniqueness-resolution interaction. The command writes only after the developer selects a unique label.
- Labels continue to follow the existing configuration rule: non-empty, no whitespace, and unique. No additional character restrictions are introduced.

## Approach

- Update `commands/speckit.knowledge.configure.md` to parse, validate, and persist the optional label without changing URL, revision, or folder-filter parsing.
- Update `README.md` with the optional argument and examples with and without folder filters.
- Extend `.github/scripts/validate-extension.sh` to check the documented label option, validation rules, and usage examples.
