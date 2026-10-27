#!/usr/bin/env bash
# Verifies a published release the way a user, and the catalog bot, will see it:
# the GitHub release exists, the tag archive downloads with a stable SHA-256,
# holds exactly what `git archive` of the tag holds (no dev-only path, no
# requirement ID), and installs from its URL into a clean project.
#
# Usage:  verify-release.sh X.Y.Z
# Needs:  git, gh, curl, unzip, python3 with PyYAML, and `specify` on PATH.
#
set -uo pipefail

VERSION="${1:?usage: verify-release.sh X.Y.Z}"
VERSION="${VERSION#v}"
ROOT=$(git -C "$(dirname "$0")" rev-parse --show-toplevel) || exit 1
cd "$ROOT" || exit 1

REPO_URL=$(python3 -c "import yaml; print(yaml.safe_load(open('extension.yml'))['extension']['repository'].rstrip('/'))")
SLUG=${REPO_URL#https://github.com/}
TAG="v$VERSION"
URL="$REPO_URL/archive/refs/tags/$TAG.zip"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/verify-release.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

fail=0
ok()  { printf '  \033[32mPASS\033[0m  %s\n' "$1"; }
bad() { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; fail=1; }

echo "Verifying $TAG of $SLUG"

state=$(gh release view "$TAG" --repo "$SLUG" --json isDraft,isPrerelease --jq '"\(.isDraft) \(.isPrerelease)"' 2>/dev/null)
[ "$state" = "false false" ] && ok "GitHub release $TAG is published" \
                             || bad "GitHub release $TAG missing, draft or pre-release ($state)"

curl -fsSL -o "$WORK/a.zip" "$URL" && curl -fsSL -o "$WORK/b.zip" "$URL" \
  || { bad "cannot download $URL"; exit 1; }
sha_a=$(shasum -a 256 "$WORK/a.zip" | awk '{print $1}')
sha_b=$(shasum -a 256 "$WORK/b.zip" | awk '{print $1}')
[ "$sha_a" = "$sha_b" ] && ok "SHA-256 is stable across two downloads" \
                        || bad "SHA-256 changed between downloads ($sha_a / $sha_b)"

# Compare against the tag itself, so a new shipped file needs no edit here.
git fetch -q origin "refs/tags/$TAG:refs/tags/$TAG" 2>/dev/null
want=$(git archive --format=tar "$TAG" 2>/dev/null | tar -tf - | grep -v '/$' | sort)
got=$(unzip -Z1 "$WORK/a.zip" | grep -v '/$' | sed 's#^[^/]*/##' | sort)
[ -n "$want" ] && [ "$want" = "$got" ] && ok "archive holds exactly the $(echo "$got" | wc -l | tr -d ' ') files of git archive $TAG" \
  || bad "archive contents differ from git archive $TAG"
echo "$got" | grep -qE '^(\.specify|\.github|specs|\.claude|\.agents|\.wibey)/|^AGENTS\.md$|^skills-lock\.json$' \
  && bad "dev-only paths in the archive" || ok "no dev-only paths in the archive"

mkdir -p "$WORK/x" && unzip -q "$WORK/a.zip" -d "$WORK/x"
SRC=$(find "$WORK/x" -mindepth 1 -maxdepth 1 -type d | head -1)
ids=$(cd "$SRC" && grep -nE '\b(FR|SC)-[0-9]+[a-z]?\b|\bspec [0-9]{3}\b' commands/*.md extension.yml config-template.yml README.md 2>/dev/null | wc -l | tr -d ' ')
[ "$ids" = 0 ] && ok "shipped files cite no requirement IDs" || bad "shipped files cite $ids requirement IDs"

# Install from the URL, exactly as the README tells users to.
C="$WORK/consumer"; mkdir -p "$C" && cd "$C" && git init -q
if specify init . --integration copilot --non-interactive --force > init.log 2>&1 \
   && printf 'y\n' | specify extension add knowledge --from "$URL" > install.log 2>&1; then
  ok "installs from $URL with Spec Kit $(specify version 2>/dev/null | sed -n 's/.*CLI Version *\([^ ]*\).*/\1/p')"
  # assert-install.sh reads the manifest from the extracted release, not the working tree.
  bash "$ROOT/.github/scripts/assert-install.sh" "$C" "$SRC" | sed 's/^/  /' || fail=1
else
  bad "specify extension add failed"; tail -20 install.log
fi

echo
if [ "$fail" -eq 0 ]; then
  printf '\033[32mRelease %s verified.\033[0m\n  download_url  %s\n  sha256        %s\n\n' "$TAG" "$URL" "$sha_a"
  exit 0
fi
printf '\033[31mRelease %s has problems.\033[0m Fix forward with a new patch version; release tags are immutable.\n\n' "$TAG"
exit 1
