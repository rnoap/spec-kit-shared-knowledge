#!/usr/bin/env bash
# install-local.sh — install spec-kit-shared-knowledge into a local project for dev/testing
#
# Usage:
#   bash scripts/install-local.sh                        # installs into current working directory
#   bash scripts/install-local.sh /path/to/project       # installs into a specific project
#   bash scripts/install-local.sh --global               # installs commands to ~/.wibey/commands/

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
  CONFIG_DIR=""
  echo "Installing commands globally → ${COMMANDS_DIR}/"
else
  PROJECT_DIR="${TARGET_PROJECT:-$(pwd)}"
  COMMANDS_DIR="${PROJECT_DIR}/.wibey/commands"
  CONFIG_DIR="${PROJECT_DIR}/.specify/extensions/${EXTENSION_ID}"
  echo "Installing into project: ${PROJECT_DIR}"
fi

# --- Install commands (bash 3.2 compatible — no associative arrays) ---
mkdir -p "${COMMANDS_DIR}"

INSTALLED=0
for src in "${EXTENSION_ROOT}/commands/"speckit.xrepo.*.md; do
  [ -f "$src" ] || continue
  # speckit.xrepo.configure.md → speckit-xrepo-configure.md
  dst_name="$(basename "$src" | sed 's/\./-/g')"
  dst="${COMMANDS_DIR}/${dst_name}"
  cp "$src" "$dst"
  echo "  ✓ /$(basename "$dst" .md)"
  INSTALLED=$((INSTALLED + 1))
done

echo "${INSTALLED} command(s) installed → ${COMMANDS_DIR}/"

# --- Install extension.yml so `specify extension list` recognises it ---
if [ -n "${CONFIG_DIR:-}" ]; then
  mkdir -p "${CONFIG_DIR}"

  EXT_YML="${CONFIG_DIR}/extension.yml"
  cp "${EXTENSION_ROOT}/extension.yml" "${EXT_YML}"
  echo "  ✓ extension.yml → ${EXT_YML}"

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
