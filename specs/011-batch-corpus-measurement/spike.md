# Spike: shell-recorded manifests on the support matrix

The gate in front of all other work ([research.md § Spike](./research.md#spike)). It runs the `--records` group of `.github/scripts/test-sync-git.sh`, so the spike's code is the feature's test.

**Pass criteria** (spec, Assumptions):
- the hostile names produce a manifest that Perl's core JSON::PP reads;
- every name reads back byte for byte, checked against git's own `ls-files -z` list;
- no marker file appears;
- a name that is not valid UTF-8 is skipped and shown as `\xHH`.

## Results

| Setup | awk | Shells | git | Result |
|---|---|---|---|---|
| macOS 26.7.1, APFS | BSD awk 20200816 | `sh` (bash 3.2.57 in POSIX mode), `dash`, `bash`, `zsh` 5.9 | 2.54.0 | **Pass**, 35 of 35, on 2026-10-26T16:53Z. The non-UTF-8 case is skipped, because APFS refuses such names. |

### What the local run proved

- The four shells write byte-identical manifests and reports for the same cache.
- `printf "%c"` writes bytes 128 to 255 unchanged under `LC_ALL=C` in BSD awk. Valid UTF-8 names (`guía.md`, a 4-byte emoji) and C1 characters reach the manifest as their own bytes.
- Every hostile name round-trips through JSON::PP: `$(touch pwned).md`, `-option.md`, `"`, `\`, tab, CR, ESC, 0x01, DEL and U+0085. No marker file appears.
- Paths containing a line feed leave no fragment, phantom or duplicate. Links named with `"` and `\` are excluded from the items and reported as `link:` lines.

## Linux rows

| Setup | awk | Shells | git | Result |
|---|---|---|---|---|
| Ubuntu 20.04 (podman, arm64), ext4 | mawk | `sh` (dash), `bash` | stub | **Pass**, 2026-10-26, through [spike/encoder-crosscheck.sh](./spike/encoder-crosscheck.sh). The manifests are byte-identical to this Mac's. The name that is not valid UTF-8 is left out and reported as `caf\xE9.md`. No marker appears. |
| Ubuntu 20.04, full harness | mawk, then gawk | `sh`, `bash`, `zsh` | 2.25 | **Pending** for the maintainer |
| Current Ubuntu, full harness | gawk | `sh`, `bash`, `zsh` | current | **Pending** for the maintainer |

### Why the full Linux rows could not run here

The `ubuntu:20.04` image came through the Artifactory Docker Hub mirror, `docker.ci.artifacts.walmart.com/hub-docker-release-remote`. Three things blocked the full rows:

- That image has no git, zsh, gawk or JSON::PP.
- The internal apt mirror, Proximity `ubuntu-ports`, answered HTTP 520, and ARK did not answer at all.
- Every image that ships git (`buildpack-deps:focal-scm`, `ubuntu:24.04`) failed to pull with a TLS handshake timeout to Artifactory's blob storage.

The internal docs suggest `podman machine init --user-mode-networking` for VPN problems, and `#help_ark_repos` for the apt mirror.

The cross-check covers the riskiest part of those rows: mawk writing bytes 128 to 255 through `printf "%c"`, GNU grep and sed under `LC_ALL=C`, and names that are not valid UTF-8. git is stubbed there, and this Mac's harness covers the link path.

**Gate**: open. Every local check and the mawk row pass. The two full Linux rows are a release check by hand (SC-006, [quickstart.md § 1](./quickstart.md#1-the-sync-checks-on-every-setup-sc-005-sc-006)), tracked by T022.
