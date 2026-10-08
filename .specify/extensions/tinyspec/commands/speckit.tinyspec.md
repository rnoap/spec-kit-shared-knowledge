---
description: "Generate a single lightweight spec file with context, plan, and tasks for small changes"
---

# TinySpec

Generate a single lightweight specification file for small tasks that don't warrant the full SDD workflow. Combines context, requirements, implementation plan, and tasks into one concise document — minimal overhead, maximum clarity.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty). The user describes the small change they want to make (e.g., "add a logout button to the navbar", "fix the date format in the invoice PDF", "add input validation to the signup form").

## Prerequisites

1. Verify a spec-kit project exists by checking for `.specify/` directory
2. Verify git is available and the project is a git repository
3. Verify the user has described the change (if not, ask what they want to build)

<!-- spec-kit-walmart:tiny-numbering START -->
## Numbered file name (MANDATORY)

<!-- Managed by the spec-kit-walmart plugin; /speckit-update re-applies it. -->

Every tiny spec is `specs/tiny/NNN-<feature-name>.md`. Reserve the number with
the spec-kit-walmart plugin's helper before you write the file — never invent it
or use a PR number (the PR does not exist yet). Unless `CLAUDE_PLUGIN_ROOT` is
set, set `SPECKIT_RUNTIME` first: `wibey` or `code_puppy` — the assistant you
are, or, if you are neither, whichever of the two has the plugin on this machine.

```bash
bash "${CLAUDE_PLUGIN_ROOT:-$HOME/.$SPECKIT_RUNTIME/plugins/spec-kit-walmart}/skills/speckit-setup/scripts/next-tiny-number.sh" --slug "<feature-name>"
# -> specs/tiny/NNN-feature-name.md
```

- Create the file at exactly the printed path. Wherever the steps below say
  `specs/tiny/{NNN}-{feature-name}.md`, they mean that path.
- The helper first numbers any older tiny spec that has no prefix yet and
  rewrites the links to it, printing one `TINY_SPEC_RENAME=` line per file.
  List those renames in your report — they belong in the same commit.
- Plugin not installed: use one above the highest `NNN-` prefix in `specs/tiny/`,
  zero-padded to three digits, after checking `git worktree list` for an
  uncommitted `specs/tiny/NNN-*` in another checkout. Leave unnumbered files to
  `/speckit-update`. Never create an unnumbered file.
<!-- spec-kit-walmart:tiny-numbering END -->

## Outline

1. **Assess scope**: Quickly evaluate whether this task is appropriate for tinyspec:
   - **Good fit**: Single feature, bug fix, UI tweak, config change, small refactor — anything that touches 1-5 files and takes under ~1 hour
   - **Bad fit**: Multi-module features, architectural changes, new services, database schema redesigns — recommend full `/speckit.specify` instead
   - If the task seems too large, warn the user and suggest the full workflow

2. **Identify affected files**: Scan the codebase to determine:
   - Which files will be modified (list them explicitly)
   - Which files provide context (imports, types, related components)
   - Which test files will need updates

3. **Generate tinyspec file**: Create a single file at `specs/tiny/{NNN}-{feature-name}.md` with this structure:

   ```markdown
   # TinySpec: {Title}

   **Branch**: {current-branch or new-branch-name}
   **Date**: {YYYY-MM-DD}
   **Status**: draft
   **Complexity**: small

   ## What

   {1-3 sentence description of what this change does and why}

   ## Context

   | File | Role |
   |------|------|
   | `src/components/Navbar.tsx` | Will be modified — add logout button |
   | `src/hooks/useAuth.ts` | Context — provides logout function |
   | `src/components/Navbar.test.tsx` | Will be modified — add test for logout |

   ## Requirements

   1. {Requirement 1 — clear, testable}
   2. {Requirement 2}
   3. {Requirement 3}

   ## Plan

   1. {Step 1 — what to change and where}
   2. {Step 2}
   3. {Step 3}

   ## Tasks

   - [ ] {Task 1}
   - [ ] {Task 2}
   - [ ] {Task 3}
   - [ ] {Test task}

   ## Done When

   - [ ] All tasks checked off
   - [ ] Tests pass
   - [ ] No lint errors
   ```

4. **Report**:

   ```markdown
   # TinySpec Created

   | Field | Value |
   |-------|-------|
   | **File** | `specs/tiny/{NNN}-{feature-name}.md` |
   | **Tasks** | {N} tasks |
   | **Files affected** | {N} files |

   ## Next Steps
   - Review the tinyspec at `specs/tiny/{NNN}-{feature-name}.md`
   - Run `/speckit.tinyspec.implement` to build it
   - Or implement manually — the spec is your checklist
   ```

## Rules

- **One file only** — never generate separate spec.md, plan.md, tasks.md for tinyspec
- **Keep it short** — the entire tinyspec should be under 80 lines
- **No boilerplate** — skip sections that add no value for this specific task
- **Concrete file references** — always list the actual files that will be changed
- **Testable requirements** — every requirement must be verifiable
- **Warn on scope creep** — if the task grows beyond 5 files or 10 tasks, recommend upgrading to full SDD
- **Respect constitution** — follow project conventions from `.specify/memory/constitution.md`
