#!/usr/bin/env bash
# install-local.sh — install spec-kit-shared-knowledge into a local project for dev/testing
#
# Usage:
#   bash scripts/install-local.sh                        # installs into current working directory
#   bash scripts/install-local.sh /path/to/project       # installs into a specific project
#   bash scripts/install-local.sh --global               # installs commands to ~/.wibey/commands/
#
# What this does:
#   1. Copies the 4 command files to <project>/.wibey/commands/ (or ~/.wibey/commands/)
#   2. Copies config-template.yml to <project>/.specify/extensions/shared-knowledge/shared-knowledge.yml
#      (only if not already present — never overwrites existing config)
#
# After install:
#   - Edit .specify/extensions/shared-knowledge/shared-knowledge.yml to add your sources
#   - Run /speckit-xrepo-configure or /speckit-xrepo-sync in Wibey

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXTENSION_ROOT="$(dirname "$SCRIPT_DIR")"
EXTENSION_ID="shared-knowledge"

# --- Parse arguments ---
GLOBAL=false
TARGET_PROJECT=""

for arg in "$@"; do
  case "$arg" in
    --global) GLOBAL=true ;;
    -*) echo "Unknown flag: $arg"; exit 1 ;;
    *) TARGET_PROJECT="$arg" ;;
  esac
done

if [ "$GLOBAL" = true ]; then
  COMMANDS_DIR="${HOME}/.wibey/commands"
  CONFIG_DIR=""   # global install doesn't write config (project-specific)
  echo "Installing commands globally → ${COMMANDS_DIR}/"
else
  PROJECT_DIR="${TARGET_PROJECT:-$(pwd)}"
  COMMANDS_DIR="${PROJECT_DIR}/.wibey/commands"
  CONFIG_DIR="${PROJECT_DIR}/.specify/extensions/${EXTENSION_ID}"
  echo "Installing into project: ${PROJECT_DIR}"
fi

# --- Install commands ---
mkdir -p "${COMMANDS_DIR}"

declare -A CMD_MAP=(
  ["speckit.xrepo.configure.md"]="speckit-xrepo-configure.md"
  ["speckit.xrepo.sync.md"]="speckit-xrepo-sync.md"
  ["speckit.xrepo.search.md"]="speckit-xrepo-search.md"
  ["speckit.xrepo.status.md"]="speckit-xrepo-status.md"
)

INSTALLED=0
for src_name in "${!CMD_MAP[@]}"; do
  src="${EXTENSION_ROOT}/commands/${src_name}"
  dst="${COMMANDS_DIR}/${CMD_MAP[$src_name]}"
  if [ -f "$src" ]; then
    cp "$src" "$dst"
    echo "  ✓ /$(basename "$dst" .md)"
    INSTALLED=$((INSTALLED + 1))
  else
    echo "  ✗ Missing source: $src" >&2
  fi
done

echo "${INSTALLED} command(s) installed → ${COMMANDS_DIR}/"

# --- Install config template (project installs only) ---
if [ -n "${CONFIG_DIR:-}" ]; then
  mkdir -p "${CONFIG_DIR}"
  CONFIG_FILE="${CONFIG_DIR}/shared-knowledge.yml"
  if [ -f "$CONFIG_FILE" ]; then
    echo ""
    echo "  ℹ️  Config already exists — not overwriting: ${CONFIG_FILE}"
  else
    cp "${EXTENSION_ROOT}/config-template.yml" "$CONFIG_FILE"
    echo ""
    echo "  ✓ Config template written → ${CONFIG_FILE}"
    echo "  → Edit this file to add your knowledge sources, then run /speckit-xrepo-sync"
  fi
fi

# --- .gitignore reminder ---
echo ""
echo "Remember to add these lines to your .gitignore:"
echo "  .specify/extensions/shared-knowledge/cache/"
echo "  .specify/extensions/shared-knowledge/knowledge-index.md"
echo ""
echo "Done. Reload Wibey (Ctrl+Shift+P → 'Wibey: Reload') to pick up the new commands."
