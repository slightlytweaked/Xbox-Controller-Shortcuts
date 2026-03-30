#!/bin/zsh
set -euo pipefail

PLIST_TARGET="$HOME/Library/LaunchAgents/com.marc.xbox-controller-shortcuts.plist"

launchctl unload "$PLIST_TARGET" >/dev/null 2>&1 || true
rm -f "$PLIST_TARGET"

echo "Removed LaunchAgent:"
echo "  $PLIST_TARGET"
