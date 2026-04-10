#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/native"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="Mac Drive Cleaner"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
MACOS_DIR="$APP_BUNDLE/Contents/MacOS"
RESOURCES_DIR="$APP_BUNDLE/Contents/Resources"

mkdir -p "$BUILD_DIR" "$DIST_DIR" "$MACOS_DIR" "$RESOURCES_DIR"
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

clang \
  -fobjc-arc \
  -framework Cocoa \
  "$ROOT_DIR/App/MacDriveCleaner.m" \
  -o "$MACOS_DIR/MacDriveCleaner"

cp "$ROOT_DIR/App/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

echo "Built app bundle:"
echo "$APP_BUNDLE"
