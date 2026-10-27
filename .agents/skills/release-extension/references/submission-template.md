<!--
Source of the Extension Submission issue for github/spec-kit's community catalog.
`scripts/submission.py` fills the {{PLACEHOLDERS}}, checks every field against
extension.yml, and refuses to render on any disagreement. Edit this file when a
feature, a tool requirement or the test setup changes; never edit an issue by hand
without bringing the change back here.

Placeholders: {{VERSION}} {{DOWNLOAD_URL}} {{SHA256}} {{DATE}} {{TESTED_ON}}
{{SPECKIT_CI}} {{ARCHIVE_FILES}}. Section headings are the form's field labels.
-->

### Extension ID
knowledge

### Extension Name
Shared Knowledge

### Version
{{VERSION}}

### Description
Inject cross-repo decisions, contracts, and conventions into your spec-kit workflow.

### Author
Raúl Noa Pedroso

### Repository URL
https://github.com/rnoap/spec-kit-shared-knowledge

### Download URL
{{DOWNLOAD_URL}}

### License
MIT

### Homepage
https://github.com/rnoap/spec-kit-shared-knowledge

### Documentation URL
https://github.com/rnoap/spec-kit-shared-knowledge/blob/main/README.md

### Changelog URL
https://github.com/rnoap/spec-kit-shared-knowledge/blob/main/CHANGELOG.md

### Required Spec Kit Version
>=0.15.2

### Required Tools
- git (>=2.25) - required
- timeout, gtimeout or perl - optional (bounds network calls)

### Number of Commands
5

### Number of Hooks
4

### Tags
cross-repo, knowledge, context, shared-decisions, contracts

### Key Features
- Declare other Git repos (HTTPS, SSH or local paths) as knowledge sources in a committed `knowledge-config.yml`
- Sparse, `.md`-only checkout scoped by `path_filter` (e.g. `specs/`, `docs/decisions/`)
- Optional `before_specify`, `before_clarify`, `before_plan` and `before_tasks` hooks refresh the cache so specs, plans and tasks reflect current contracts
- Per-source revision pinning: branch, tag or full commit SHA
- Cache freshness policy, with offline fallback to the last cached copy
- Context budget (`max_items` / `max_bytes`) with a deterministic rule; nothing is withheld silently
- Conflict detection when two sources ship the same path
- Remove, disable or re-enable a source without editing YAML
- Search and status commands
- Keeps a pointer section in `AGENTS.md` so agents answer cross-repo questions in plain chat
- Documented trust model: fetched content is data and never executed; config is validated on every read

### Testing Details
**Tested on:**
- {{TESTED_ON}}
- CI (Ubuntu) on every PR and push to main: static package checks, plus install smoke tests on Spec Kit {{SPECKIT_CI}} and on the declared minimum, 0.15.2

**Test project:** a clean `specify init` project, installing from the download URL above

**Test scenarios:**
1. `specify extension add knowledge --from <download URL>` succeeds after the Untrusted Source prompt
2. 10 files installed under `.specify/extensions/knowledge/`, no dev-only files
3. 5 commands registered and `knowledge-config.yml` scaffolded
4. 4 optional hooks registered, none with arguments

### Example Usage
# Install
specify extension add knowledge --from {{DOWNLOAD_URL}}

# Declare a source, scoped to the folders you need
/speckit.knowledge.configure https://github.com/your-org/payment-service specs/ docs/decisions/

# Fetch and index it, then search it or just run /speckit.specify
/speckit.knowledge.sync
/speckit.knowledge.search "payment session"

### Proposed Catalog Entry
{
 "knowledge": {
  "name": "Shared Knowledge",
  "id": "knowledge",
  "description": "Inject cross-repo decisions, contracts, and conventions into your spec-kit workflow.",
  "author": "Raúl Noa Pedroso",
  "version": "{{VERSION}}",
  "download_url": "{{DOWNLOAD_URL}}",
  "sha256": "{{SHA256}}",
  "repository": "https://github.com/rnoap/spec-kit-shared-knowledge",
  "homepage": "https://github.com/rnoap/spec-kit-shared-knowledge",
  "documentation": "https://github.com/rnoap/spec-kit-shared-knowledge/blob/main/README.md",
  "changelog": "https://github.com/rnoap/spec-kit-shared-knowledge/blob/main/CHANGELOG.md",
  "license": "MIT",
  "category": "integration",
  "effect": "read-write",
  "requires": {
   "speckit_version": ">=0.15.2",
   "tools": [{"name": "git", "version": ">=2.25", "required": true}]
  },
  "provides": {"commands": 5, "hooks": 4},
  "tags": ["cross-repo", "knowledge", "context", "shared-decisions", "contracts"],
  "verified": false,
  "downloads": 0,
  "stars": 0,
  "created_at": "{{DATE}}T00:00:00Z",
  "updated_at": "{{DATE}}T00:00:00Z"
 }
}

### Additional Context
- The download URL is the tag archive. `.gitattributes` `export-ignore` keeps this repo's own spec-kit workspace out of it, so it holds {{ARCHIVE_FILES}} files. Its SHA-256 is in the proposed entry.
- All 4 hooks are `optional: true` and take no arguments.
- The README documents a trust model for `knowledge-config.yml`, including prompt injection and credential exposure.
