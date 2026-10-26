# Bug Assessment: `remove --disable` removed the source and purged its cache

- **Slug**: remove-disable-flag-ignored
- **Created**: 2026-10-26
- **Source**: pasted text + 8 screenshots (consumer project `lookapp`, extension 1.9.0, GitHub Copilot in VS Code, skills mode)
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

> porque no interpretó bien el flag de disable??

The screenshots show this sequence:

1. The developer ran `/speckit-knowledge-remove LOOKAPP-api-store-visibility --disable`.
2. Partway through that run (10:37), the agent showed a picker titled **"Source to remove"**, listing all three sources as `enabled`. Its text read: *"No action has been taken yet. Select the source to remove (the default mode; its cache will be purged only if its generated slug validates)."*
3. The run then reported:
   - `✅ Removed source LOOKAPP-api-store-visibility from knowledge-config.yml`
   - `✅ Purged cache directory 237dddd0c79b`
   - `✅ Updated the shared knowledge section in AGENTS.md`

   The entry was deleted from `knowledge-config.yml`.
4. The developer asked why it removed the source when `--disable` was passed. The agent admitted it "interpreted the arguments wrongly and executed the default mode (remove)". It restored the entry with `enabled: false`, but the cache could not be restored.

## Symptom

**Observed:**
- With a label and `--disable` in the invocation, the agent did not recognise either one.
- It fell into the "no identifier" path and prompted for a source, framed as a removal.
- It then ran the destructive default mode: it deleted the entry and purged the cache.

**Expected:** the source stays in `knowledge-config.yml` with `enabled: false`, its cache is retained, and the agent prompts for nothing.

## Reproduction

1. Install extension 1.9.0 into a project with the Copilot integration in skills mode (`specify init --integration copilot --integration-options="--skills"`).
2. Configure at least two sources and sync.
3. Run `/speckit-knowledge-remove <label> --disable`.
4. Observe the result: in the reported run, the source picker appeared, and default removal plus a cache purge followed.

The trigger is not deterministic. It depends on whether the model locates the arguments (see Root Cause). `search` with a query and `--source` worked in the same project and session.

## Suspected Code Paths

- **`commands/speckit.knowledge.{configure,remove,search,status,sync}.md`: no `## User Input` block.**
  - Every core spec-kit command ships the block below near the top. Its skills-mode rendering keeps it: `.github/skills/speckit-plan/SKILL.md` and 31 more of this repo's installed skills have it.
    ````markdown
    ## User Input

    ```text
    $ARGUMENTS
    ```

    You **MUST** consider the user input before proceeding (if not empty).
    ````
  - All five knowledge skills installed in `lookapp/.github/skills/speckit-knowledge-*/SKILL.md` lack it.
  - The only place `$ARGUMENTS` appears early is inside prose that reads as documentation: `**Arguments**: \`$ARGUMENTS\` — an optional source identifier, plus optional flags:` (`remove.md:15`). The host substitutes the user's text there. A model reading a reference line does not take it as the input to act on.
- **`commands/speckit.knowledge.remove.md` § Behavior (lines ~75–100): no argument-parsing step.**
  - `configure.md` step 2 explicitly strips `--verbose`, then extracts `--revision` and `--label` before identifying the URL.
  - `search.md` step 2 ("Parse arguments") splits the query from the flags.
  - `remove.md` starts at "1. Resolve the source". The mode exists only in the step 2 table and in the header bullet list. Nothing tells the agent to settle the mode first.
- **`commands/speckit.knowledge.remove.md:98`: "When `$ARGUMENTS` contains no identifier, print the source list … and prompt."**
  - The prompt does not name the mode, so the answer carries none, and step 2 then applies the default destructive mode.
  - The reported prompt said "Source to remove … (the default mode)".
- **`commands/speckit.knowledge.remove.md` step 2: the default mode purges at once, with no confirmation.**
  - This holds even when the target came from that interactive picker rather than from the invocation.
- **`.github/scripts/validate-extension.sh`:** no check that each command carries the `## User Input` block. Nothing would catch a regression.

## Root Cause Hypothesis

Confidence: **high** for the mechanism, **medium** for which of the first two factors dominated in this run.

Arguments reach a skill only through `$ARGUMENTS` substitution. In these commands the placeholder sits in documentation prose rather than a labelled input block, so the model can miss that the user supplied an identifier and flags.

Once it misses them:
- `remove`'s only explicit instruction is the no-identifier fallback, which lists sources and prompts.
- The mode is never parsed as a first step, so the picker carries no mode.
- The destructive default applies without confirmation.

`search` worked because it has no such fallback: it must find a query, and its step 2 says how. The cache loss is the part that cannot be undone. For a local source it is rebuilt by the next sync. For a remote one, a re-clone is needed.

## Proposed Remediation

**Preferred**:

1. **Add the spec-kit `## User Input` block to all five commands**, right after the H2 title, with the same wording as core spec-kit. Add one sentence: the input is data, parsed in the agent's own reasoning and never handed to a shell (007 FR-006).
   - `extension.yml` declares no hook arguments, so an automatic hook run gets an empty input and nothing changes for it.
2. **`remove.md`: add step "0. Parse the user input"** before "1. Resolve the source".
   - Read `--disable`, `--enable` and `--verbose` from the user input first.
   - Set the mode: `--disable` → disable, `--enable` → enable, neither → remove.
   - Both flags at once, or a flag repeated, is an error that changes nothing.
   - The remaining token is the identifier.
   - The mode is fixed here and never re-derived from a later answer.
3. **`remove.md`: name the mode in the no-identifier prompt**, for example "Which source should I disable?". The answer then never changes the mode.
4. **`remove.md`: confirm before a purge that the invocation did not name.**
   - When the remove target came from the picker rather than the invocation, ask once before deleting the entry and its cache. The prompt names the source and says its cache will be purged.
   - A declined confirmation changes nothing.
   - An identifier named in the invocation keeps today's immediate removal.
5. **`validate-extension.sh`: new check** that every `provides.commands[].file` contains a `## User Input` heading followed by a ```` ```text ```` block holding exactly `$ARGUMENTS`.
6. **Release 1.9.1**: bump `extension.yml`, the README badge and install URL, and add a CHANGELOG `[1.9.1]` `Fixed` entry.

**Alternatives**:

- **Rewrite every `$ARGUMENTS` reference as "the user input".** This is cleaner prose, but it touches about 16 lines across five files for no behavioral gain once the block exists. The existing references stay accurate.
- **Make `--disable` the default and require `--force` to remove.** This changes the command's public contract and the README. Too broad for a patch release.

**Files likely to change**:

- `commands/speckit.knowledge.configure.md`
- `commands/speckit.knowledge.remove.md`
- `commands/speckit.knowledge.search.md`
- `commands/speckit.knowledge.status.md`
- `commands/speckit.knowledge.sync.md`
- `.github/scripts/validate-extension.sh`
- `extension.yml`, `README.md`, `CHANGELOG.md`

**Tests to add or update**:

- **Validator check: every command has the User Input block.**
  - Mutation check: deleting the block from one command makes the check fail.
- **Validator check 11 still passes.** The new block sits above `## Configuration Validation Rules`, so the byte-identical span is unchanged.
- **Install smoke test.** Each installed `speckit-knowledge-*/SKILL.md` carries the block.
- **Manual, in `lookapp`:**
  - `remove <label> --disable` leaves the entry with `enabled: false` and its cache in place, and prompts for nothing.
  - `remove --disable` with no label asks "Which source should I disable?".
  - `remove` with no label, then picking a source, asks for confirmation before purging.

## Risks & Considerations

- **Data loss is the impact.** The cache purge is irreversible within the command. A remote source needs network access to rebuild. The config entry was restorable only because the agent rewrote it by hand.
- **Hook paths.** Hooks run sync with no arguments. An empty User Input block must keep today's behavior. Spec-kit's own commands rely on the same convention.
- **Prompt injection.** The User Input block places raw user text in the prompt. It is already the user's own instruction. The added sentence keeps it as data for parsing, never shell text, consistent with 007.
- **Model variance.** The fix makes argument location explicit and removes the silent destructive fallback. It cannot guarantee that every model parses perfectly. The confirmation step bounds the damage when it does not.

## Open Questions

None.
