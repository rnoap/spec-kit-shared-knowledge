# Research: Catalog Readiness

Every decision below was settled from the codebase, spec-kit's source and changelog, or a run on 2026-10-14. No `NEEDS CLARIFICATION` remained in the spec.

## 1. The floor is `>=0.15.2`

**Decision**: Declare `requires.speckit_version: ">=0.15.2"`.

**Rationale**: spec-kit 0.15.2 is the first release that scaffolds config templates on `extension add` (spec-kit #2000). On 0.10.0 the install ran, but `knowledge-config.yml` was missing. Skills have rendered `__SPECKIT_COMMAND_*__` tokens since 0.12.17 (#3544), so 0.15.2 covers both. Installs passed on 0.15.2, on 1.1.2 from the release zip, and on 1.2.0. spec-kit refuses an install below `requires.speckit_version` and names the version it needs (`check_compatibility` in the 1.1.2 source), so raising the floor turns a half-working install into a clear refusal.

**Alternatives considered**: `>=0.12.17` renders tokens but leaves the config unscaffolded, so the README's install description stays false. `>=1.0.4`, the old CI pin, excludes 0.15 and 0.16 users without any evidence that they break.

## 2. The minimum-version job reads the floor from the manifest

**Decision**: The new job takes the version after `>=` in `requires.speckit_version` and installs that tag. It fails loudly when it finds no `>=` bound.

**Rationale**: The job then tests whatever the manifest claims, today and after any later change. It follows the rule `assert-install.sh` already states: every assertion derives from the manifest rather than from a hardcoded number.

**Alternatives considered**: Hardcoding `v0.15.2` in the workflow adds a second copy of the floor that can drift without anyone noticing.

## 3. A separate job, not a matrix

**Decision**: Keep the `smoke` job, named "Install smoke test", as it is apart from the pin. Add a `smoke-minimum` job named "Install smoke test (minimum spec-kit)".

**Rationale**: GitHub names each matrix run after its matrix values, so no check named exactly "Install smoke test" would report, and the ruleset would block every merge to `main`.

**Alternatives considered**: A matrix, for the reason above. Extracting the install steps into a shared script would remove the third copy of three steps, but it is a refactor this feature does not need.

## 4. Unattended project setup on 0.15.2

**Decision**: The minimum job runs `specify init . --integration copilot --force < /dev/null`.

**Rationale**: 0.15.2 has no `--non-interactive`. With stdin closed and `--force`, init exited 0 locally, and `--integration` exists in that release.

**Alternatives considered**: `--ai copilot` is rejected by 0.15.2 as an unknown option.

## 5. The install check fails a broken install readably

**Decision**: Count registered commands with `grep -c` and default an empty result to 0. Fail the file-count check at 0 files. Fail with a message, not a traceback, when `.specify/extensions.yml` is absent.

**Rationale**: `grep -c` prints `0` and exits 1 when nothing matches, so `|| echo 0` appended a second `0` and broke the `[` test. An aborted install leaves neither the extension directory nor `.specify/extensions.yml`, which on 2026-10-14 produced a pass at 0 files and a Python traceback from the hooks check.

**Alternatives considered**: `|| true` keeps a single `0` on no match, but still leaves an empty value when the log itself is missing.

## 6. README install guidance keeps spec-kit's trust boundary

**Decision**: Lead with `specify extension add knowledge --from <release zip>`, and say spec-kit shows an `Untrusted Source` prompt that the user confirms. For teams that want no prompt, point to the route spec-kit recommends: list the extension in a catalog they control. Never suggest marking the community catalog install-allowed, and document no way around the prompt.

**Rationale**: spec-kit 1.1.2 registers the community catalog with `install_allowed=False`, so a plain `specify extension add knowledge` fails on a default setup. Its own messages call that flag the vetting boundary: "Don't flip a discovery-only catalog to install_allowed". `specify extension catalog add` also writes `.specify/extension-catalogs.yml`, and a project catalogs file replaces spec-kit's built-in list, so flipping the community catalog this way silently drops the `default` catalog. Both facts come from the 1.1.2 source.

**Alternatives considered**: Offering `catalog add … --install-allowed` with a trust warning, as the spec first asked. It contradicts spec-kit's guidance and breaks the project's catalog list, so the spec was clarified to drop it.

## 7. One invocation note, examples unchanged

**Decision**: Keep the dot-form examples. Add one note at the top of § Commands naming the skills form (`/speckit-knowledge-sync`) and the Codex form (`$speckit-knowledge-sync`).

**Rationale**: The form depends on the agent and on the spec-kit version: Copilot is installed as skills on 1.1.2 and as prompts on 1.0.4. `validate-extension.sh` also requires the README to name every command in dot form.

**Alternatives considered**: Per-agent variants of every example multiply the README, and would still fail the validator if the dot form disappeared.

## 8. Constitution version 1.3.0

**Decision**: The separate 1.2.0 amendment authorizes project-owned template edits. This feature then bumps the constitution from 1.2.0 to 1.3.0 for its compatibility and CI changes, updates `Last Amended`, and adds a `1.3.0 rationale` note.

**Rationale**: A stated requirement changes and a quality gate grows a second run. That is more than a wording fix, which would be a patch, and removes no principle, which would be a major change.

**Alternatives considered**: Calling a forbidden template edit a justified exception does not satisfy the constitution. Reusing 1.2.0 for the later feature amendment would conflate two independently reviewed changes.
