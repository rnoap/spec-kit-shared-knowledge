---
name: release-extension
description: Release a new version of the Shared Knowledge spec-kit extension and get it into spec-kit's community catalog. Use when bumping the version, tagging, publishing a GitHub release, verifying the published archive, or filing or updating the Extension Submission issue on github/spec-kit — "cut a release", "publish 1.11.0", "update the catalog", "publicar una versión", "sacar un release".
argument-hint: "<version, e.g. 1.10.3>"
---

# Release the extension

From a green `main` to a published, verified release, and the catalog pointed at
it. Steps 1–4 publish the release. Step 5 updates spec-kit's community catalog.

## Ground rules

- **Release tags are immutable.** A repository ruleset blocks updating or deleting
  `refs/tags/v*`, with no bypass. A published release is never moved or replaced.
  Fix a bad release forward with the next patch version.
- **Confirm before anything public:** push, tag, release, and catalog issue. Each
  one is visible to others and hard to take back.
- **Version** is `X.Y.Z`, no `v`.
  - PATCH: wording in shipped files, docs or CI, with no behavior change.
  - MINOR: a new command, config key, hook or behavior.
  - MAJOR: a breaking config change, which also bumps `schema_version` in `config-template.yml`.
- **Shipped files** are what `git archive` serves: `extension.yml`, `README.md`,
  `LICENSE`, `CHANGELOG.md`, `.extensionignore`, `config-template.yml` and
  `commands/*.md`. Constitution §I: they cite no requirement IDs (static check 13).

## 1. Prepare the release commit

1. Start from an up-to-date, clean `main`: `git pull --ff-only && git status`.
2. Check for a newer spec-kit: `gh release list --repo github/spec-kit --limit 3`.
   If it is newer than `SPEC_KIT_REF` in `.github/workflows/validate.yml`, bump the
   pin in its own `ci:` commit first and let CI prove the new version.
3. Bump the version in four places:
   - `extension.yml`: `extension.version`.
   - `README.md`: the `status-vX.Y.Z` badge and the `--from …/vX.Y.Z.zip` install line.
   - `CHANGELOG.md`:
     - Rename the `[Unreleased]` content to `## [X.Y.Z] - YYYY-MM-DD` and keep an
       empty `## [Unreleased]` above it.
     - End the section with "`extension.yml` `version` bumped from `A` to `X.Y.Z`."
     - At the bottom, point `[Unreleased]` at `compare/vX.Y.Z...HEAD` and add
       `[X.Y.Z]: …/releases/tag/vX.Y.Z`.
   - If the command files and `config-template.yml` did not change, say so in one
     line under the version heading. Users decide whether to upgrade on it.
4. `bash .github/scripts/validate-extension.sh` must pass every check. It needs
   `python3` with PyYAML. If `commands/speckit.knowledge.sync.md` changed, also run
   `bash .github/scripts/test-sync-git.sh`.
5. Commit as `chore(release): X.Y.Z` (Conventional Commits, constitution §IV).

## 2. Land it, and wait for CI on that exact commit

Push to `main`, or merge a PR. An admin's direct push bypasses the required checks,
so CI may still be running. **Never tag before CI is green on that commit:**

```bash
sha=$(git rev-parse HEAD)
id=$(gh run list --commit "$sha" --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status
```

All three jobs must pass: Static validation, Install smoke test, and Install smoke
test (minimum spec-kit).

## 3. Tag and publish

```bash
git tag -a vX.Y.Z -m "Shared Knowledge vX.Y.Z" "$sha"
git push origin vX.Y.Z
gh release create vX.Y.Z --verify-tag --title "Shared Knowledge vX.Y.Z" --notes-file notes.md --latest
```

Release notes follow the earlier releases (`gh release view v1.10.0`):

- **Opening paragraph:** what changes for a user, in plain words. If behavior is
  unchanged, say so.
- **Install:** `specify extension add knowledge --from <tag archive URL>`, noting
  that spec-kit shows an `Untrusted Source` prompt first.
- **Upgrade note:** `specify extension add` recreates the extension folder and keeps
  only `knowledge-config.yml`, so the first sync rebuilds every source.
- **Body:** `## Added`, `## Changed` and `## Fixed`, with bold-lead bullets.

## 4. Verify what was published

```bash
bash .agents/skills/release-extension/scripts/verify-release.sh X.Y.Z
```

The script checks that:

- the release is published;
- the tag archive's SHA-256 is stable across two downloads;
- the archive holds exactly the files of `git archive vX.Y.Z`, with no dev-only path
  and no requirement ID;
- it installs from its URL into a clean project, and `assert-install.sh` passes
  against the released manifest.

It prints the `download_url` and `sha256` that step 5 needs. If any check fails,
fix forward with a new patch version.

## 5. Point the catalog at it

Read [references/catalog.md](references/catalog.md) first. Then:

1. Find out where the catalog submission stands:
   - **Never submitted:** file a new submission.
   - **Submitted but not processed yet:** the issue has no `extension-submission`
     label. Edit that issue in place.
   - **Listed:** `knowledge` is in `extensions/catalog.community.json`. File a new
     issue marked as an update.
2. Render the submission from
   [references/submission-template.md](references/submission-template.md):

   ```bash
   S=.agents/skills/release-extension/scripts/submission.py
   python3 $S check --version X.Y.Z                 # validate only
   python3 $S url   --version X.Y.Z [--update]      # new issue: open in the browser
   python3 $S body  --version X.Y.Z > body.md       # unprocessed issue: edit in place
   gh issue edit <n> --repo github/spec-kit --body-file body.md
   ```

   `submission.py` reads the released `extension.yml` from the archive. It refuses
   to render if the template disagrees with that manifest or with the catalog
   bot's rules.
3. **Opening a new issue:** open the URL from `url` in a browser signed in with the
   maintainer's **personal** GitHub account, tick the 11 checkboxes, and submit.
   The browser form applies the `triage-must-have` label; `gh issue create` would not.

## When something changes

| What changed | Update |
| --- | --- |
| A feature, tool requirement or test setup | `references/submission-template.md` |
| spec-kit's catalog rules or issue form | `references/catalog.md` and `scripts/submission.py` (`FIELDS`, `CHECKBOXES`) |
| A file added to the package | `.gitattributes` (archive), `.extensionignore` (installed copy), static check 9 |
