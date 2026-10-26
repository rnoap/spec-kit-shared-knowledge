#!/usr/bin/env bash
# Static validation of the extension package.
#
# Every check below traces to a real defect that shipped, or nearly shipped, in
# this repository. The blocker each one would have caught is named in its output.
# Runnable locally — run it before you push, not just in CI:
#
#   bash .github/scripts/validate-extension.sh
#
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1

pass=0; fail=0
ok()   { printf '  \033[32mPASS\033[0m  %s\n' "$1"; pass=$((pass+1)); }
bad()  { printf '  \033[31mFAIL\033[0m  %s\n'  "$1"; fail=$((fail+1)); }
note() { printf '        %s\n' "$1"; }

y() { python3 -c "
import sys, yaml
d = yaml.safe_load(open('extension.yml'))
$1" 2>/dev/null
}

echo
echo "Package manifest"

# --- extension.yml parses and carries the keys spec-kit requires ------------
if python3 -c "import yaml; yaml.safe_load(open('extension.yml'))" 2>/dev/null; then
  ok "extension.yml is valid YAML"
else
  bad "extension.yml is not valid YAML"
  echo; echo "Cannot continue — fix the manifest first."; exit 1
fi

VERSION=$(y "print(d['extension']['version'])")
EXT_ID=$(y "print(d['extension']['id'])")
[ -n "$VERSION" ] && ok "manifest declares a version ($VERSION)" \
                  || bad "extension.version is missing"

# --- BLOCKER v1.2.0 #1 and #2 ----------------------------------------------
# spec-kit's ExtensionManager._target_follows_preserved_convention only accepts
# a config target ending in -config.yml / -config.local.yml. Anything else is
# silently NOT scaffolded, and is rmtree'd by `extension add --force` and by
# `extension remove --keep-config` — so a bad name can destroy a user's source
# list on reinstall. This shipped once. It must never ship again.
bad_names=$(y "
for c in d.get('provides', {}).get('config', []) or []:
    n = c.get('name', '')
    if not (n.endswith('-config.yml') or n.endswith('-config.local.yml')) or '/' in n:
        print(n)
")
if [ -z "$bad_names" ]; then
  ok "every provides.config[].name follows the preserved-file convention"
else
  bad "provides.config[].name will NOT be scaffolded, and is deleted by --force"
  note "offending: $bad_names"
  note "must end in -config.yml or -config.local.yml, with no '/'"
fi

# --- BLOCKER v1.2.0 #4 ------------------------------------------------------
# `location` is not part of the manifest schema; config always deploys under
# .specify/extensions/<id>/. Unknown keys are ignored silently, so a typo here
# is invisible until someone reads the installed result.
unknown=$(y "
allowed = {'name', 'template', 'description', 'required'}
for c in d.get('provides', {}).get('config', []) or []:
    for k in c:
        if k not in allowed: print(k)
")
[ -z "$unknown" ] && ok "provides.config[] uses only schema keys" \
                  || { bad "provides.config[] has unsupported key(s): $unknown"; \
                       note "allowed: name, template, description, required"; }

# --- a command entry pointing at a missing file installs a broken extension --
missing=$(y "
import os
for c in d['provides']['commands']:
    if not os.path.exists(c['file']): print(c['file'])
")
[ -z "$missing" ] && ok "every provides.commands[].file exists" \
                  || { bad "command file(s) declared but not present: $missing"; }

# --- spec-kit enforces ^speckit\.<ext-id>\.<command>$ -----------------------
misnamed=$(y "
import re
pat = re.compile(r'^speckit\.' + re.escape(d['extension']['id']) + r'\.[a-z][a-z-]*\$')
for c in d['provides']['commands']:
    if not pat.match(c['name']): print(c['name'])
")
[ -z "$misnamed" ] && ok "command names match speckit.$EXT_ID.<verb>" \
                   || bad "command name(s) violate the required pattern: $misnamed"

echo
echo "Agent portability"

# --- BLOCKER v1.2.0 #5 ------------------------------------------------------
# Command bodies must reference sibling commands through __SPECKIT_COMMAND_*__
# tokens. A hard-coded "/speckit.knowledge.sync" is correct for slash agents
# only, and breaks on Codex/ZCode ($name), Kimi (/skill:name), and any agent
# with a different separator. Spec Kit renders the token per agent.
hardcoded=$(grep -rnE '[/$]speckit[.-]' commands/*.md 2>/dev/null \
            | grep -v '__SPECKIT_COMMAND_' || true)
if [ -z "$hardcoded" ]; then
  ok "command bodies use agent-neutral __SPECKIT_COMMAND_*__ tokens"
else
  bad "command bodies hard-code an agent-specific invocation"
  echo "$hardcoded" | sed 's/^/        /'
fi

# --- 1.9.1: `remove <label> --disable` purged a cache ------------------------
# Arguments reach a command only through $ARGUMENTS. Without spec-kit's labelled
# "## User Input" block they sat in documentation prose, the agent missed them,
# fell into the no-identifier picker and ran the destructive default mode.
noinput=$(y "
import re
pat = re.compile(r'^## User Input\n\n\`\`\`text\n\\\$ARGUMENTS\n\`\`\`\n', re.M)
for c in d['provides']['commands']:
    if not pat.search(open(c['file'], encoding='utf-8').read()): print(c['file'])
")
[ -z "$noinput" ] && ok "every command receives its arguments in a ## User Input block" \
                  || bad "command(s) missing the ## User Input \$ARGUMENTS block: $noinput"

echo
echo "Documentation consistency  (Constitution § Quality Gates)"

# --- BLOCKER v1.2.0 #7: badge pinned at 1.0.0 while the manifest was 1.1.0 ---
badge=$(grep -oE 'badge/status-v[0-9]+\.[0-9]+\.[0-9]+' README.md 2>/dev/null \
        | head -1 | sed 's|badge/status-v||')
if [ "$badge" = "$VERSION" ]; then
  ok "README badge matches the manifest ($VERSION)"
else
  bad "README badge is v${badge:-<none>} but the manifest is v$VERSION"
fi

# --- BLOCKER v1.2.0 #8: CHANGELOG entry was "[1.0.0] - TBD" -----------------
if grep -q "^## \[$VERSION\]" CHANGELOG.md 2>/dev/null; then
  ok "CHANGELOG has an entry for $VERSION"
else
  bad "CHANGELOG has no '## [$VERSION]' section"
fi

# --- Quality Gate §5: README must mirror provides.commands ------------------
undocumented=$(y "
readme = open('README.md').read()
for c in d['provides']['commands']:
    if '/' + c['name'] not in readme: print(c['name'])
")
[ -z "$undocumented" ] && ok "README documents every provided command" \
                       || bad "command(s) missing from README: $undocumented"

echo
echo "Configure label contract"
CONFIGURE=commands/speckit.knowledge.configure.md
if grep -Fq -- '`--label <label>`' "$CONFIGURE" \
   && grep -Fq 'If `--label <label>` was provided, use that value exactly.' "$CONFIGURE" \
   && grep -Fq 'Reject an explicit label that is empty or contains whitespace' "$CONFIGURE" \
   && grep -Fq 'exclude that entry from the collision check' "$CONFIGURE" \
   && grep -Fq 'label when one was explicitly provided; otherwise retain' "$CONFIGURE" \
   && grep -Fq 'appears more than once' "$CONFIGURE"; then
  ok "configure command documents optional label parsing and validation"
else
  bad "configure command is missing optional label parsing or validation"
fi
if grep -Fq -- 'https://github.com/your-org/payment-service --label payments-v2 specs/ docs/decisions/' README.md \
   && grep -Fq 'Use the derived label by omitting the optional label' README.md; then
  ok "README shows a chosen label with filters and the optional default"
else
  bad "README is missing chosen-label or derived-label usage examples"
fi

echo
echo "Published artifact"

# --- BLOCKER v1.2.0: the catalog download_url is the git archive. Without
# --- .gitattributes export-ignore, every published zip shipped this repo's own
# --- .specify/ workspace, including four vendored third-party extensions.
leaked=$(git archive --format=tar HEAD 2>/dev/null | tar -tf - 2>/dev/null \
         | grep -E '^\.specify/|^\.github/|^specs/|^\.claude/|^\.wibey/|^\.agents/|^AGENTS\.md|^skills-lock\.json' || true)
if [ -z "$leaked" ]; then
  ok "git archive contains no dev-only paths"
else
  bad "dev-only paths leak into the published archive"
  echo "$leaked" | head -5 | sed 's/^/        /'
  note "check .gitattributes export-ignore rules"
fi

echo
echo "Repository invariants"

# --- FR-022: the freshness policy must always apply to hook-driven syncs. ----
# That is guaranteed structurally, by the hook entries taking no arguments —
# not by a runtime check. Adding one would silently let a hook pass --force.
hookargs=$(y "
for name, h in (d.get('hooks') or {}).items():
    if 'args' in h or 'arguments' in h: print(name)
")
[ -z "$hookargs" ] && ok "no hook declares arguments (keeps --force unreachable)" \
                   || { bad "hook(s) declare arguments, breaking FR-022: $hookargs"; }

# --- FR-029: the validation rules are duplicated into every reading command
# --- on purpose. Constitution §I forbids extracting them to a shared file:
# --- spec-kit would not install it and every command would break at runtime.
# --- Duplication is only safe while the copies stay identical.
blocks=$(for f in commands/speckit.knowledge.configure.md \
                  commands/speckit.knowledge.sync.md \
                  commands/speckit.knowledge.status.md; do
           [ -f "$f" ] && awk '/^## Configuration Validation Rules$/,/^## Behavior$/' "$f" \
             | shasum -a 256 | cut -d' ' -f1
         done | sort -u | wc -l | tr -d ' ')
if [ "$blocks" = "1" ]; then
  ok "the three Configuration Validation Rules blocks are byte-identical"
else
  bad "the duplicated validation blocks have drifted apart ($blocks variants)"
  note "they must stay identical — see Constitution §I on hidden dependencies"
fi

scan_configuration_quotes() {
python3 - <<'PY'
import re
import sys
from pathlib import Path

placeholder = re.compile(r'<[A-Za-z][A-Za-z0-9_-]*>')


def unsafe_placeholders(lines):
    context = 'unquoted'
    escaped = False
    ambiguous = False
    occurrences = []
    for number, line in lines:
      if context == 'unquoted' and not escaped and line.lstrip().startswith('#'):
        continue
      position = 0
      while position < len(line):
        match = placeholder.match(line, position)
        if match and match.group() != '<slug>':
          occurrences.append((number, match.group(), context == 'single' and not ambiguous))
        character = line[position]
        following = line[position:position + 2]
        if escaped:
          escaped = False
        elif context == 'single':
          if character == "'":
            context = 'unquoted'
        elif character == '\\':
          escaped = True
        elif context == 'ansi':
          if character == "'":
            context = 'unquoted'
        elif context == 'double':
          if following in ('$(', '${') or character == '`':
            ambiguous = True
          if character == '"':
            context = 'unquoted'
        elif following == "$'":
          context = 'ansi'
          position += 1
        elif following in ('${', '<<') or character == '`':
          ambiguous = True
        elif character == "'":
          context = 'single'
        elif character == '"':
          context = 'double'
        position += 1
    findings = {}
    for number, name, safe in occurrences:
      if not safe or context != 'unquoted':
        findings.setdefault(number, []).append(name)
    return findings


fixtures = [
    ("git clone -- '<url>'", True),
    ("test -d '<expanded-path>/.git'", True),
    ("url='<url>'", True),
    ("git clone -- <url>", False),
    ('git clone -- "<url>"', False),
    ('git clone -- "\'<url>\'"', False),
    (r"git clone -- \'<url>\'", False),
    ("git clone -- $'<url>'", False),
    ('git clone -- "\\\n\'<url>\'"', False),
    ('git clone -- "\n\'<url>\'"', False),
    ("git clone -- \\\n\\'<url>\\'", False),
    ("git clone -- '\n<url>'", True),
    ("git clone -- '<url>", False),
    ('echo "$(printf "\'<url>\'")"', False),
    ("# git clone -- <url>\ngit clone -- '<url>'", True),
    ('printf "\n# <url>\n"', False),
    ("git clone -- <slug>", True),
]
for fixture, expected in fixtures:
    accepted = not unsafe_placeholders(enumerate(fixture.splitlines(keepends=True), 1))
    if accepted != expected:
      print('scanner fixture misclassified: ' + repr(fixture))
      sys.exit(2)

findings = []
for path in sorted(Path('commands').glob('*.md')):
    block = None
    for number, line in enumerate(path.read_text().splitlines(keepends=True), 1):
      if block is None:
        if line.rstrip() == '```bash':
          block = []
      elif line.rstrip() == '```':
        for location, names in unsafe_placeholders(block).items():
          findings.append(f'{path}:{location}: ' + ' '.join(names))
        block = None
      else:
        block.append((number, line))
    if block is not None:
      for location, names in unsafe_placeholders(block).items():
        findings.append(f'{path}:{location}: ' + ' '.join(names))
print('\n'.join(findings), end='\n' if findings else '')
sys.exit(1 if findings else 0)
PY
}
quote_findings=$(scan_configuration_quotes)
quote_exit=$?
if [ "$quote_exit" -eq 2 ]; then
    bad "inert quote scanner fixtures failed"
    note "$quote_findings"
elif [ "$quote_exit" -gt 2 ]; then
    bad "configuration placeholder scanner could not run"
    note "$quote_findings"
else
    ok "inert quote scanner fixtures distinguish effective single quotes"
    if [ "$quote_exit" -eq 0 ]; then
    ok "every configuration placeholder in a bash block is single-quoted"
    else
    quote_lines=$(printf '%s\n' "$quote_findings" | wc -l | tr -d ' ')
    bad "configuration placeholders reach the shell unquoted ($quote_lines lines)"
    printf '%s\n' "$quote_findings" | sed 's/^/        /'
    note "quote each one: '<name>' (007 FR-006)"
    fi
fi

echo
if [ "$fail" -eq 0 ]; then
  printf '\033[32m%s checks passed.\033[0m\n\n' "$pass"
  exit 0
fi
printf '\033[31m%s failed\033[0m, %s passed.\n\n' "$fail" "$pass"
exit 1
