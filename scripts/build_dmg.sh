#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/Downloader.app"
DMG="$ROOT/dist/Downloader.dmg"
STAGING="$ROOT/.build/dmg"

if [ ! -d "$APP" ]; then
    echo "Run scripts/build_app.sh first." >&2
    exit 1
fi

rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/Downloader.app"
ln -s /Applications "$STAGING/Applications"

hdiutil create \
    -volname "Downloader" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG" >/dev/null

MOUNT_POINT="$(mktemp -d)"
hdiutil attach "$DMG" -nobrowse -readonly -mountpoint "$MOUNT_POINT" >/dev/null
trap 'hdiutil detach "$MOUNT_POINT" -quiet || true; rmdir "$MOUNT_POINT" 2>/dev/null || true' EXIT

codesign --verify --deep --strict "$MOUNT_POINT/Downloader.app"
test -L "$MOUNT_POINT/Applications"

echo "Built: $DMG"
du -h "$DMG"
