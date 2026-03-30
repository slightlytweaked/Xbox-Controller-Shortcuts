#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$APP_ROOT/.." && pwd)"

nohup /bin/zsh "$PROJECT_ROOT/run.sh" "$PROJECT_ROOT/config.json" >> "$PROJECT_ROOT/app-launch.log" 2>&1 &
