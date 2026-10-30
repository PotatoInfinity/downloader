import Foundation
import DownloaderCore

struct ToolPaths {
    let ytDlp: String
    let ffmpeg: String

    static func resolve() -> ToolPaths? {
        let fileManager = FileManager.default
        var candidates: [(ytDlp: String, ffmpeg: String)] = []

        if let environment = ProcessInfo.processInfo.environment["FETCH_TOOLS_DIR"] {
            candidates.append((
                URL(fileURLWithPath: environment).appendingPathComponent("yt-dlp").path,
                URL(fileURLWithPath: environment).appendingPathComponent("ffmpeg").path
            ))
        }

        if let resources = Bundle.main.resourceURL {
            candidates.append((
                resources.appendingPathComponent("yt-dlp").path,
                resources.appendingPathComponent("ffmpeg").path
            ))
        }

        let executableDirectory = URL(fileURLWithPath: CommandLine.arguments[0])
            .deletingLastPathComponent()
        candidates.append((
            executableDirectory.appendingPathComponent("yt-dlp").path,
            executableDirectory.appendingPathComponent("ffmpeg").path
        ))

        let workingDirectory = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        candidates.append((
            workingDirectory.appendingPathComponent("tools/yt-dlp").path,
            workingDirectory.appendingPathComponent("tools/ffmpeg").path
        ))

        candidates.append((
            "/opt/homebrew/bin/yt-dlp",
            "/opt/homebrew/bin/ffmpeg"
        ))
        candidates.append((
            "/usr/local/bin/yt-dlp",
            "/usr/local/bin/ffmpeg"
        ))

        for candidate in candidates {
            if fileManager.isExecutableFile(atPath: candidate.ytDlp),
               fileManager.isExecutableFile(atPath: candidate.ffmpeg) {
                return ToolPaths(ytDlp: candidate.ytDlp, ffmpeg: candidate.ffmpeg)
            }
        }

        return nil
    }
}
