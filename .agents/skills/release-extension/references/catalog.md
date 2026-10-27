# spec-kit community catalog

How the extension gets into, and stays current in, `extensions/catalog.community.json`
on github/spec-kit. The community site at https://speckit-community.github.io/extensions
builds from that file. It has no submission path of its own.

## Re-read upstream before each submission

The rules live in spec-kit, which changes them. Check each file's latest commits
before you rely on this page:

```bash
for p in extensions/EXTENSION-PUBLISHING-GUIDE.md extensions/EXTENSION-DEVELOPMENT-GUIDE.md \
         extensions/README.md .github/ISSUE_TEMPLATE/extension_submission.yml \
         .github/workflows/add-community-extension.md; do
  echo "== $p"; gh api "repos/github/spec-kit/commits?path=$p&per_page=2" \
    --jq '.[] | "\(.commit.author.date[0:10]) \(.commit.message | split("\n")[0])"'
done
```

`add-community-extension.md` is the bot's own instructions. It is the authority on
what gets validated. If the issue form gains, renames or drops a field, update
`FIELDS` and `CHECKBOXES` in `scripts/submission.py`.

## The process

1. **Submit through the Extension Submission issue form.** Never open a PR against
   `catalog.community.json`: spec-kit rejects those.
2. **The form labels the issue `triage-must-have` automatically.**
3. **A maintainer applies `extension-submission` during triage.** Submitters cannot
   apply it. That label starts the bot, which reads the issue body *at that moment*.
4. **The bot validates and reports with a label:**
   - It adds `validation-passed` and opens a draft PR that updates the catalog and
     `docs/community/extensions.md`.
   - Or it adds `validation-failed` and comments with each failed check.
5. **A maintainer merges the PR.** Expect 3–7 business days in total.

## What the bot rejects

- A title that does not start with `[Extension]:`.
- An id that does not match `^[a-z][a-z0-9-]*$`.
- A version that is not `X.Y.Z`, including one with a leading `v`.
- A download URL that:
  - is not `https://github.com/<owner>/<repo>/archive/refs/tags/<tag>.zip` (or a
    `releases/download/<tag>/<asset>.zip`) of the submitted repository;
  - uses `releases/latest/`;
  - has a tag whose version is not the submitted one;
  - contains characters outside `[A-Za-z0-9._~%/:-]`.
- A download that fails: anything other than HTTP 200, or no GitHub release for the tag.
- A `sha256` that is present but does not match the archive. When the field is
  absent, the bot computes and records the digest itself.
- A repository without `extension.yml`, `README.md` and `LICENSE`.
- Any of the 11 checkboxes left unticked.

The bot also checks the proposed JSON against the repository. Keep both in step with
`extension.yml`, which `submission.py` enforces.

## Which case you are in

| State | How to tell | What to do |
| --- | --- | --- |
| Not processed | Issue open, no `extension-submission` label | Edit the issue body in place (`submission.py body` + `gh issue edit`). The bot reads it only when the label lands. |
| Failed validation | `validation-failed` label, bot comment | Fix the cause, edit the issue, ask in a comment for validation to run again |
| Listed | `knowledge` in the catalog JSON (below) | New issue with `--update`. The title says "Update", and the bot keeps `created_at`, `downloads` and `stars`. |

```bash
curl -s https://raw.githubusercontent.com/github/spec-kit/main/extensions/catalog.community.json \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['extensions'].get('knowledge', {}).get('version', 'not listed'))"
```

History: first submitted as [#5137](https://github.com/github/spec-kit/issues/5137)
on 2026-10-27, filed for 1.10.0 and edited to 1.10.2 before triage.

## Gotchas met so far

- **Use a personal GitHub account.** An Enterprise Managed User account (a login like
  `name_shortcode`) cannot create issues outside its enterprise. In the browser the
  submit fails with `404` from `POST https://github.com/_ghui/issues`. Switch
  accounts. If a corporate network blocks signing in with a personal account, use
  another network.
- **Keep prefilled form URLs under about 6,600 characters.** Above that GitHub
  answers `500`. `submission.py url` refuses past 6,500.
- **Checkboxes cannot be prefilled.** Tick all 11 by hand.
- **The form wraps two fields in a code fence:** `render: markdown` (Required Tools,
  Example Usage) and `render: json` (Proposed Catalog Entry). Never put a fence
  inside them.
- **Prefer the browser form for a new issue.** `gh issue create` posts the same body
  but does not get the `triage-must-have` label the form applies.
- **The community catalog is discovery-only by default** (`install_allowed: false`).
  That is why the README leads with `specify extension add knowledge --from <zip>`.
