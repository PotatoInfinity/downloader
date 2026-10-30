#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Downloader"
VERSION="1.0"
BUILD_DIR="$ROOT/.build"
DIST_DIR="$ROOT/dist"
APP="$DIST_DIR/$APP_NAME.app"
CONTENTS="$APP/Contents"
RESOURCES="$CONTENTS/Resources"

cd "$ROOT"

"$ROOT/scripts/fetch_tools.sh"

echo "Building release binary..."
swift build -c release --product Downloader

echo "Generating app icon..."
swift scripts/make_icon.swift >/dev/null

echo "Assembling app bundle..."
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$RESOURCES"

cp "$BUILD_DIR/release/Downloader" "$CONTENTS/MacOS/$APP_NAME"
cp "$BUILD_DIR/AppIcon.icns" "$RESOURCES/AppIcon.icns"
cp "$ROOT/tools/yt-dlp" "$RESOURCES/yt-dlp"
cp "$ROOT/tools/ffmpeg" "$RESOURCES/ffmpeg"
chmod +x "$CONTENTS/MacOS/$APP_NAME" "$RESOURCES/yt-dlp" "$RESOURCES/ffmpeg"

mkdir -p "$RESOURCES/Licenses"
cp "$ROOT/licenses/yt-dlp.txt" "$RESOURCES/Licenses/yt-dlp.txt"
cp "$ROOT/licenses/ffmpeg.txt" "$RESOURCES/Licenses/ffmpeg.txt"

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>local.downloader.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSDesktopFolderUsageDescription</key>
    <string>Downloads are saved to Desktop/download_tool.</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright 2026</string>
</dict>
</plist>
PLIST

printf 'APPL????' > "$CONTENTS/PkgInfo"

echo "Signing..."
xattr -cr "$APP" || true
codesign --force --sign - --timestamp=none "$RESOURCES/yt-dlp"
codesign --force --sign - --timestamp=none "$RESOURCES/ffmpeg"
codesign --force --sign - --timestamp=none "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "Built: $APP"
du -sh "$APP"
