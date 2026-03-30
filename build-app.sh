#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
START_APP="$SCRIPT_DIR/Xbox Controller Shortcuts.app"
EXECUTABLE_PATH="$START_APP/Contents/MacOS/XboxControllerShortcutsApp"

rm -rf "$START_APP" "$SCRIPT_DIR/Stop Xbox Controller Shortcuts.app"

mkdir -p "$START_APP/Contents/MacOS"
cp "$SCRIPT_DIR/app-template-start-Info.plist" "$START_APP/Contents/Info.plist"
clang -fobjc-arc \
  -framework Foundation \
  -framework AppKit \
  -framework GameController \
  -framework ApplicationServices \
  "$SCRIPT_DIR/MenuBarApp.m" \
  -o "$EXECUTABLE_PATH"

echo "Built:"
echo "  $START_APP"
echo "Executable:"
echo "  $EXECUTABLE_PATH"
