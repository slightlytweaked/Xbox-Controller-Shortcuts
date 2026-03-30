#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

exec zsh "$SCRIPT_DIR/run.sh" "$SCRIPT_DIR/config.json"
