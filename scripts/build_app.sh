#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Downloader"
VERSION="1.1"
BUILD_DIR="$ROOT/.build"
DIST_DIR="$ROOT/dist"
APP="$DIST_DIR/$APP_NAME.app"
CONTENTS="$APP/Contents"
RESOURCES="$CONTENTS/Resources"

# Release signing: Developer ID + hardened runtime (notarize.md §3).
# Override with CODESIGN_IDENTITY="..." for local dev builds.
DEVID="${CODESIGN_IDENTITY:-Developer ID Application: Tien Nhut Truong (T4UWU7H9M9)}"
TS_FLAG="--timestamp"
case "$DEVID" in
    "Developer ID Application:"*) TS_FLAG="--timestamp" ;;
    *) TS_FLAG="--timestamp=none" ;;
esac

cd "$ROOT"

"$ROOT/scripts/fetch_tools.sh"

echo "Building release binary (universal arm64+x86_64)..."
swift build -c release --arch arm64 --arch x86_64 --product Downloader

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
    <string>2</string>
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

echo "Signing (nested-first, outer-last, no --deep)..."
xattr -cr "$APP" || true
codesign --force --options runtime "$TS_FLAG" --sign "$DEVID" --identifier local.downloader.app.yt-dlp "$RESOURCES/yt-dlp"
codesign --force --options runtime "$TS_FLAG" --sign "$DEVID" --identifier local.downloader.app.ffmpeg "$RESOURCES/ffmpeg"
codesign --force --options runtime "$TS_FLAG" --sign "$DEVID" --identifier local.downloader.app "$CONTENTS/MacOS/$APP_NAME"
codesign --force --options runtime "$TS_FLAG" --sign "$DEVID" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
# Fail closed for release: must be Developer ID / Team T4UWU7H9M9.
if [[ "$DEVID" == "Developer ID Application:"* ]]; then
    TEAM="$(codesign -dv --verbose=4 "$APP" 2>&1 | sed -n 's/^TeamIdentifier=//p')"
    if [[ "$TEAM" != "T4UWU7H9M9" ]]; then
        echo "ERROR: sealed TeamIdentifier '$TEAM' != T4UWU7H9M9." >&2
        exit 1
    fi
    echo "Universal arch gate..."
    lipo -verify_arch arm64 "$CONTENTS/MacOS/$APP_NAME"
    lipo -verify_arch x86_64 "$CONTENTS/MacOS/$APP_NAME"
    lipo -verify_arch arm64 "$RESOURCES/ffmpeg"
    lipo -verify_arch x86_64 "$RESOURCES/ffmpeg"
    lipo -verify_arch arm64 "$RESOURCES/yt-dlp"
    lipo -verify_arch x86_64 "$RESOURCES/yt-dlp"
    lipo -info "$CONTENTS/MacOS/$APP_NAME" "$RESOURCES/ffmpeg" "$RESOURCES/yt-dlp"
fi

echo "Built: $APP"
du -sh "$APP"
