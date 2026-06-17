#!/usr/bin/env bash
# install-local.sh — install spec-kit-shared-knowledge into a local spec-kit project
#
# Usage:
#   bash scripts/install-local.sh                        # installs into current working directory
#   bash scripts/install-local.sh /path/to/project       # installs into a specific project
#
# What this does:
#   1. Copies command files → .specify/extensions/shared-knowledge/commands/
#   2. Copies extension.yml + config-template → .specify/extensions/shared-knowledge/
#   3. Registers in .specify/extensions/.registry
#   4. Generates SKILL.md wrappers in .wibey/skills/ AND .claude/skills/
#      (same pattern as built-in extensions like git and brownfield)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXTENSION_ROOT="$(dirname "$SCRIPT_DIR")"
EXTENSION_ID="shared-knowledge"
PROJECT_DIR="${1:-$(pwd)}"
REGISTRY="${PROJECT_DIR}/.specify/extensions/.registry"
EXT_DIR="${PROJECT_DIR}/.specify/extensions/${EXTENSION_ID}"

echo "Installing ${EXTENSION_ID} into: ${PROJECT_DIR}"

# --- Validate target is a spec-kit project ---
if [ ! -d "${PROJECT_DIR}/.specify/extensions" ]; then
  echo "❌ Error: ${PROJECT_DIR} does not look like a spec-kit project (.specify/extensions not found)"
  exit 1
fi

# --- Copy command files to extension dir ---
mkdir -p "${EXT_DIR}/commands"
INSTALLED=0
for src in "${EXTENSION_ROOT}/commands/"speckit.xrepo.*.md; do
  [ -f "$src" ] || continue
  cp "$src" "${EXT_DIR}/commands/$(basename "$src")"
  echo "  ✓ commands/$(basename "$src")"
  INSTALLED=$((INSTALLED + 1))
done
echo "${INSTALLED} command(s) → ${EXT_DIR}/commands/"

# --- Copy extension.yml ---
cp "${EXTENSION_ROOT}/extension.yml" "${EXT_DIR}/extension.yml"
echo "  ✓ extension.yml"

# --- Copy config template (skip if config already exists) ---
CONFIG_FILE="${EXT_DIR}/shared-knowledge.yml"
if [ -f "$CONFIG_FILE" ]; then
  echo "  ℹ️  shared-knowledge.yml already exists — not overwriting"
else
  cp "${EXTENSION_ROOT}/config-template.yml" "$CONFIG_FILE"
  echo "  ✓ shared-knowledge.yml (from config-template)"
fi

# --- Register in .registry ---
if [ ! -f "$REGISTRY" ]; then
  echo "❌ Error: .registry not found at ${REGISTRY}"
  exit 1
fi

if command -v sha256sum >/dev/null 2>&1; then
  HASH=$(sha256sum "${EXT_DIR}/extension.yml" | cut -c1-64)
else
  HASH=$(shasum -a 256 "${EXT_DIR}/extension.yml" | cut -c1-64)
fi
INSTALLED_AT=$(date -u +"%Y-%m-%dT%H:%M:%S.000000+00:00")

python3 - <<PYEOF
import json
registry_path = "${REGISTRY}"
with open(registry_path) as f:
    reg = json.load(f)
ext = reg.setdefault("extensions", {})
if "${EXTENSION_ID}" in ext:
    print("  ℹ️  Already registered — updating entry")
ext["${EXTENSION_ID}"] = {
    "version": "1.0.0",
    "source": "local",
    "manifest_hash": "sha256:${HASH}",
    "enabled": True,
    "priority": 10,
    "registered_commands": {
        "claude": [
            "speckit.xrepo.configure",
            "speckit.xrepo.sync",
            "speckit.xrepo.search",
            "speckit.xrepo.status"
        ]
    },
    "registered_skills": [],
    "installed_at": "${INSTALLED_AT}"
}
with open(registry_path, "w") as f:
    json.dump(reg, f, indent=2)
    f.write("\n")
print("  ✓ registered in .registry")
PYEOF

# --- Generate SKILL.md wrappers in .wibey/skills/ and .claude/skills/ ---
# Same pattern as git/brownfield extensions: frontmatter wrapper + command body
echo ""
echo "Generating Wibey/Claude skill wrappers..."

generate_skill() {
  local cmd_file="$1"
  local target_dir="$2"
  local cmd_base
  cmd_base="$(basename "$cmd_file" .md)"               # speckit.xrepo.configure
  local skill_name
  skill_name="$(echo "$cmd_base" | sed 's/\./-/g')"   # speckit-xrepo-configure

  # Extract description from frontmatter (line starting with "description:")
  local description
  description=$(grep '^description:' "$cmd_file" | head -1 | sed 's/^description:[[:space:]]*//' | sed 's/^"//' | sed 's/"$//')

  # Extract body (everything after closing ---)
  local body
  body=$(awk '/^---/{found++; if(found==2){found=3; next}} found==3{print}' "$cmd_file")

  local skill_dir="${target_dir}/${skill_name}"
  mkdir -p "$skill_dir"

  cat > "${skill_dir}/SKILL.md" <<SKILL
---
name: ${skill_name}
description: ${description}
compatibility: Requires spec-kit project structure with .specify/ directory
metadata:
  author: walmart-developer-experience
  source: shared-knowledge:commands/${cmd_base}.md
---
${body}
SKILL

  echo "  ✓ ${skill_name}"
}

for src in "${EXT_DIR}/commands/"speckit.xrepo.*.md; do
  [ -f "$src" ] || continue
  generate_skill "$src" "${PROJECT_DIR}/.wibey/skills"
  generate_skill "$src" "${PROJECT_DIR}/.claude/skills"
done

# --- .gitignore: idempotent auto-append ---
GITIGNORE="${PROJECT_DIR}/.gitignore"
CACHE_ENTRY=".specify/extensions/shared-knowledge/cache/"
INDEX_ENTRY=".specify/extensions/shared-knowledge/knowledge-index.md"

touch "$GITIGNORE"
if ! grep -qF "$CACHE_ENTRY" "$GITIGNORE"; then
  printf "\n# shared-knowledge cache (local only; do not commit)\n%s\n%s\n" \
    "$CACHE_ENTRY" "$INDEX_ENTRY" >> "$GITIGNORE"
  echo "  → Added .gitignore entries for cache/ and knowledge-index.md"
elif ! grep -qF "$INDEX_ENTRY" "$GITIGNORE"; then
  printf "%s\n" "$INDEX_ENTRY" >> "$GITIGNORE"
  echo "  → Added .gitignore entry for knowledge-index.md"
else
  echo "  → .gitignore entries already present (skipped)"
fi

echo ""
echo "Done. Reload Wibey (Ctrl+Shift+P → 'Wibey: Reload') to pick up the new commands."
