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

if [ ! -x "$TOOLS/ffmpeg" ]; then
    case "$(uname -m)" in
        arm64)
            ASSET="ffmpeg-darwin-arm64.gz"
            ;;
        x86_64)
            ASSET="ffmpeg-darwin-x64.gz"
            ;;
        *)
            echo "Unsupported architecture: $(uname -m)" >&2
            exit 1
            ;;
    esac

    echo "Downloading ffmpeg..."
    curl -L --fail --progress-bar -o "$TOOLS/ffmpeg.gz" \
        "https://github.com/eugeneware/ffmpeg-static/releases/download/b6.1.1/$ASSET"
    gunzip -c "$TOOLS/ffmpeg.gz" > "$TOOLS/ffmpeg.tmp"
    rm -f "$TOOLS/ffmpeg.gz"
    chmod +x "$TOOLS/ffmpeg.tmp"
    mv "$TOOLS/ffmpeg.tmp" "$TOOLS/ffmpeg"
    xattr -dr com.apple.quarantine "$TOOLS/ffmpeg" 2>/dev/null || true
fi

echo "yt-dlp: $("$TOOLS/yt-dlp" --version)"
echo "ffmpeg: $("$TOOLS/ffmpeg" -version | head -1)"
