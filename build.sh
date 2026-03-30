#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

clang -fobjc-arc \
  -framework Foundation \
  -framework AppKit \
  -framework GameController \
  "$SCRIPT_DIR/main.m" \
  -o "$SCRIPT_DIR/xbox-controller-shortcuts"
