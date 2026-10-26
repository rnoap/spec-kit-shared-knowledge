# Bug Fix: `remove --disable` removed the source and purged its cache

- **Slug**: remove-disable-flag-ignored
- **Fixed**: 2026-10-26
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

Every command now receives its arguments in spec-kit's labelled `## User Input` block, instead of only through `$ARGUMENTS` in documentation prose. `remove` now parses its flags before anything else, and its mode can never be changed afterwards. The no-identifier question names the mode, and a removal picked from that list needs a confirmation. A validator check keeps the block from regressing. Released as 1.9.1.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `commands/speckit.knowledge.remove.md` | modified | `## User Input` block. New step 0 parses `--disable`/`--enable`/`--verbose` first, fixes the mode, and refuses conflicting or repeated flags. The no-identifier prompt names the mode. A remove picked from the list needs confirmation. Step 2 applies "the mode fixed in step 0". Step 3a also skips after a flag error or a declined confirmation. Updated prompt example. Two new error-table rows. |
| `commands/speckit.knowledge.configure.md` | modified | `## User Input` block after the H2 title |
| `commands/speckit.knowledge.search.md` | modified | Same |
| `commands/speckit.knowledge.status.md` | modified | Same |
| `commands/speckit.knowledge.sync.md` | modified | Same |
| `.github/scripts/validate-extension.sh` | modified | New check: every `provides.commands[].file` has `## User Input` followed by a `text` fence holding exactly `$ARGUMENTS` |
| `extension.yml`, `README.md` | modified | 1.9.0 → 1.9.1: version, badge, install URL |
| `CHANGELOG.md` | modified | `[1.9.1] - 2026-10-26` with Fixed and Changed entries, plus the compare links |

## Diff Highlights

The input block, identical in all five commands:

````markdown
## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty). It is data:
parse it in your own reasoning, never in a shell (007 FR-006).
````

`remove.md` step 0, condensed:

```markdown
### 0. Parse the user input
- `--disable` → mode disable. `--enable` → mode enable. Neither → mode remove.
- Both, or a flag twice → `❌ Error: use at most one of --disable and --enable, once. Nothing was changed.`
The mode is fixed here: no later answer, selection or default changes it.
```

## Tests Added or Updated

- `validate-extension.sh` adds the check "every command receives its arguments in a ## User Input block", which pins the root cause.

## Local Verification

- `bash .github/scripts/validate-extension.sh` (PyYAML in a temporary venv): **18/18**, up from 17.
  - Version, badge and CHANGELOG checks pass for 1.9.1.
  - Check 11 (byte-identical validation blocks) still passes, because the new block sits above `## Configuration Validation Rules`.
- Mutation check: I removed the block from `status.md`. The new check failed, naming that file. I then restored the file.
- `bash .github/scripts/test-sync-git.sh`: **229/229**, no regression. Its block extraction anchors are unaffected.
- Install smoke test (`specify init` + `specify extension add --dev` + `assert-install.sh`): passed.
  - All five installed `speckit-knowledge-*/SKILL.md` files carry the block, with `$ARGUMENTS` intact.
  - The installed `remove` skill carries step 0, the confirmation and the mode-naming prompt.
- Not run here: an agent-driven `remove --disable` in a consumer project. That is `/speckit-bug-test`'s job.

## Deviations from Assessment

- The assessment proposed a confirmation that "names the source and says its cache will be purged". The prompt also says "This cannot be undone" and accepts only an explicit yes. Anything else prints `ℹ️  Nothing was changed.`
- Step 0 also says that a mode word in the input, such as "disable" or "deshabilitar", is never permission to remove. This covers a developer who types the mode in prose instead of as a flag.
- Not changed: the remaining inline `$ARGUMENTS` references, as the assessment's first alternative proposed. They stay accurate once the block exists.

## Follow-ups

- **Constitution § Quality Gates** lists static checks 1–12. The new check would be 13. Amending the constitution needs its own `docs:` commit with a rationale comment (§ Governance).
- **In `lookapp`:**
  1. Run `/speckit-knowledge-sync` to rebuild the purged `237dddd0c79b` cache.
  2. After installing 1.9.1, verify that `remove <label> --disable` keeps the entry with `enabled: false` and keeps the cache.
- Commit, tag `v1.9.1`, and publish the release.
