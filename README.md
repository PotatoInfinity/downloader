# Downloader

Minimal macOS downloader for YouTube and Facebook links, built with SwiftUI and yt-dlp.

Paste one or more links, choose MP4 or MP3, press Download. Files are saved to `~/Desktop/download_tool`.

## Download

Prebuilt DMG: [Releases](https://github.com/PotatoInfinity/downloader/releases/latest)

## Behavior

- Detects YouTube and Facebook URLs in arbitrary pasted text.
- Removes duplicates and ignores unsupported hosts.
- Downloads sequentially, one link at a time.
- Retries a failed link three times, waiting 5s, 10s, then 15s.
- Uses bundled yt-dlp and a static ffmpeg; no Homebrew install required at runtime.
- MP4 prefers H.264 video plus AAC audio and merges to MP4.
- MP3 extracts the best available audio and converts to 320 kbps MP3.
- No analytics, background services, auto-updates, or network code in the app itself.

## Requirements

- macOS 13 or later
- Xcode or the Swift toolchain

## Build

```sh
./scripts/fetch_tools.sh
./scripts/build_app.sh
open dist/Downloader.app
```

Make a DMG:

```sh
./scripts/build_dmg.sh
```

The result is `dist/Downloader.dmg`.

## Notes

- The app is ad-hoc signed, not notarized. On first launch, right-click the app and choose Open if Gatekeeper blocks it.
- The first download may ask for permission to access the Desktop folder.
- The app bundle is about 80 MB because yt-dlp and ffmpeg are bundled for a self-contained install. The DMG is compressed.

## Third-party

- [yt-dlp](https://github.com/yt-dlp/yt-dlp), Unlicense.
- [FFmpeg](https://ffmpeg.org/), licensed under the LGPL/GPL depending on the build. The bundled build's license is included in the app at `Contents/Resources/Licenses/ffmpeg.txt`.
