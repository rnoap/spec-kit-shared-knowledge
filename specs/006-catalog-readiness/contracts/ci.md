# Contract: CI checks and the install assertion

**Feature**: [../catalog-readiness.spec.md](../catalog-readiness.spec.md) · **Plan**: [../plan.md](../plan.md) · **Research**: [../research.md](../research.md)

Two consumers code against this surface, and neither changes here: the `main` branch ruleset,
which waits for checks by name, and `upstream-compat.yml`, which reads the gating pin out of
`validate.yml` and runs the same assertion script.

---

## 1. Checks

| Workflow | Job id | Check name (exact) | Triggers | spec-kit | Required on `main` |
|---|---|---|---|---|---|
| `validate.yml` | `validate` | `Static validation` | pull request, push to `main`, manual | — | yes, unchanged |
| `validate.yml` | `smoke` | `Install smoke test` | pull request, push to `main`, manual | `v1.2.0`, from `SPEC_KIT_REF` | yes, unchanged |
| `validate.yml` | `smoke-minimum` | `Install smoke test (minimum spec-kit)` | pull request, push to `main`, manual | `v0.15.2`, from `extension.yml` | no, until a maintainer adds it |
| `upstream-compat.yml` | `smoke-against-main` | `Install smoke test (spec-kit main)` | weekly, manual | `main` | no, unchanged |

- The two required names are load-bearing (FR-015). Renaming either job, or turning `smoke` into a
  matrix, stops the required check from reporting and blocks every merge: GitHub names each matrix
  run after its values ([research § 3](../research.md#3-a-separate-job-not-a-matrix)).
- Adding the new check to the ruleset is a repository setting outside this change.

---

## 2. The gating pin (FR-013)

```yaml
env:
  SPEC_KIT_REF: v1.2.0
```

- Stays workflow-level in `validate.yml`, and stays the file's only line matching `SPEC_KIT_REF: `.
  `upstream-compat.yml` reads it with
  `grep -oE 'SPEC_KIT_REF: .*' .github/workflows/validate.yml | cut -d' ' -f2`; a second match
  would garble its failure report.
- `smoke` is otherwise unchanged: it installs `git+https://github.com/github/spec-kit.git@${SPEC_KIT_REF}`
  and runs `specify init` with `--non-interactive`.

---

## 3. The minimum-version job (FR-014)

| Step | `smoke` | `smoke-minimum` |
|---|---|---|
| spec-kit release | `${SPEC_KIT_REF}` | `v` + the version in the `>=` clause of `requires.speckit_version`: `v0.15.2` |
| Project setup | `specify init . --integration copilot --non-interactive --force` | `specify init . --integration copilot --force < /dev/null` |
| Extension install | `specify extension add "$GITHUB_WORKSPACE" --dev` | identical |
| Assertion | `bash "$GITHUB_WORKSPACE/.github/scripts/assert-install.sh" /tmp/consumer "$GITHUB_WORKSPACE"` | identical |
| Log artifact on failure | `install-log` | `install-log-minimum` |

- **The floor comes from the manifest.** The job reads `requires.speckit_version` and installs the
  release its `>=` clause names. With no `>=` clause it fails with an error naming the field and its
  value, and never falls back to a default
  ([research § 2](../research.md#2-the-minimum-version-job-reads-the-floor-from-the-manifest)). The
  workflow holds no second copy of the floor.
- **Never `SPEC_KIT_REF`.** The job sees the workflow-level `SPEC_KIT_REF` and must ignore it. It
  must not declare its own either; see § 2.
- **Unattended setup.** spec-kit `0.15.2` has no `--non-interactive`. Closed stdin plus `--force`
  lets `init` finish; that release rejects `--ai copilot`
  ([research § 4](../research.md#4-unattended-project-setup-on-0152)).
- **Its own artifact name.** Artifact names are unique within a workflow run, so a second
  `install-log` upload would fail exactly when the log is needed.
- Prints `specify --version` after installing, as `smoke` does, so the log shows which release was
  tested.

---

## 4. `assert-install.sh`

```text
assert-install.sh <consumer-dir> <repo-root>
```

| Argument | Default |
|---|---|
| `<consumer-dir>` | `/tmp/consumer` |
| `<repo-root>` | `$GITHUB_WORKSPACE`, else two directories above the script |

`smoke`, `smoke-minimum` and `smoke-against-main` call it with the same arguments. The interface is
unchanged; what it reports for a broken install is not.

- **Reads** `<repo-root>/extension.yml` for every expected number, and `install.log`,
  `.specify/extensions/<id>/` and `.specify/extensions.yml` under `<consumer-dir>`.
- **Prints** one `  PASS  <text>` or `  FAIL  <text>` line per check, then a blank line and
  `Smoke test passed.` (exit 0) or `Smoke test failed.` (exit 1). `PASS` and `FAIL` are wrapped in
  ANSI colour codes; match on the text after them.
- A missing `<consumer-dir>` prints `no consumer project at <consumer-dir>` and exits 1.

### 4.1 Checks

Expected values come from the manifest; today that is 5 commands, 4 hooks, `knowledge-config.yml`
and version `1.5.0`.

| # | Check | PASS | FAIL | Change |
|---|---|---|---|---|
| 1 | No scaffolding warning in `install.log` | `no config-scaffolding warning` | `spec-kit refused to scaffold the config template` | — |
| 2 | Config file on disk | `config scaffolded: knowledge-config.yml` | `config declared but not created: .specify/extensions/knowledge/knowledge-config.yml` | — |
| 3 | `• speckit.` lines in `install.log` | `all 5 commands registered` | `manifest declares 5 commands, install reported <n>` | `<n>` is a single integer: `0` when nothing matches or the log is missing (FR-016) |
| 4 | Version in `install.log` | `installed version reported as v1.5.0` | `install did not report v1.5.0` | — |
| 5 | Files under `.specify/extensions/knowledge/` | `installed file count is sane (<n>)`, for 1 ≤ n < 30 | n ≥ 30: `install copied <n> files — check .extensionignore`, then up to 20 paths | n = 0 fails: `install copied 0 files — the extension directory is missing or empty` (FR-017) |
| 6 | Hooks in `.specify/extensions.yml`, none with arguments | `4 hooks registered, none carrying arguments` | `manifest declares 4 hooks, <n> registered` or `hook(s) carry arguments, breaking FR-022: <events>` | A missing file fails as `manifest declares 4 hooks, 0 registered (.specify/extensions.yml is missing)` |

### 4.2 Broken installs it must catch (SC-005)

| Seed | State under `<consumer-dir>` | Must print a FAIL line reading | Exit |
|---|---|---|---|
| A, no commands registered | A good install, with every `• speckit.` line removed from `install.log` | `manifest declares 5 commands, install reported 0` | 1 |
| B, no files copied | `install.log` present; `.specify/extensions/knowledge/` and `.specify/extensions.yml` absent, as an aborted install leaves them | `install copied 0 files — the extension directory is missing or empty` | 1 |

For both seeds the output holds no shell or interpreter error: no `integer expression expected`, no
`Traceback`, and no `No such file or directory` from `find` or `grep`. Today seed A trips `[` on a
two-line count, and seed B passes check 5 at 0 files, then ends in a Python traceback.
