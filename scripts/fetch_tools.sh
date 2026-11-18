#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="$ROOT/tools"
mkdir -p "$TOOLS"

if [ ! -x "$TOOLS/yt-dlp" ]; then
    echo "Downloading yt-dlp..."
    curl -L --fail --progress-bar -o "$TOOLS/yt-dlp.tmp" \
        https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos
    chmod +x "$TOOLS/yt-dlp.tmp"
    mv "$TOOLS/yt-dlp.tmp" "$TOOLS/yt-dlp"
    xattr -dr com.apple.quarantine "$TOOLS/yt-dlp" 2>/dev/null || true
fi

# Universal ffmpeg: lipo arm64 + x64 static builds into one fat binary.
# Rebuild when missing, non-executable, or thin (missing either arch).
NEED_FFMPEG=0
if [ ! -x "$TOOLS/ffmpeg" ]; then
    NEED_FFMPEG=1
else
    ARCHS="$(lipo -archs "$TOOLS/ffmpeg" 2>/dev/null || true)"
    case "$ARCHS" in
        *arm64*x86_64*|*x86_64*arm64*) NEED_FFMPEG=0 ;;
        *) echo "ffmpeg is thin ($ARCHS), rebuilding universal..."; NEED_FFMPEG=1 ;;
    esac
fi

if [ "$NEED_FFMPEG" -eq 1 ]; then
    TMPD="$(mktemp -d)"
    trap 'rm -rf "$TMPD"' EXIT
    echo "Downloading ffmpeg (arm64 + x64)..."
    curl -L --fail --progress-bar -o "$TMPD/ffmpeg-arm64.gz" \
        "https://github.com/eugeneware/ffmpeg-static/releases/download/b6.1.1/ffmpeg-darwin-arm64.gz"
    curl -L --fail --progress-bar -o "$TMPD/ffmpeg-x64.gz" \
        "https://github.com/eugeneware/ffmpeg-static/releases/download/b6.1.1/ffmpeg-darwin-x64.gz"
    gunzip -c "$TMPD/ffmpeg-arm64.gz" > "$TMPD/ffmpeg-arm64"
    gunzip -c "$TMPD/ffmpeg-x64.gz" > "$TMPD/ffmpeg-x64"
    lipo -create "$TMPD/ffmpeg-arm64" "$TMPD/ffmpeg-x64" -output "$TMPD/ffmpeg-universal"
    chmod +x "$TMPD/ffmpeg-universal"
    mv "$TMPD/ffmpeg-universal" "$TOOLS/ffmpeg"
    rm -rf "$TMPD"
    trap - EXIT
    xattr -dr com.apple.quarantine "$TOOLS/ffmpeg" 2>/dev/null || true
    lipo -info "$TOOLS/ffmpeg"
fi

echo "yt-dlp: $("$TOOLS/yt-dlp" --version)"
echo "ffmpeg: $("$TOOLS/ffmpeg" -version | head -1)"
