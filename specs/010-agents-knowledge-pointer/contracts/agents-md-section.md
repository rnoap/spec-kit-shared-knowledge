# Contract: The knowledge section in `AGENTS.md`

**Feature**: [../agents-knowledge-pointer.spec.md](../agents-knowledge-pointer.spec.md) · **Plan**: [../plan.md](../plan.md) · **Research**: [../research.md](../research.md)

This is the exact text `speckit.knowledge.sync` and `speckit.knowledge.remove` keep in the consumer project's root `AGENTS.md`.
Both commands produce it through `§ Agent Context Section` in `speckit.knowledge.sync.md` ([research R4](../research.md#r4-one-procedure-defined-in-sync)).
Command prose cites this feature's requirements as `010 FR-001`.

---

## 1. The section

Shown with two enabled sources, `payment-service` and `identity-service`:

```markdown
<!-- KNOWLEDGE START -->
## Shared knowledge

For any question about another repository or a knowledge source listed below:

1. Read `.specify/extensions/knowledge/knowledge-index.md` first.
2. Open the `.md` files it lists for those sources, from `.specify/extensions/knowledge/cache/<slug>/`.
3. Cite borrowed information as `<label> › <relative-path>`.
4. When the index marks an item `⚠️ CONFLICT`, show every version present and flag the conflict to the user.
5. Use only the sources listed below, and ignore index entries for any other source.
6. If the index, a source's entries, or a listed file is missing, suggest running the knowledge sync command, `speckit.knowledge.sync`, instead of guessing.

Sources:
- `payment-service`
- `identity-service`
<!-- KNOWLEDGE END -->
```

Every line above is literal, except the label lines.

| Part | Rule |
| --- | --- |
| Start marker | `<!-- KNOWLEDGE START -->`, alone on its line |
| End marker | `<!-- KNOWLEDGE END -->`, alone on its line |
| Fixed lines | The 12 lines from `## Shared knowledge` through `Sources:`, byte for byte (FR-004, SC-005) |
| Index path | `.specify/extensions/knowledge/knowledge-index.md`, project-relative (FR-008) |
| Citation format | `<label> › <relative-path>`, with U+203A between single spaces (FR-002) |
| Sync command | `speckit.knowledge.sync`, the canonical id. Not the install-rendered token: that differs per host, and the section is committed and shared (FR-007) |
| Label lines | One per label, after `Sources:` and before the end marker (FR-003) |
| Line endings | Each line ends with a line feed. No line has trailing whitespace. |

Items 1 to 4 restate items 1 to 4 of the `SHARED KNOWLEDGE CONTEXT` block in sync step 10.
Item 5 limits the agent to the listed sources (FR-003, SC-006).
Item 6 covers a fresh clone, a newly enabled source and a deleted cache file (FR-002).

The section holds no timestamp, count, absolute path or source content (FR-008).
The same configuration therefore produces the same bytes on every host (FR-007, SC-002).

---

## 2. Label lines

- **Which labels**: the enabled sources that pass § Configuration Validation Rules, in configuration order ([research R7](../research.md#r7-labels-in-the-section)).
- **Form**: `- ` followed by the label in a code span.
- **Escaping**: escape the label first under § Values in messages (007 FR-005).
- **Backticks**: when the label contains a backtick, use a code-span delimiter longer than its longest backtick run.
- **Edge backticks**: when the label begins or ends with a backtick, put one space inside each delimiter.

```text
label              line
payment-service    - `payment-service`
a-->b              - `a-->b`
x`y                - ``x`y``
`tick              - `` `tick ``
```

A label line always starts with `- `, so it can never equal a marker line (FR-013).
A code span keeps markdown and comment syntax in a label inert.

---

## 3. Markers

Markers match only as whole lines ([research R3](../research.md#r3-markers)).

| `AGENTS.md` holds | State |
| --- | --- |
| No file, or no marker line | Absent |
| Exactly one start line, then exactly one end line | Present |
| Any other combination | Damaged |

A damaged file is never written (FR-011).
The `<!-- SPECKIT START -->` and `<!-- SPECKIT END -->` block of the `agent-context` extension is ordinary content here.

---

## 4. Write and remove

The agent's file-writing tool applies these rules, never a shell ([research R5](../research.md#r5-placement-replacement-and-removal)).

| Mode | State | Result |
| --- | --- | --- |
| Write | No file, or only whitespace | Write `AGENTS.md` holding only the section (FR-005) |
| Write | Absent | Ensure the file ends with a line feed, add one empty line, then append the section |
| Write | Present, same bytes | Do not write the file (FR-007) |
| Write | Present, different bytes | Replace the start-to-end lines in place |
| Remove | Present | Delete the start-to-end lines and one empty line directly above them, if any |
| Remove | Present, nothing else left | Delete the file when only whitespace remains |
| Remove | Absent or no file | Do nothing |
| Either | Damaged | Do nothing and warn ([commands.md § 3](./commands.md#3-report-lines)) |

Every byte outside the section stays unchanged (FR-006, SC-003).
A write followed by a remove leaves the file as it was, apart from a final line feed the write added to a file that lacked one.
