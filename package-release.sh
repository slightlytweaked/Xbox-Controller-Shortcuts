#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERSION="${1:-v0.1.0}"
APP_NAME="Xbox Controller Shortcuts.app"
ZIP_NAME="Xbox-Controller-Shortcuts-${VERSION}-macOS.zip"

cd "$SCRIPT_DIR"
zsh "$SCRIPT_DIR/build-app.sh"
rm -f "$ZIP_NAME"
ditto -c -k --sequesterRsrc --keepParent "$APP_NAME" "$ZIP_NAME"

echo "Created release archive:"
echo "  $SCRIPT_DIR/$ZIP_NAME"
