#!/usr/bin/env bash
# install-local.sh — install spec-kit-shared-knowledge into a local spec-kit project
#
# Usage:
#   bash scripts/install-local.sh                        # installs into current working directory
#   bash scripts/install-local.sh /path/to/project       # installs into a specific project
#
# What this does:
#   1. Copies command files → .specify/extensions/shared-knowledge/commands/
#   2. Copies extension.yml → .specify/extensions/shared-knowledge/extension.yml
#   3. Copies config-template.yml → .specify/extensions/shared-knowledge/shared-knowledge.yml
#      (only if not already present)
#   4. Registers the extension in .specify/extensions/.registry

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

# --- Copy command files ---
mkdir -p "${EXT_DIR}/commands"
INSTALLED=0
for src in "${EXTENSION_ROOT}/commands/"speckit.xrepo.*.md; do
  [ -f "$src" ] || continue
  dst="${EXT_DIR}/commands/$(basename "$src")"
  cp "$src" "$dst"
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

# Compute manifest hash from extension.yml
if command -v sha256sum >/dev/null 2>&1; then
  HASH=$(sha256sum "${EXT_DIR}/extension.yml" | cut -c1-64)
else
  HASH=$(shasum -a 256 "${EXT_DIR}/extension.yml" | cut -c1-64)
fi
INSTALLED_AT=$(date -u +"%Y-%m-%dT%H:%M:%S.000000+00:00")

python3 - <<PYEOF
import json, sys

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

# --- .gitignore reminder ---
echo ""
echo "Remember to add to .gitignore:"
echo "  .specify/extensions/shared-knowledge/cache/"
echo "  .specify/extensions/shared-knowledge/knowledge-index.md"
echo ""
echo "Done. Run: specify extension list"
