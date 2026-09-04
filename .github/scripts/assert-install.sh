#!/usr/bin/env bash
# Asserts that a real `specify extension add` produced what the manifest promised.
#
# Shared by both workflows — validate.yml (pinned spec-kit, gates PRs) and
# upstream-compat.yml (spec-kit main, advisory). Keeping one copy matters: if the
# two drifted, the compatibility job could go green on a check the gating job no
# longer performs, which is worse than not having it.
#
# Every assertion derives from the manifest rather than a hardcoded number, so
# adding a sixth command needs no edit here.
#
# Usage:  assert-install.sh <consumer-dir> <repo-root>
#
set -uo pipefail

CONSUMER="${1:-/tmp/consumer}"
REPO="${2:-${GITHUB_WORKSPACE:-$(cd "$(dirname "$0")/../.." && pwd)}}"
MANIFEST="$REPO/extension.yml"

cd "$CONSUMER" || { echo "no consumer project at $CONSUMER"; exit 1; }

fail=0
ok()  { printf '  \033[32mPASS\033[0m  %s\n' "$1"; }
bad() { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; fail=1; }

m() { python3 -c "import yaml;d=yaml.safe_load(open('$MANIFEST'));$1"; }

EXT_ID=$(m "print(d['extension']['id'])")
VERSION=$(m "print(d['extension']['version'])")
NCMD=$(m "print(len(d['provides']['commands']))")
NHOOK=$(m "print(len(d.get('hooks') or {}))")
DEST=".specify/extensions/$EXT_ID"

# Quality Gate §1 — the install must not warn about the config template. This is
# the exact string spec-kit printed while the config silently failed to scaffold
# in 1.1.0, which also meant `extension add --force` would delete it.
grep -qi 'not scaffolded' install.log \
  && bad "spec-kit refused to scaffold the config template" \
  || ok  "no config-scaffolding warning"

# ...and the file it promised must actually be on disk.
CFG=$(m "
c = (d.get('provides', {}).get('config') or [])
print(c[0]['name'] if c else '')")
if   [ -z "$CFG" ];        then ok  "manifest declares no config template"
elif [ -f "$DEST/$CFG" ];  then ok  "config scaffolded: $CFG"
else                            bad "config declared but not created: $DEST/$CFG"
fi

# Quality Gate §2 — every declared command is registered. Match "• speckit."
# specifically: the install output also bullets the scaffolded config, and
# counting every bullet reports one too many (a false red on a correct install).
got=$(grep -cE '• speckit\.' install.log || echo 0)
[ "$got" -eq "$NCMD" ] \
  && ok "all $NCMD commands registered" \
  || bad "manifest declares $NCMD commands, install reported $got"

# Quality Gate §3 — the version a consumer sees is the version we shipped.
grep -q "v$VERSION" install.log \
  && ok "installed version reported as v$VERSION" \
  || bad "install did not report v$VERSION"

# BLOCKER v1.2.0 #3 — .extensionignore gaps once copied 110 files into the
# consumer, 86 of them belonging to other extensions entirely.
n=$(find "$DEST" -type f | wc -l | tr -d ' ')
[ "$n" -lt 30 ] \
  && ok "installed file count is sane ($n)" \
  || { bad "install copied $n files — check .extensionignore"; \
       find "$DEST" -type f | head -20; }

# Hooks must auto-register, and must stay argument-free: that is what keeps
# --force unreachable from an automatic trigger (FR-022), by construction rather
# than by a runtime check.
python3 - "$EXT_ID" "$NHOOK" <<'PY' || fail=1
import sys, yaml
ext, expected = sys.argv[1], int(sys.argv[2])
hooks = (yaml.safe_load(open('.specify/extensions.yml')) or {}).get('hooks') or {}
mine = [(ev, e) for ev, es in hooks.items()
        for e in (es if isinstance(es, list) else [es])
        if e.get('extension') == ext]
if len(mine) != expected:
    print(f'  \033[31mFAIL\033[0m  manifest declares {expected} hooks, {len(mine)} registered')
    sys.exit(1)
armed = [ev for ev, e in mine if 'args' in e or 'arguments' in e]
if armed:
    print(f'  \033[31mFAIL\033[0m  hook(s) carry arguments, breaking FR-022: {armed}')
    sys.exit(1)
print(f'  \033[32mPASS\033[0m  {expected} hooks registered, none carrying arguments')
PY

echo
[ "$fail" -eq 0 ] || { echo "Smoke test failed."; exit 1; }
echo "Smoke test passed."
