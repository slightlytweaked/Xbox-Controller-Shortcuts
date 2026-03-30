#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLIST_SOURCE="$SCRIPT_DIR/com.marc.xbox-controller-shortcuts.plist"
PLIST_TARGET="$HOME/Library/LaunchAgents/com.marc.xbox-controller-shortcuts.plist"

mkdir -p "$HOME/Library/LaunchAgents"
cp "$PLIST_SOURCE" "$PLIST_TARGET"

launchctl unload "$PLIST_TARGET" >/dev/null 2>&1 || true
launchctl load "$PLIST_TARGET"

echo "Installed LaunchAgent:"
echo "  $PLIST_TARGET"
echo
echo "It will start now and again at login."
