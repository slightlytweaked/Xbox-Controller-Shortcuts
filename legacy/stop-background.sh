#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
pkill -f "$PROJECT_ROOT/xbox-controller-shortcuts" || true
