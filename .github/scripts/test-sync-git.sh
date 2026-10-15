#!/usr/bin/env bash
# Behavioural check of the git steps in the sync and status commands.
#
# Agent prompts cannot be unit-tested, but their bash blocks can be run. This
# script takes each block straight from the command file, fills in its
# placeholders, and runs it against throwaway file:// repositories. Offline;
# writes only to a mktemp directory. Runnable locally:
#
#   bash .github/scripts/test-sync-git.sh
#
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1
SYNC=$PWD/commands/speckit.knowledge.sync.md
STATUS=$PWD/commands/speckit.knowledge.status.md

pass=0; fail=0
ok()     { printf '  \033[32mPASS\033[0m  %s\n' "$1"; pass=$((pass+1)); }
bad()    { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; fail=$((fail+1)); }
check()  { label=$1; shift; if "$@"; then ok "$label"; else bad "$label"; fi; }
expect() {
  if [ "$2" = "$3" ]; then ok "$1"; else
    bad "$1"; printf '        expected: %s\n        actual:   %s\n' "$3" "$2"
  fi
}

T=$(mktemp -d "${TMPDIR:-/tmp}/sync-git.XXXXXX") || exit 1
P=$T/project
TARPIT=
# Keep the scratch directory when something failed, so run.log can be read.
trap '[ -n "$TARPIT" ] && kill "$TARPIT" 2>/dev/null; [ "$fail" -eq 0 ] && rm -rf "$T"' EXIT
export HOME=$T/home XDG_CONFIG_HOME=$T/home/.config GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid
mkdir -p "$HOME" "$P"

# --- reading and running the command files ----------------------------------

# block <file> <anchor>: the first ```bash block after the line starting with <anchor>.
block() {
  awk -v anchor="$2" '
    !found  { if (index($0, anchor) == 1) found = 1; next }
    !inside { if ($0 ~ /^```bash[[:space:]]*$/) inside = 1; next }
    /^```[[:space:]]*$/ { exit }
    { print }
  ' "$1"
}

URL='' LOCAL='' REV='' FILTER='' DIRS=. SLUG=''
render() {
  if [ -n "$REV" ]; then sed 's|\[--branch <revision>\]|--branch <revision>|'
  else sed '/\[--branch <revision>\]/d'; fi \
  | sed -e "s|<url>|$URL|g" -e "s|<expanded-path>|$LOCAL|g" \
        -e "s|<revision>|$REV|g" -e "s|<slug>|$SLUG|g" \
        -e "s|<pattern1> \[<pattern2> \.\.\.\]|$FILTER|g" -e "s|<path_filter>|$FILTER|g" \
        -e "s|<dir1> \[<dir2> \.\.\.\]|$DIRS|g"
}

# run <file> <anchor>...: each block in its own subshell from the project root,
# after the Bounded Network Call definition. Returns the last block's status.
run() {
  file=$1; shift
  {
    block "$SYNC" '### Bounded Network Call'
    for anchor in "$@"; do
      body=$(block "$file" "$anchor")
      if [ -z "$body" ]; then printf 'echo "missing block: %s" >&2; exit 99\n' "$anchor"; continue; fi
      printf '(\n%s\n)\n' "$(printf '%s\n' "$body" | render)"
    done
  } > "$T/run.sh"
  ( cd "$P" && bash "$T/run.sh" ) >> "$T/run.log" 2>&1
}

# bounded <bin-dir> <seconds> <command...>: with_timeout with only <bin-dir> on PATH.
bounded() {
  bin=$1; shift
  { block "$SYNC" '### Bounded Network Call'; printf 'with_timeout'; printf ' %q' "$@"; echo; } > "$T/bounded.sh"
  PATH=$bin "$BASH" "$T/bounded.sh"
}

# items_of: runs § Indexable Items for $SLUG / $DIRS into items.out and links.out.
items_of() {
  {
    block "$SYNC" '### Indexable Items' | render
    printf 'printf "%%s\\n" "$items" > %q\n' "$T/items.out"
    printf 'printf "%%s\\n" "$links" > %q\n' "$T/links.out"
  } > "$T/items.sh"
  ( cd "$P" && bash "$T/items.sh" ) >> "$T/run.log" 2>&1
}
joined() { sed '/^$/d' "$T/$1.out" | sort | tr '\n' ' ' | sed 's/ $//'; }

cache()   { printf '%s' "$P/.specify/extensions/knowledge/cache/$1"; }
head_of() { git -C "$(cache "$1")" rev-parse HEAD 2>/dev/null; }
content() { cat "$(cache "$1")/$2" 2>/dev/null || echo '<missing>'; }
exists()  { if [ -e "$(cache "$1")/$2" ] || [ -L "$(cache "$1")/$2" ]; then echo yes; else echo no; fi; }
kind()    { f=$(cache "$1")/$2; if [ -L "$f" ]; then echo symlink; elif [ -f "$f" ]; then echo file; else echo missing; fi; }

TIER1='**Tier 1 — no revision pinned, or a branch or tag.**'
TIER2='**Tier 2 — a full commit SHA.**'
TIER3='**Tier 3 — the server refuses an unadvertised object.**'
LOCAL_COLD='**Local path** (no network flags needed'
SPARSE='After clone (both remote and local), apply sparse-checkout'
NOFILTER='If no `path_filter`:'
WARM='#### Warm path (update)'
WARM_REMOTE='**Remote URL** — check out the declared revision'
WARM_LOCAL='**Local path** (fetch from local remote'

# --- fixtures ----------------------------------------------------------------

new_repo() { git init -q "$1" && git -C "$1" symbolic-ref HEAD refs/heads/main; }
commit()   { git -C "$1" add -A && git -C "$1" commit -q -m "$2" && git -C "$1" rev-parse HEAD; }
# Like GitHub: partial clone, and any object may be fetched by id.
serve()    { git -C "$1" config uploadpack.allowFilter true && git -C "$1" config uploadpack.allowAnySHA1InWant true; }

echo
echo "git $(git --version | sed 's/^git version //')"

printf 'TOP-SECRET\n' > "$T/secret.txt"
printf 'PROJECT-SECRET\n' > "$P/.env"
mkdir "$T/outside" && printf 'OUTSIDE\n' > "$T/outside/x.md"

# C1 is pinned. C2, the default tip, edits a.md, deletes b.md, and adds c.md.
U=$T/up; new_repo "$U"; serve "$U"; mkdir "$U/docs"
printf 'A v1\n' > "$U/docs/a.md"; printf 'B pin only\n' > "$U/docs/b.md"; printf 'root\n' > "$U/README.md"
ln -s "$T/secret.txt" "$U/docs/notes.md"
ln -s ../../../../../../.env "$U/docs/rel.md"   # from a cache's docs/, the project's .env
ln -s "$T/outside" "$U/docs/linked"
C1=$(commit "$U" C1)
git -C "$U" checkout -q -b side
# S is neither reachable from main nor a branch tip, so no server advertises it.
printf 'side\n' > "$U/docs/side.md"; S=$(commit "$U" side)
printf 'side 2\n' > "$U/docs/side.md"; commit "$U" side2 >/dev/null
git -C "$U" checkout -q main
printf 'A v2\n' > "$U/docs/a.md"; rm "$U/docs/b.md"; printf 'C default only\n' > "$U/docs/c.md"
C2=$(commit "$U" C2)
# No allow* settings: over protocol v0 this server refuses unadvertised objects.
git clone -q --bare "$U" "$T/up-v0.git"

# --- D1: pinning a full commit SHA ------------------------------------------

echo
echo "Pinning a full commit SHA  (Tiers 2 and 3)"

URL=file://$U REV=$C1 FILTER=docs/ DIRS=docs SLUG=tier2
run "$SYNC" "$TIER1"; rc=$?
check "Tier 1 cannot clone a SHA, so the sync escalates" [ "$rc" -ne 0 ]
run "$SYNC" "$TIER2"; rc=$?
check "Tier 2 clones and fetches the pinned commit" [ "$rc" -eq 0 ]
run "$SYNC" "$SPARSE"
expect "Tier 2 + path_filter: HEAD is the pin, not the default tip" "$(head_of tier2)" "$C1"
expect "Tier 2 + path_filter: the pin's content (a.md v1, b.md, no c.md)" \
       "$(content tier2 docs/a.md)|$(exists tier2 docs/b.md)|$(exists tier2 docs/c.md)" "A v1|yes|no"
expect "path_filter keeps root files out" "$(exists tier2 README.md)" no
expect "clones set core.symlinks=false" "$(git -C "$(cache tier2)" config core.symlinks)" false

REV=$C1 FILTER='' DIRS=. SLUG=tier2-nofilter
run "$SYNC" "$TIER1"; run "$SYNC" "$TIER2" "$NOFILTER"
expect "Tier 2, no path_filter: the pin's HEAD and content" \
       "$(head_of tier2-nofilter)|$(content tier2-nofilter docs/a.md)|$(exists tier2-nofilter docs/c.md)" "$C1|A v1|no"

git config --global protocol.version 0
URL=file://$T/up-v0.git REV=$C1 FILTER=docs/ DIRS=docs SLUG=tier3
run "$SYNC" "$TIER1"; run "$SYNC" "$TIER2"; rc=$?
check "Tier 2 fails when the server refuses unadvertised objects" [ "$rc" -ne 0 ]
run "$SYNC" "$TIER3"; rc=$?
check "Tier 3 succeeds" [ "$rc" -eq 0 ]
run "$SYNC" "$SPARSE"
expect "Tier 3: HEAD and content are the pin's, though FETCH_HEAD is the default tip" \
       "$(head_of tier3)|$(content tier3 docs/a.md)" "$C1|A v1"

REV=$S SLUG=tier3-unreachable
run "$SYNC" "$TIER1"; run "$SYNC" "$TIER2"; run "$SYNC" "$TIER3"; rc=$?
check "Tier 3 fails for a pin outside the fetched history (reported unreachable)" [ "$rc" -ne 0 ]
git config --global --unset protocol.version

# --- D2: warm sync ------------------------------------------------------------

echo
echo "Warm sync  (files deleted upstream, path_filter)"

W=$T/warm; new_repo "$W"; serve "$W"; mkdir "$W/docs"
printf 'ADR-1\n' > "$W/docs/adr-001.md"; printf 'ADR-2\n' > "$W/docs/adr-002.md"; printf 'readme\n' > "$W/README.md"
commit "$W" one >/dev/null

URL=file://$W REV='' FILTER=docs/ DIRS=docs SLUG=warm
run "$SYNC" "$TIER1" "$SPARSE"
printf '{}\n' > "$(cache warm)/.manifest.json"
LOCAL=$W FILTER='' DIRS=. SLUG=warm-local
run "$SYNC" "$LOCAL_COLD" "$NOFILTER"
printf '{}\n' > "$(cache warm-local)/.manifest.json"
expect "local clones set core.symlinks=false" "$(git -C "$(cache warm-local)" config core.symlinks)" false

git -C "$W" rm -q docs/adr-002.md
printf 'ADR-1 v2\n' > "$W/docs/adr-001.md"; printf 'r\n' > "$W/root.md"
mkdir "$W/other"; printf 'o\n' > "$W/other/x.md"
W2=$(commit "$W" two)

FILTER=docs/ DIRS=docs SLUG=warm
run "$SYNC" "$WARM" "$WARM_REMOTE"
expect "HEAD moves to the fetched commit" "$(head_of warm)" "$W2"
expect "a file deleted upstream is removed" "$(exists warm docs/adr-002.md)" no
expect "a file changed upstream is updated" "$(content warm docs/adr-001.md)" "ADR-1 v2"
expect "files added outside path_filter are not written" "$(exists warm root.md)|$(exists warm other/x.md)" "no|no"
expect "the untracked .manifest.json survives" "$(exists warm .manifest.json)" yes

FILTER='' DIRS=. SLUG=warm-local
run "$SYNC" "$WARM" "$WARM_LOCAL"
expect "local path: deletion removed, additions written, manifest kept" \
       "$(exists warm-local docs/adr-002.md)|$(exists warm-local root.md)|$(exists warm-local .manifest.json)" "no|yes|yes"

# Older caches were cloned in cone mode, which always checks out root files.
URL=file://$W REV='' FILTER=docs/ DIRS=docs SLUG=cone
c=$(cache cone)
git clone -q --filter=blob:none --no-checkout --depth=1 -- "$URL" "$c" 2>/dev/null
git -C "$c" sparse-checkout init --cone 2>/dev/null
git -C "$c" sparse-checkout set docs 2>/dev/null; git -C "$c" checkout -q 2>/dev/null
expect "a cone-mode cache starts with root files" "$(exists cone README.md)" yes
run "$SYNC" "$WARM"; rc=$?
check "the warm sparse step succeeds on this git" [ "$rc" -eq 0 ]
run "$SYNC" "$WARM_REMOTE"
expect "...and loses them on its next warm sync" "$(exists cone README.md)" no

# The pre-fix Tier 2: the failed pathspec checkout left HEAD on the default branch.
URL=file://$U REV=$C1 FILTER='' DIRS=. SLUG=legacy
c=$(cache legacy)
git clone -q --filter=blob:none --no-checkout --depth=1 -- "$URL" "$c" 2>/dev/null
git -C "$c" fetch -q --depth=1 origin -- "$C1" 2>/dev/null
git -C "$c" checkout -q -- "$C1" 2>/dev/null; git -C "$c" checkout -q HEAD -- . 2>/dev/null
printf '{}\n' > "$c/.manifest.json"
run "$SYNC" "$WARM" "$WARM_REMOTE"
expect "a pinned cache that served the default branch converges to the pin" \
       "$(head_of legacy)|$(content legacy docs/a.md)|$(exists legacy docs/b.md)|$(exists legacy docs/c.md)" "$C1|A v1|yes|no"

# --- D4: symbolic links ------------------------------------------------------

echo
echo "Symbolic links in a source"

SLUG=tier2 DIRS=docs; items_of
expect "a link is checked out as a plain file" "$(kind tier2 docs/notes.md)" file
expect "items are the regular files git does not record as links" "$(joined items)" "docs/a.md docs/b.md"
expect "every link is reported" "$(joined links)" "docs/linked docs/notes.md docs/rel.md"

SLUG=legacy DIRS=.; items_of
expect "a cache cloned before the fix still holds real links" "$(kind legacy docs/notes.md)" symlink
expect "...and none of them is an item" "$(joined items)" "README.md docs/a.md docs/b.md"
leaks=$(cd "$(cache legacy)" && sed '/^$/d' "$T/items.out" | while read -r f; do cat "$f"; done | grep -c SECRET)
expect "reading every item reveals no file outside the cache" "$leaks" 0

# --- D3: bounded network calls ----------------------------------------------

echo
echo "Bounded network calls"

direct=$(grep -nE '^[[:space:]]*(timeout|gtimeout)[[:space:]]+[0-9]' commands/*.md || true)
if [ -z "$direct" ]; then ok "no command calls timeout directly"; else
  bad "commands call timeout directly"; printf '        %s\n' "$direct"; fi
check "sync defines with_timeout in § Bounded Network Call" \
  grep -q '^with_timeout()' <(block "$SYNC" '### Bounded Network Call')

if command -v timeout >/dev/null 2>&1; then via=timeout
elif command -v gtimeout >/dev/null 2>&1; then via=gtimeout; else via=perl; fi
URL=file://$U
run "$STATUS" '**Remote URL** (`with_timeout`'; rc=$?
expect "status: a reachable remote answers 0 (via $via)" "$rc" 0

mkdir "$T/bin-perl" "$T/bin-none"
ln -s "$(command -v git)" "$T/bin-perl/git"; ln -s "$(command -v perl)" "$T/bin-perl/perl"
ln -s "$(command -v git)" "$T/bin-none/git"

bounded "$T/bin-perl" 5 git ls-remote --exit-code -- "file://$U" HEAD >/dev/null 2>&1
expect "perl fallback: success is 0" "$?" 0
bounded "$T/bin-perl" 5 git ls-remote --exit-code -- "file://$U" refs/heads/nope >/dev/null 2>&1
expect "perl fallback: the command's own status passes through" "$?" 2
bounded "$T/bin-perl" 5 no-such-command-xyz >/dev/null 2>&1
expect "perl fallback: a command that cannot run is 127, not 0" "$?" 127

perl -MIO::Socket::INET -e '
  $| = 1;
  my $s = IO::Socket::INET->new(LocalAddr => "127.0.0.1", LocalPort => 0, Listen => 5, ReuseAddr => 1) or die;
  print $s->sockport, "\n";
  my @held; push @held, $_ while $_ = $s->accept;
' > "$T/tarpit.port" &
TARPIT=$!
disown "$TARPIT" 2>/dev/null || true
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -s "$T/tarpit.port" ] && break; sleep 0.2; done
port=$(cat "$T/tarpit.port")
start=$(date +%s)
bounded "$T/bin-perl" 2 git ls-remote --exit-code -- "http://127.0.0.1:$port/x" HEAD >/dev/null 2>&1; rc=$?
elapsed=$(( $(date +%s) - start ))
expect "perl fallback: a hung host is cut off with 124 within the bound plus 1 s grace" \
       "$rc|$([ "$elapsed" -le 4 ] && echo on-time || echo "late (${elapsed}s)")" "124|on-time"
if command -v pgrep >/dev/null 2>&1; then
  sleep 1
  expect "perl fallback: no transport helper outlives the call" "$(pgrep -f "127.0.0.1:$port" | wc -l | tr -d ' ')" 0
fi

bounded "$T/bin-none" 5 git ls-remote --exit-code -- "file://$U" HEAD >/dev/null 2>"$T/warn"
expect "no timeout tool at all: the call still runs" "$?" 0
check "no timeout tool at all: one warning says so" grep -q 'without a time bound' "$T/warn"

echo
if [ "$fail" -eq 0 ]; then
  printf '\033[32m%s checks passed.\033[0m\n\n' "$pass"
  exit 0
fi
printf '\033[31m%s failed\033[0m, %s passed. Scratch kept: %s\n\n' "$fail" "$pass" "$T"
exit 1
