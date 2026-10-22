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

finish() {
  echo
  if [ "$fail" -eq 0 ]; then
    printf '\033[32m%s checks passed.\033[0m\n\n' "$pass"
    exit 0
  fi
  printf '\033[31m%s failed\033[0m, %s passed. Scratch kept: %s\n\n' "$fail" "$pass" "$T"
  exit 1
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
  URL="$URL" LOCAL="$LOCAL" REV="$REV" FILTER="$FILTER" DIRS="$DIRS" SLUG="$SLUG" perl -0pe '
    sub escaped {
      my ($value) = @_;
      $value =~ s/\x27/\x27\\\x27\x27/g;
      return $value;
    }
    sub quoted { return "\x27" . escaped($_[0]) . "\x27" }
    sub replacement {
      my ($token) = @_;
      return length($ENV{REV}) ? "--branch " . quoted($ENV{REV}) : ""
        if $token eq "[--branch \x27<revision>\x27]";
      return quoted($ENV{FILTER}) if $token =~ /<pattern1>/;
      return quoted(($token =~ m{\./<dir1>} ? "./" : "") . $ENV{DIRS})
        if $token =~ /<dir1>/;
      my %values = (
        "<url>" => $ENV{URL}, "<expanded-path>" => $ENV{LOCAL},
        "<revision>" => $ENV{REV}, "<slug>" => $ENV{SLUG},
        "<path_filter>" => $ENV{FILTER},
      );
      return exists($values{$token}) ? escaped($values{$token}) : $token;
    }
    s{\[--branch\x20\x27<revision>\x27\]
      |\x27<pattern1>\x27\x20\[\x27<pattern2>\x27\x20\.\.\.\]
      |\x27\./<dir1>\x27\x20\[\x27\./<dir2>\x27\x20\.\.\.\]
      |\x27<dir1>\x27\x20\[\x27<dir2>\x27\x20\.\.\.\]
      |<[A-Za-z][A-Za-z0-9_-]*>
    }{replacement($&)}gex;
  '
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
SPARSE='With a `path_filter`:'
NOFILTER='If no `path_filter`:'
WARM='#### Warm path (update)'
WARM_REMOTE='**Remote URL** — check out the declared revision'
WARM_LOCAL='**Local path** (fetch from local remote'

hostile_record() {
  printf '%s\0' "$#" "$@" >> "$HOSTILE_LOG"
}

hostile_arguments() {
  perl -e '
    sub fields {
      open my $input, "<:raw", $_[0] or die "$ARGV[0]: $!\n";
      local $/;
      my @fields = split /\0/, scalar(<$input>) // "", -1;
      pop @fields if @fields && $fields[-1] eq "";
      return @fields;
    }
    my @actual = fields($ARGV[0]);
    my %actual;
    while (@actual) {
      my $argc = shift @actual;
      die "malformed argument recording\n"
        unless $argc =~ /^[1-9][0-9]*$/ && @actual >= $argc;
      my @args = splice @actual, 0, $argc;
      my $program = shift @args;
      $actual{$program}{$_}++ for @args;
    }
    my @expected = fields($ARGV[1]);
    die "malformed argument expectations\n" if @expected % 2;
    my %expected;
    while (@expected) {
      my ($program, $value) = splice @expected, 0, 2;
      $expected{$program}{$value}++;
    }
    my $valid = 1;
    for my $program (sort keys %expected) {
      for my $value (sort keys %{$expected{$program}}) {
        my $want = $expected{$program}{$value};
        my $got = $actual{$program}{$value} // 0;
        next if $want == $got;
        warn "$program: expected $want byte-exact argument(s), received $got\n";
        $valid = 0;
      }
    }
    exit($valid ? 0 : 1);
  ' "$1" "$2"
}

hostile_block() {
  local source=$1 anchor=$2 name=$3
  shift 3
  local body field seed_number seed case_dir marker marker_word value rc reason
  local URL LOCAL REV FILTER DIRS SLUG
  body=$(block "$source" "$anchor")
  if [ -z "$body" ]; then bad "$name: missing block"; return; fi
  for field in "$@"; do
    for seed_number in 1 2 3 4 5 6 7 8; do
      case_dir=$T/hostile/$name-$field-$seed_number
      mkdir -p "$case_dir"
      marker=$case_dir/marker
      marker_word=$(printf '%q' "$marker")
      case "$seed_number" in
        1) seed="\$(touch $marker_word)" ;;
        2) seed="\`touch $marker_word\`" ;;
        3) seed="x;touch $marker_word" ;;
        4) seed="x&&touch $marker_word" ;;
        5) seed="x|touch $marker_word" ;;
        6) seed="x>$marker_word" ;;
        7) seed="x';touch $marker_word;'" ;;
        8) seed=$(printf 'x\ntouch %s' "$marker_word") ;;
      esac
      URL=https://example.invalid/repo LOCAL=$T/source REV=main
      FILTER=docs/ DIRS=docs SLUG=012345abcdef
      case "$field" in
        URL) URL=https://example.invalid/$seed ;;
        LOCAL) LOCAL=$T/$seed ;;
        *) printf -v "$field" '%s' "$seed" ;;
      esac
      value=${!field}
      : > "$case_dir/argv"
      : > "$case_dir/expected"
      case "$name:$field" in
        slug:*) printf '%s\0' "slug-$field" "$value" >> "$case_dir/expected" ;;
        indexable:DIRS)
          printf '%s\0' git "$value" find "./$value" >> "$case_dir/expected" ;;
        indexable:FILTER)
          printf '%s\0' '[' "$value" >> "$case_dir/expected" ;;
        status-local:LOCAL)
          printf '%s\0' '[' "$value/.git" git "$value" >> "$case_dir/expected" ;;
        warm-sparse:FILTER|warm-remote:REV|warm-local:REV)
          printf '%s\0' '[' "$value" git "$value" >> "$case_dir/expected" ;;
        *) printf '%s\0' git "$value" >> "$case_dir/expected" ;;
      esac
      {
        block "$SYNC" '### Bounded Network Call'
        declare -f hostile_record
        printf '%s\n' \
          'function [ { hostile_record "[" "$@"; builtin [ "$@"; }' \
          'find() { hostile_record find "$@"; printf "./fixture.md\n"; }'
        printf '%s\n' "$body" | render
        printf '%s\n' 'hostile_rc=$?'
        if [ "$name" = slug ]; then
          printf '%s\n' \
            'hostile_record slug-URL "${url-}"' \
            'hostile_record slug-REV "${revision-}"'
        fi
        printf '%s\n' 'exit "$hostile_rc"'
      } > "$case_dir/run.sh"
      ( cd "$P" && PATH="$hostile_bin:$PATH" HOSTILE_LOG="$case_dir/argv" \
        "$BASH" "$case_dir/run.sh" ) > "$case_dir/run.log" 2>&1
      rc=$?
      reason=''
      if [ -e "$marker" ]; then reason='marker executed; '; fi
      if ! hostile_arguments "$case_dir/argv" "$case_dir/expected" >> "$case_dir/run.log" 2>&1; then
        reason="${reason}argument bytes/count differ; "
      fi
      if [ "$rc" -ne 0 ]; then reason="${reason}snippet exit $rc; "; fi
      if [ -z "$reason" ]; then
        ok "$name / $field / seed $seed_number: no marker, byte-exact arguments"
      else
        bad "$name / $field / seed $seed_number: $reason"
      fi
    done
  done
}

hostile_values() {
  local hostile_bin=$T/hostile/bin
  mkdir -p "$hostile_bin" "$(cache 012345abcdef)"
  {
    printf '#!%s\n' "$BASH"
    declare -f hostile_record
    printf '%s\n' 'hostile_record git "$@"'
  } > "$hostile_bin/git"
  chmod +x "$hostile_bin/git"
  echo
  echo 'Hostile values (validation bypassed)'
  hostile_block "$SYNC" '### Source Slug Generation' slug URL REV
  hostile_block "$SYNC" "$TIER1" tier1 URL REV
  hostile_block "$SYNC" "$TIER2" tier2 URL REV
  hostile_block "$SYNC" "$TIER3" tier3 REV
  hostile_block "$SYNC" "$LOCAL_COLD" local-cold LOCAL REV
  hostile_block "$SYNC" "$SPARSE" cold-sparse FILTER
  hostile_block "$SYNC" "$WARM" warm-sparse FILTER
  hostile_block "$SYNC" "$WARM_REMOTE" warm-remote REV
  hostile_block "$SYNC" "$WARM_LOCAL" warm-local REV
  hostile_block "$SYNC" '### Indexable Items' indexable DIRS FILTER
  hostile_block "$STATUS" '**Remote URL** (`with_timeout`' status-remote URL
  hostile_block "$STATUS" '**Local path** (expand' status-local LOCAL
}

slug_checks() {
  local shell_name reference slug_exit URL REV expected_slug
  local slug_urls=(
    'https://GitHub.com/org/payment-service.git'
    'https://github.com/org/payment-service/'
    'https://github.com/org/payment-service.git/'
    'https://github.com/org/payment-service'
    'https://github.com/org/payment-service'
    'git@github.com:org/payment-service.git'
    'git@github.com:org/payment-service'
    'ssh://git@GitHub.com/Org/Payment-Service/'
    '~/My Repos/kb'
  )
  local slug_revisions=('' '' '' v2.4.1 0123456789abcdef0123456789abcdef01234567 '' main '' '')
  local slug_expected=(18dbb51ec4eb 18dbb51ec4eb e60fc46dba69 5e8b13c49fbe 93b864df69a3 c9511374b688 b916698aa6c1 0b93c9b8c26b d3ae9616ac00)
  echo
  echo 'Slug procedure in sh, bash and zsh'
  for shell_name in sh bash zsh; do
    if ! command -v "$shell_name" >/dev/null 2>&1; then
      bad "slug procedure: required shell $shell_name is missing"
      continue
    fi
    for reference in "${!slug_urls[@]}"; do
      URL=${slug_urls[$reference]} REV=${slug_revisions[$reference]}
      expected_slug=${slug_expected[$reference]}
      block "$SYNC" '### Source Slug Generation' | render > "$T/slug.sh"
      printf '%s\n' "$expected_slug" > "$T/slug.expected"
      "$shell_name" "$T/slug.sh" > "$T/slug.stdout" 2> "$T/slug.stderr"
      slug_exit=$?
      if [ "$slug_exit" -eq 0 ] && [ ! -s "$T/slug.stderr" ] \
        && cmp -s "$T/slug.expected" "$T/slug.stdout"; then
        ok "$shell_name slug reference $((reference + 1)): exact stdout, empty stderr, exit 0"
      else
        bad "$shell_name slug reference $((reference + 1)): output or exit differs ($slug_exit)"
      fi
    done
  done
}

if [ "${1:-}" = --slugs ]; then slug_checks; finish; fi
case "${1:-}" in
  --local-space|--hostile-files) ;;
  *) hostile_values ;;
esac
if [ "${1:-}" = --hostile-values ]; then finish; fi

# --- fixtures ----------------------------------------------------------------

new_repo() { git init -q "$1" && git -C "$1" symbolic-ref HEAD refs/heads/main; }
commit()   { git -C "$1" add -A && git -C "$1" commit -q -m "$2" && git -C "$1" rev-parse HEAD; }
# Like GitHub: partial clone, and any object may be fetched by id.
serve()    { git -C "$1" config uploadpack.allowFilter true && git -C "$1" config uploadpack.allowAnySHA1InWant true; }

hostile_file_checks() {
  local source=$T/hostile-files-source hostile_name='$(touch pwned).md'
  local relative_dir=$'relative\n..' absolute_dir=$'absolute\n'
  local outside_file=$T/hostile-outside/escape.md outside_hash expected_hash
  local URL LOCAL REV='' FILTER='' DIRS=. SLUG=hostile-files
  mkdir -p "${outside_file%/*}"
  printf 'OUTSIDE-CACHE\n' > "$outside_file"
  new_repo "$source"
  printf 'LITERAL-NAME\n' > "$source/$hostile_name"
  printf 'LEADING-DASH\n' > "$source/-option.md"
  mkdir -p "$source/$relative_dir" "$source/$absolute_dir/${outside_file%/*}"
  printf 'INSIDE-RELATIVE\n' > "$source/$relative_dir/escape.md"
  printf 'INSIDE-ABSOLUTE\n' > "$source/$absolute_dir/${outside_file#/}"
  commit "$source" hostile-names >/dev/null
  URL=$source LOCAL=$source
  echo
  echo 'Hostile fetched file names'
  run "$SYNC" "$LOCAL_COLD" "$NOFILTER"
  printf 'OUTSIDE-CACHE\n' > "$(cache "$SLUG")/../escape.md"
  items_of
  check 'hostile file name is indexed literally' grep -Fxq -- "$hostile_name" "$T/items.out"
  check 'leading-dash file is indexed' grep -Fxq -- '-option.md' "$T/items.out"
  if grep -Eq '(^|/)\.\.(/|$)|^/' "$T/items.out"; then
    bad 'newline directory cannot forge traversal or absolute item paths'
  else
    ok 'newline directory cannot forge traversal or absolute item paths'
  fi
  {
    block "$SYNC" '### Indexable Items' | render
    printf '%s\n' 'while IFS= read -r file; do' '[ -f "$file" ] || continue'
    block "$SYNC" '### Corpus Measurement'
    printf '%s\n' \
      'if command -v sha256sum >/dev/null 2>&1; then' \
      '  hash=$(sha256sum < "$file" | cut -d " " -f1)' \
      'else' \
      '  hash=$(shasum -a 256 < "$file" | cut -d " " -f1)' \
      'fi'
    printf 'printf "%%s\\t%%s\\t%%s\\n" "$file" "$size" "$hash" >> %q\n' "$T/measured.out"
    printf '%s\n' 'done <<< "$items"'
  } > "$T/hostile-files.sh"
  : > "$T/measured.out"
  ( cd "$P" && "$BASH" "$T/hostile-files.sh" ) >> "$T/run.log" 2>&1
  expect 'literal file name is measured without command evaluation' \
    "$(awk -F '\t' '$1 == "$(touch pwned).md" { print $2 }' "$T/measured.out" | tr -d ' ')" 13
  expected_hash=$(shasum -a 256 < "$source/-option.md" | cut -d ' ' -f1)
  expect 'leading-dash file is measured and hashed as content, not an option' \
    "$(awk -F '\t' '$1 == "-option.md" { print $2 "|" $3 }' "$T/measured.out" | tr -d ' ')" \
    "13|$expected_hash"
  outside_hash=$(shasum -a 256 < "$outside_file" | cut -d ' ' -f1)
  if grep -Fq -- "$outside_hash" "$T/measured.out"; then
    bad 'no measured item content comes from outside the cache'
  else
    ok 'no measured item content comes from outside the cache'
  fi
  if [ -e "$T/pwned" ] || [ -e "$P/pwned" ] || [ -e "$(cache "$SLUG")/pwned" ]; then
    bad 'hostile fetched name never creates a marker'
  else
    ok 'hostile fetched name never creates a marker'
  fi
}

if [ "${1:-}" = --hostile-files ]; then hostile_file_checks; finish; fi

echo
echo 'A local path containing a space'

URL='~/My Repos/kb' LOCAL="$HOME/My Repos/kb" REV='' FILTER='' DIRS=. SLUG=local-space
mkdir -p "$LOCAL"
new_repo "$LOCAL"
mkdir "$LOCAL/docs"
printf 'A v1\n' > "$LOCAL/docs/a.md"
printf 'B cold only\n' > "$LOCAL/docs/b.md"
spaced_cold=$(commit "$LOCAL" cold)

run "$SYNC" "$LOCAL_COLD" "$NOFILTER"; rc=$?
expect 'spaced local path: cold sync exits 0' "$rc" 0
expect 'spaced local path: cold cache has the source commit and items' \
  "$(head_of "$SLUG")|$(content "$SLUG" docs/a.md)|$(content "$SLUG" docs/b.md)" \
  "$spaced_cold|A v1|B cold only"
expect 'spaced local path: clone uses the expanded home path' \
  "$(git -C "$(cache "$SLUG")" remote get-url origin 2>/dev/null)" "$LOCAL"

git -C "$LOCAL" rm -q docs/b.md
printf 'A v2\n' > "$LOCAL/docs/a.md"
printf 'C warm only\n' > "$LOCAL/docs/c.md"
spaced_warm=$(commit "$LOCAL" warm)

run "$SYNC" "$WARM" "$WARM_LOCAL"; rc=$?
expect 'spaced local path: warm sync exits 0' "$rc" 0
expect 'spaced local path: warm cache updates, removes and adds items' \
  "$(head_of "$SLUG")|$(content "$SLUG" docs/a.md)|$(exists "$SLUG" docs/b.md)|$(content "$SLUG" docs/c.md)" \
  "$spaced_warm|A v2|no|C warm only"

run "$STATUS" '**Local path** (expand'; rc=$?
expect 'spaced local path: status reports local reachability with exit 0' "$rc" 0

if [ "${1:-}" = --local-space ]; then finish; fi

slug_checks
hostile_file_checks

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

URL=file://$U REV=$C1 FILTER='docs/**/*.md' DIRS=docs SLUG=tier2
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
URL=file://$T/up-v0.git REV=$C1 FILTER='docs/**/*.md' DIRS=docs SLUG=tier3
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

URL=file://$W REV='' FILTER='docs/**/*.md' DIRS=docs SLUG=warm
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

FILTER='docs/**/*.md' DIRS=docs SLUG=warm
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
URL=file://$W REV='' FILTER='docs/**/*.md' DIRS=docs SLUG=cone
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

# --- Markdown-only caches: default patterns and path_filter --------------------

echo
echo "Markdown-only caches  (default patterns with no path_filter, *.md filters)"

files_of() {
  (cd "$(cache "$1")" && find . -name .git -prune -o -type f ! -name .manifest.json -print) \
    | sed 's|^\./||' | sort | tr '\n' ' ' | sed 's/ $//'
}

M=$T/md; new_repo "$M"; serve "$M"
mkdir -p "$M/.specify/memory" "$M/.github/docs" "$M/.wibey" "$M/docs" "$M/specs/.drafts" "$M/src"
for f in .specify/memory/constitution.md .github/docs/guide.md .wibey/agent.md AGENTS.md CLAUDE.md GEMINI.md \
         docs/AGENTS.md docs/a.md specs/.drafts/d.md README.md .notes.md; do
  printf '%s\n' "$f" > "$M/$f"
done
printf '{}\n' > "$M/package.json"; printf 'x\n' > "$M/src/app.ts"; printf 'png\n' > "$M/docs/diagram.png"
commit "$M" md >/dev/null
KEPT='.notes.md README.md docs/a.md specs/.drafts/d.md'

URL=file://$M REV='' FILTER='' DIRS=. SLUG=md-default
run "$SYNC" "$TIER1" "$NOFILTER"; rc=$?
expect "no path_filter: the cold sparse step exits 0" "$rc" 0
expect "no path_filter: only .md files outside root dot-directories and agent files are cached" \
       "$(files_of md-default)" "$KEPT"
expect "no path_filter: the cache is a sparse checkout" \
       "$(git -C "$(cache md-default)" config core.sparseCheckout)" true
items_of
expect "no path_filter: items match the cached files" "$(joined items)" "$KEPT"

LOCAL=$M SLUG=md-default-local
run "$SYNC" "$LOCAL_COLD" "$NOFILTER"
expect "no path_filter, local source: the same default patterns apply" "$(files_of md-default-local)" "$KEPT"

FILTER='docs/**/*.md' DIRS=docs SLUG=md-filter
run "$SYNC" "$TIER1" "$SPARSE"
expect "path_filter: only .md files under the filter are cached, no images" \
       "$(files_of md-filter)" "docs/AGENTS.md docs/a.md"
items_of
expect "path_filter: agent files under an explicit filter are honored" "$(joined items)" "docs/AGENTS.md docs/a.md"

FILTER='.github/docs/**/*.md' DIRS=.github/docs SLUG=md-dotdir
run "$SYNC" "$TIER1" "$SPARSE"
items_of
expect "path_filter into a dot-directory is honored as written" \
       "$(files_of md-dotdir)|$(joined items)" ".github/docs/guide.md|.github/docs/guide.md"

# Before the default patterns, a cache with no path_filter was a full checkout.
FILTER='' DIRS=. SLUG=md-full
c=$(cache md-full)
git clone -q -c core.symlinks=false --filter=blob:none --no-checkout --depth=1 -- "$URL" "$c" 2>/dev/null
git -C "$c" checkout -q HEAD -- . 2>/dev/null
printf '{}\n' > "$c/.manifest.json"
expect "a full-checkout cache starts with code and .specify/" \
       "$(exists md-full package.json)|$(exists md-full .specify/memory/constitution.md)" "yes|yes"
items_of
expect "...yet its items already leave out dot-directories and agent files" "$(joined items)" "$KEPT"
run "$SYNC" "$WARM"; rc=$?
check "...the warm sparse step succeeds with no path_filter" [ "$rc" -eq 0 ]
run "$SYNC" "$WARM_REMOTE"
expect "...and its next warm sync prunes it to the default patterns" "$(files_of md-full)" "$KEPT"
expect "...keeping the untracked .manifest.json" "$(exists md-full .manifest.json)" yes

# Before the /**/*.md suffix, a filtered cache held every file under the filter.
FILTER='docs/**/*.md' DIRS=docs SLUG=md-oldfilter
c=$(cache md-oldfilter)
git clone -q -c core.symlinks=false --filter=blob:none --no-checkout --depth=1 -- "$URL" "$c" 2>/dev/null
git -C "$c" sparse-checkout init --no-cone 2>/dev/null
git -C "$c" sparse-checkout set -- 'docs/' 2>/dev/null; git -C "$c" checkout -q 2>/dev/null
expect "an old-pattern filtered cache starts with non-.md files" "$(exists md-oldfilter docs/diagram.png)" yes
run "$SYNC" "$WARM" "$WARM_REMOTE"
expect "...and loses them on its next warm sync" "$(files_of md-oldfilter)" "docs/AGENTS.md docs/a.md"

# --- D4: symbolic links ------------------------------------------------------

echo
echo "Symbolic links in a source"

SLUG=tier2 FILTER='docs/**/*.md' DIRS=docs; items_of
expect "a link is checked out as a plain file" "$(kind tier2 docs/notes.md)" file
expect "items are the regular files git does not record as links" "$(joined items)" "docs/a.md docs/b.md"
expect "every link is reported" "$(joined links)" "docs/linked docs/notes.md docs/rel.md"

SLUG=legacy FILTER='' DIRS=.; items_of
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

finish
