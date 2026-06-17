---
status: migrated
feature: xrepo-command-suite
migrated_from: commands/speckit.xrepo.configure.md, commands/speckit.xrepo.sync.md, commands/speckit.xrepo.search.md, commands/speckit.xrepo.status.md
migrated_at: 2026-06-17
---

# Feature Specification: xrepo Command Suite

**Feature Branch**: `main`

**Created**: 2026-06-17 (migrated from existing implementation)

**Status**: migrated

**Input**: Reverse-engineered from the 4 xrepo command Markdown files in `commands/`

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Configure Knowledge Sources (Priority: P1)

A developer points the extension at one or more Git repositories (remote or local) that contain specs, ADRs, or API contracts relevant to their current project. They run configure to register those repos as knowledge sources.

**Why this priority**: Configure is the entry point — no other command works without at least one source configured.

**Independent Test**: Run `speckit.xrepo.configure https://github.com/org/repo specs/` with no existing config; verify `shared-knowledge.yml` is created with the correct source entry; run again with the same URL; verify no duplicate entry is added.

**Acceptance Scenarios**:

1. **Given** no `shared-knowledge.yml` exists, **When** configure is run with a valid URL, **Then** the config file is created at `.specify/extensions/shared-knowledge/shared-knowledge.yml` with `schema_version: "1.0"` and a single source entry
2. **Given** a source with the same URL already exists, **When** configure is run with that URL again, **Then** the existing entry is updated (not duplicated)
3. **Given** a local path argument (starts with `/`, `~/`, `./`), **When** configure is run, **Then** `~` is expanded to `$HOME` before writing; the entry uses `url: <expanded-path>` (not `url:`)
4. **Given** an invalid `path_filter` (starts with `/` or contains `..`), **When** configure is run, **Then** an error is printed and no file is written
5. **Given** a local path that does not exist or is not a git repo, **When** configure is run, **Then** the corresponding error is printed and no file is written
6. **Given** `--verbose` flag is present, **When** configure completes, **Then** the full YAML content of `shared-knowledge.yml` is printed after the success message

---

### User Story 2 — Sync Knowledge Cache (Priority: P1)

A developer runs sync to fetch the latest `.md` files from all configured sources and build a local `knowledge-index.md` that spec-kit commands (`speckit-specify`, `speckit-plan`) can read.

**Why this priority**: Sync is the prerequisite for search and enables knowledge injection into spec/plan workflows.

**Independent Test**: Configure a source (local repo), run sync; verify `cache/<slug>/` directory exists with `.manifest.json`, and `knowledge-index.md` is written with correct item count.

**Acceptance Scenarios**:

1. **Given** a valid `shared-knowledge.yml` with one enabled remote source, **When** sync runs, **Then** a sparse-checkout clone is created at `cache/<slug>/`, `.manifest.json` is written last, and `knowledge-index.md` is updated
2. **Given** a `path_filter` is set, **When** sync clones the repo, **Then** only `.md` files under that path are checked out (git sparse-checkout)
3. **Given** the cache already exists (warm path), **When** sync runs again, **Then** `git fetch --depth=1 origin` is used instead of a fresh clone
4. **Given** a git clone times out (> 10s), **When** the cache is intact (manifest passes integrity check), **Then** sync falls back to `cached` status and continues without error (exit 0)
5. **Given** a source has `enabled: false`, **When** sync runs, **Then** that source is skipped silently
6. **Given** two sources contain the same relative `.md` path, **When** sync builds the index, **Then** both items are included with a `⚠️ CONFLICT` annotation; neither is silently dropped
7. **Given** a local path source, **When** sync runs, **Then** no `timeout` wrapper or `--filter=blob:none` flag is used (local clone is instant)
8. **Given** `> 10` enabled sources, **When** sync runs, **Then** a warning is printed before syncing begins (not an error)

---

### User Story 3 — Search the Knowledge Corpus (Priority: P2)

A developer searches across all synced sources for specs, ADRs, or contracts relevant to their current task.

**Why this priority**: Search is the primary consumer-facing read operation for the knowledge corpus.

**Independent Test**: Sync a source, run `speckit.xrepo.search "payment"` — verify results show matching file paths with excerpts; run with `--source <label>` — verify only that source's items appear.

**Acceptance Scenarios**:

1. **Given** a synced knowledge index, **When** search is run with a query, **Then** results show file path, topic tags (derived from path components), and a 150-char excerpt from file content
2. **Given** `--source <label>` flag, **When** search is run, **Then** only items from that source label appear
3. **Given** `--tag <tag>` flag, **When** search is run, **Then** only items whose path components include that tag appear
4. **Given** `--verbose` flag, **When** search is run, **Then** full file content replaces the excerpt for each result
5. **Given** no `knowledge-index.md` exists, **When** search is run, **Then** sync is automatically triggered before searching
6. **Given** no items match the query, **When** search returns, **Then** a "No matching items found" message is shown (exit 0)

---

### User Story 4 — View Source Status (Priority: P2)

A developer checks which knowledge sources are reachable, how stale the cache is, and how many items are indexed per source.

**Why this priority**: Operational visibility — essential for diagnosing sync failures and cache age.

**Independent Test**: Configure a source (local), sync it, run status — verify the table shows correct item count, `fresh` status, and cache age. Disable a source — verify it shows `— disabled`.

**Acceptance Scenarios**:

1. **Given** synced sources, **When** status is run, **Then** a table is printed with: source label, reachability check result, cache status (fresh/cached/not synced/corrupted), item count, cache age
2. **Given** a remote source that is reachable, **When** status checks reachability, **Then** `git ls-remote --exit-code <url> HEAD` with 5s timeout is used
3. **Given** a local path source that exists as a git repo, **When** status checks reachability, **Then** `[ -d "<path>/.git" ]` or `git -C "<path>" rev-parse` is used (no network call)
4. **Given** a source with `enabled: false`, **When** status is run, **Then** that source shows `— disabled` without a reachability check
5. **Given** `--verbose` flag, **When** status is run, **Then** each source's cached `.md` file paths are listed after its row
6. **Given** `knowledge-index.md` is absent, **When** status is run, **Then** a `⚠️ knowledge-index.md not found` warning is shown above the table

---

### Edge Cases

- What happens when `shared-knowledge.yml` has invalid YAML? → All 4 commands print a parse error and exit 0 (degraded operation)
- What happens when `schema_version` is missing or unknown? → Error printed, operation aborted, exit 0
- What happens when the cache `<slug>/` directory exists but `.manifest.json` is absent (interrupted sync)? → Integrity check fails; cache is discarded; fresh sync attempted
- What happens when conflict detection finds the same path in 3+ sources? → All are included; `⚠️ CONFLICT` shows all source labels

---

## Requirements *(mandatory)*

### Functional Requirements

**configure:**
- **FR-001**: MUST create `shared-knowledge.yml` with `schema_version: "1.0"` and empty `sources: []` if absent
- **FR-002**: MUST support both remote Git URLs (`https://...`, `git@...`) and local paths (`/`, `~/`, `./`)
- **FR-003**: MUST expand `~` to `$HOME` for local paths before writing
- **FR-004**: MUST validate `path_filter` (no absolute paths, no `..`)
- **FR-005**: MUST derive label from URL (last 3 path components: `<host>/<org>/<repo>`) or local path (last component) when not explicitly provided
- **FR-006**: MUST update existing entry (same URL) rather than append duplicate

**sync:**
- **FR-007**: MUST compute a stable 12-character slug per source URL (lowercase → SHA-256 → first 12 hex chars)
- **FR-008**: MUST use `--filter=blob:none --no-checkout --depth=1` for remote clones; no network flags for local clones
- **FR-009**: MUST apply `git sparse-checkout set <path_filter>` when `path_filter` is set
- **FR-010**: MUST write `.manifest.json` as the LAST step after all `.md` files are written (integrity signal)
- **FR-011**: MUST detect conflicts (same relative path in 2+ sources) and include both items in the index with `⚠️ CONFLICT` annotation
- **FR-012**: MUST always exit 0 — network failures cause `cached` or `unreachable` status, never a non-zero exit

**search:**
- **FR-013**: MUST derive topic tags from path components (split on `/`, strip `.md`)
- **FR-014**: MUST match query case-insensitively against path, tags, and first 500 characters of file content
- **FR-015**: MUST auto-trigger sync if `knowledge-index.md` is absent

**status:**
- **FR-016**: MUST check reachability: `git ls-remote` with 5s timeout for remote; filesystem check for local
- **FR-017**: MUST display cache age as: `< 60 min` → "N min", `1h–48h` → "Nh", `> 48h` → "Nd"
- **FR-018**: MUST skip reachability check for disabled sources

### Key Entities

- **Knowledge Source** (`shared-knowledge.yml` entry): `url` (remote or local), `label` (display name), `path_filter` (subdirectory restriction), `enabled` (default true)
- **Source Slug**: Stable 12-hex-char directory name derived from normalized URL SHA-256
- **Cache** (`.specify/extensions/shared-knowledge/cache/<slug>/`): Sparse-checkout git clone of source repo
- **Manifest** (`cache/<slug>/.manifest.json`): JSON integrity record: `schema_version`, `source_url`, `synced_at`, `item_count`, `items[]` with per-file SHA-256
- **Knowledge Index** (`.specify/extensions/shared-knowledge/knowledge-index.md`): Aggregated Markdown index of all cached items; entry point for `speckit-specify` and `speckit-plan`
- **Knowledge Conflict**: Same relative `.md` path present in 2+ sources; both included in index with warning annotation

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: `speckit.xrepo.sync` completes for a single remote source (small repo, `specs/` path_filter) in under 30 seconds on a corporate network
- **SC-002**: `speckit.xrepo.search "<query>"` returns results in under 1 second for an index with ≤ 50 items
- **SC-003**: Re-running `speckit.xrepo.sync` with an intact cache (warm path) takes < 5 seconds
- **SC-004**: All 4 commands exit 0 when `shared-knowledge.yml` is absent or malformed (degraded operation, no crashes)

---

## Assumptions

- Git 2.25+ is available for `sparse-checkout` support
- `sha256sum` (GNU) or `shasum -a 256` (macOS) is available for slug generation and manifest integrity
- The `knowledge-index.md` file is the only file `speckit-specify` and `speckit-plan` read — no direct cache access by those commands
- Remote source repos are accessible via the same network/credentials the developer uses for `git clone`
- Cache directories are local only and must be listed in `.gitignore` (not committed)
