#!/usr/bin/env bash
# Spike T008: the record run's encoder on Linux (mawk, dash, GNU grep and sed,
# ext4) against this machine, for an image with no git, zsh or JSON::PP.
#
# A stub `git` reports link"q.md as a symbolic link, so § Indexable Items runs
# without git. This machine's manifest is checked with JSON::PP; the container's
# must be byte-identical to it, and only the container can hold a name that is
# not valid UTF-8 (APFS refuses one).
#
#   bash specs/011-batch-corpus-measurement/spike/encoder-crosscheck.sh [image]
#
set -uo pipefail
cd "$(dirname "$0")/../../.." || exit 1
IMAGE=${1:-docker.ci.artifacts.walmart.com/hub-docker-release-remote/ubuntu:20.04}
W=$(mktemp -d "${TMPDIR:-/tmp}/encoder-crosscheck.XXXXXX") || exit 1
trap 'rm -rf "$W"' EXIT
SLUG=0123456789ab
CACHE=.specify/extensions/knowledge/cache/$SLUG
fail=0
report() { if [ "$1" = ok ]; then printf '  PASS  %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fail=1; fi; }

block() {
  awk -v anchor="$1" '
    !found  { if (index($0, anchor) == 1) found = 1; next }
    !inside { if ($0 ~ /^```bash[[:space:]]*$/) inside = 1; next }
    /^```[[:space:]]*$/ { exit }
    { print }
  ' commands/speckit.knowledge.sync.md
}

{
  printf '%s\n' "git() { printf '120000 %040d 0\\tlink\"q.md\\0' 0; }"
  block '### Indexable Items'; block '### Item Records'; block '### 6. Write'
} | sed -e "s|<slug>|$SLUG|g" -e "s|'<dir1>' \['<dir2>' ...\]|'.'|" -e "s|'\./<dir1>' \['\./<dir2>' ...\]|'./.'|" \
        -e "s|<path_filter>||" -e "s|<url>|https://example.invalid/org/kb.git|" -e "s|<revision>||" > "$W/record.sh"

cat > "$W/fixture.sh" <<'EOF'
root=$1 bad=$2
c=$root/.specify/extensions/knowledge/cache/0123456789ab
mkdir -p "$c/docs" "$c/.git" && cd "$c" || exit 1
for name in '$(touch pwned).md' '-option.md' 'a"quote.md' 'back\slash.md' $'tab\tname.md' $'cr\rname.md' \
            $'esc\x1bname.md' $'ctl\x01name.md' $'del\x7fname.md' $'c1\xc2\x85name.md' 'guía.md' \
            $'emoji-\xf0\x9f\x98\x80.md' docs/plain.md $'nl\nname.md' 'link"q.md'; do
  printf '%s\n' "$name" > "./$name"
done
if [ "$bad" = yes ]; then printf 'NOT-UTF-8\n' > $'./caf\xe9.md'; fi
EOF

normalize() { sed -e 's/"synced_at": "[^"]*"/"synced_at": "-"/' -e 's/ synced_at=[^ ]*$/ synced_at=-/' "$1"; }

bash "$W/fixture.sh" "$W/host" no
( cd "$W/host" && sh "$W/record.sh" ) > "$W/host.report" 2>&1
cp "$W/host/$CACHE/.manifest.json" "$W/host.json"
if perl -MJSON::PP -e '
  open my $f, "<:raw", $ARGV[0] or exit 1; my $m = JSON::PP->new->utf8->decode(do { local $/; <$f> });
  exit 1 unless $m->{item_count} == 13 && @{ $m->{items} } == 13;
  for (@{ $m->{items} }) { my $p = $_->{path}; utf8::encode($p); exit 1 unless -f "$ARGV[1]/$p" }
' "$W/host.json" "$W/host/$CACHE"; then
  report ok "this machine ($(awk --version 2>&1 | head -1)): 13 items, JSON::PP reads every path back"
else
  report fail "this machine: manifest does not read back"
fi

podman run --rm -v "$W:/w" "$IMAGE" bash -c '
  bash /w/fixture.sh /tmp/c yes
  for s in sh bash; do
    rm -f /tmp/c/.specify/extensions/knowledge/cache/0123456789ab/.manifest.json
    ( cd /tmp/c && "$s" /w/record.sh ) > "/w/ctr.$s.report" 2>&1
    cp /tmp/c/.specify/extensions/knowledge/cache/0123456789ab/.manifest.json "/w/ctr.$s.json"
  done
  if [ -e /tmp/c/pwned ] || [ -e /tmp/c/.specify/extensions/knowledge/cache/0123456789ab/pwned ]; then echo marker > /w/ctr.marker; fi
  { readlink -f /usr/bin/awk; readlink -f /bin/sh; grep --version | head -1; } > /w/ctr.tools
' || report fail "container did not run: $IMAGE"

printf '  container: %s\n' "$(tr '\n' ' ' < "$W/ctr.tools" 2>/dev/null)"
for s in sh bash; do
  if [ -f "$W/ctr.$s.json" ] && cmp -s <(normalize "$W/host.json") <(normalize "$W/ctr.$s.json"); then
    report ok "container $s: manifest byte-identical to this machine's"
  else
    report fail "container $s: manifest differs"
  fi
  if grep -Fxq 'skipped-utf8: caf\xE9.md' "$W/ctr.$s.report" 2>/dev/null; then
    report ok "container $s: the name that is not valid UTF-8 is reported as caf\\xE9.md"
  else
    report fail "container $s: no skipped-utf8 line for caf\\xE9.md"
  fi
  if cmp -s <(normalize "$W/host.report") <(grep -v '^skipped-utf8: ' "$W/ctr.$s.report" | normalize /dev/stdin); then
    report ok "container $s: every other report line matches this machine's"
  else
    report fail "container $s: report differs"
  fi
done
if [ -e "$W/ctr.marker" ]; then report fail 'container: a hostile name created a marker'; else report ok 'container: no marker'; fi
exit "$fail"
