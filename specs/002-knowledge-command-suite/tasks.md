---
status: migrated
feature: knowledge-command-suite
---

# Tasks: Knowledge Command Suite

**Input**: `specs/002-knowledge-command-suite/spec.md`, `specs/002-knowledge-command-suite/plan.md`

**Note**: All tasks marked `[x]` — implementation is complete. Migrated on 2026-06-17.

**Gaps identified**: See end of file.

---

## Phase 1: Setup

**Purpose**: Scaffold 4 command files with frontmatter and section headers

- [x] T001 Create `commands/speckit.knowledge.configure.md` with YAML frontmatter and section headings (Behavior, Error Cases, Side Effects, Exit Codes)
- [x] T002 [P] Create `commands/speckit.knowledge.sync.md` with YAML frontmatter, Algorithm Reference section, Behavior section, Error Cases Summary, Side Effects
- [x] T003 [P] Create `commands/speckit.knowledge.search.md` with YAML frontmatter and section headings
- [x] T004 [P] Create `commands/speckit.knowledge.status.md` with YAML frontmatter and Algorithm Reference cross-reference

---

## Phase 2: Foundational — Shared Infrastructure

**Purpose**: Define the shared algorithms used by sync and status before implementing either

- [x] T005 Implement **Source Slug Generation** algorithm in `speckit.knowledge.sync.md`: normalize URL (strip `.git`, trailing slash, lowercase) → SHA-256 → first 12 hex chars; Bash pseudocode with macOS fallback
- [x] T006 Implement **Cache Integrity Check** algorithm in `speckit.knowledge.sync.md`: verify `.manifest.json` exists + valid JSON + `item_count` matches file count + per-file SHA-256 matches; 5-step pass/fail logic
- [x] T007 Define **`knowledge-index.md` format** in sync Algorithm Reference: HTML comment header, source section per entry, status line, conflict footer

**Checkpoint**: Shared algorithms documented and stable. Both sync and status can now be implemented.

---

## Phase 3: User Story 1 — configure (Priority: P1)

**Goal**: Developer can add, update, and view knowledge sources in `knowledge.yml`

- [x] T008 [US1] Implement config file creation: check for `knowledge.yml`, create with `schema_version: "1.0"` + `sources: []` if absent (copy from extension `config-template.yml`)
- [x] T009 [US1] Implement argument parsing: first token = URL or local path, second token = `path_filter`, remaining = flags
- [x] T010 [US1] Implement URL type detection (local path vs remote URL) and `~` expansion
- [x] T011 [US1] Implement label derivation: local path → last component; remote URL → strip `.git` + last 3 path components (`<host>/<org>/<repo>`)
- [x] T012 [US1] Implement `path_filter` validation (reject absolute paths and `..` traversal)
- [x] T013 [US1] Implement local path validation: check directory exists, check `.git` subdirectory present
- [x] T014 [US1] Implement upsert logic: if source with same URL exists, update `path_filter`/`label` in-place; else append new entry
- [x] T015 [US1] Implement config display (numbered sources list) and write on confirmation
- [x] T016 [US1] Implement `--verbose` flag (print full YAML after write)
- [x] T017 [US1] Document all error cases table (invalid path_filter, local path absent, invalid YAML, missing schema_version)

**Checkpoint**: `speckit.knowledge.configure` fully implemented. Developer can configure both remote and local sources.

---

## Phase 4: User Story 2 — sync (Priority: P1)

**Goal**: Developer can sync all configured sources and build a knowledge index

- [x] T018 [US2] Implement config read and validation (absent file → error, invalid YAML → error, missing `sources` → error, unknown schema_version → error)
- [x] T019 [US2] Implement source-count warning (> 10 enabled sources)
- [x] T020 [US2] Implement cold path (fresh clone) for remote URL sources: `git clone --filter=blob:none --no-checkout --depth=1` with 10s timeout
- [x] T021 [US2] Implement cold path for local path sources: `git clone --no-checkout` (no timeout, no blob filter)
- [x] T022 [US2] Implement `path_filter` sparse-checkout: `git sparse-checkout init --cone` + `git sparse-checkout set <path_filter>` + `git checkout`; checkout all if no filter
- [x] T023 [US2] Implement warm path (update): remote → `git fetch --depth=1 origin` + `git checkout origin/HEAD -- .`; local → `git fetch origin` + checkout
- [x] T024 [US2] Implement timeout/failure handler: run Cache Integrity Check on existing cache; fallback to `cached` if intact; mark `unreachable` if absent/corrupted
- [x] T025 [US2] Implement `.md` file indexing: recurse `cache/<slug>/` under path_filter; record relative path + SHA-256 per file
- [x] T026 [US2] Implement `.manifest.json` write (last step): `schema_version`, `source_url`, `source_slug`, `synced_at` (ISO8601), `item_count`, `items[]`
- [x] T027 [US2] Implement conflict detection: compare relative paths across all sources; record `KnowledgeConflict` for duplicates; include both items
- [x] T028 [US2] Implement `knowledge-index.md` assembly and write: HTML comment header, per-source sections, conflict footer
- [x] T029 [US2] Implement per-source status output lines (fresh/cached/unreachable) and final summary line
- [x] T030 [US2] Implement `--verbose` flag (list files loaded per source)

**Checkpoint**: `speckit.knowledge.sync` fully implemented. Cache + index populated. Both `search` and `status` can be implemented.

---

## Phase 5: User Story 3 — search (Priority: P2)

**Goal**: Developer can search the knowledge corpus with text query + filters

- [x] T031 [US3] Implement knowledge-index.md load; auto-trigger sync if absent; error if sync also fails
- [x] T032 [US3] Implement argument parsing: query tokens vs flags (`--source`, `--tag`, `--verbose`)
- [x] T033 [US3] Implement tag derivation: split path on `/`, strip `.md` extension from last component
- [x] T034 [US3] Implement filter pipeline: `--source` filter → `--tag` filter → text match (path + tags + first 500 chars of content)
- [x] T035 [US3] Implement results display: path, tags, last-modified, 150-char excerpt per item; CONFLICT annotation when applicable
- [x] T036 [US3] Implement `--verbose` flag (full file content instead of excerpt)
- [x] T037 [US3] Implement "no results" message with sync suggestion

**Checkpoint**: `speckit.knowledge.search` fully implemented. All filter/flag combinations work.

---

## Phase 6: User Story 4 — status (Priority: P2)

**Goal**: Developer can view per-source reachability, cache freshness, and item counts

- [x] T038 [US4] Implement config read with "not configured" message if absent
- [x] T039 [US4] Implement manifest read per source: derive slug, read `cache/<slug>/.manifest.json`; handle absent (not synced) and invalid JSON (corrupted)
- [x] T040 [US4] Implement cache age calculation: `< 60 min` → "N min"; `1h–48h` → "Nh"; `> 48h` → "Nd"
- [x] T041 [US4] Implement reachability check: remote → `git ls-remote --exit-code <url> HEAD` with 5s timeout; local → filesystem check
- [x] T042 [US4] Skip reachability for `enabled: false` sources; show `— disabled`
- [x] T043 [US4] Implement status table output with box-drawing characters
- [x] T044 [US4] Implement summary line (total items, counts by status)
- [x] T045 [US4] Add `⚠️ knowledge-index.md not found` warning if index is absent
- [x] T046 [US4] Implement `--verbose` flag (list cached file paths per source)

**Checkpoint**: All 4 commands fully implemented.

---

## Phase N: Polish

- [x] TXXX Add cross-reference in `status.md` to `sync.md § Algorithm Reference` (avoid duplication)
- [x] TXXX Add `--verbose` flag consistently across all 4 commands with command-specific output

---

## Gaps Identified

| Gap | Severity | Recommendation |
|-----|----------|---------------|
| No automated tests for any command | High | Create `tests/` directory; write integration tests that configure a local git repo as source and verify sync/search/status output |
| No CI/CD pipeline | High | Add Looper or GitHub Actions workflow; run tests on push to main |
| No timeout test coverage for sync | Medium | Integration test: mock a slow remote (or use `git daemon` with firewall) to verify `cached` fallback behavior |
| `speckit.knowledge.search` reads first 500 chars of each file for matching — O(N×M) for large corpora | Low | Document performance limit in README; consider index pre-built text excerpts in knowledge-index.md |
| No support for SSH key authentication in configure/sync (relies on system git config) | Low | Document SSH key setup requirement in README |
| ~~`knowledge-index.md` format is not versioned (no schema_version)~~ | ~~Low~~ | ✅ Fixed — `schema_version=1.0` added to the HTML comment header in `speckit.knowledge.sync.md` |
