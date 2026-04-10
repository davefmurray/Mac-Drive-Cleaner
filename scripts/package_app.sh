#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/Mac Drive Cleaner.app"
ZIP_PATH="$ROOT_DIR/dist/Mac Drive Cleaner.zip"

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "App bundle not found at:"
  echo "$APP_BUNDLE"
  echo "Build it first with ./scripts/build_app.sh"
  exit 1
fi

rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"

echo "Created packaged archive:"
echo "$ZIP_PATH"
