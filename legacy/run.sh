#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_PATH="${1:-$SCRIPT_DIR/config.json}"
BINARY_PATH="$SCRIPT_DIR/xbox-controller-shortcuts"
SOURCE_PATH="$SCRIPT_DIR/main.m"

if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "Config not found: $CONFIG_PATH" >&2
  echo "Copy config.sample.json to config.json and edit it first." >&2
  exit 1
fi

if [[ ! -x "$BINARY_PATH" || "$SOURCE_PATH" -nt "$BINARY_PATH" ]]; then
  "$SCRIPT_DIR/build.sh"
fi

"$BINARY_PATH" "$CONFIG_PATH"
