import Foundation

public struct DownloadJob: Sendable {
    public let url: URL
    public let format: MediaFormat
    public let outputDirectory: URL
    public let ytDlpPath: String
    public let ffmpegPath: String

    public init(
        url: URL,
        format: MediaFormat,
        outputDirectory: URL,
        ytDlpPath: String,
        ffmpegPath: String
    ) {
        self.url = url
        self.format = format
        self.outputDirectory = outputDirectory
        self.ytDlpPath = ytDlpPath
        self.ffmpegPath = ffmpegPath
    }

    public var outputTemplate: String {
        outputDirectory
            .appendingPathComponent("%(title).120B [%(id)s].%(ext)s")
            .path
    }

    public func arguments(printFile: URL) -> [String] {
        var arguments = [
            "--no-playlist",
            "--newline",
            "--no-colors",
            "--no-warnings",
            "--no-mtime",
            "--retries", "3",
            "--fragment-retries", "3",
            "--socket-timeout", "30",
            "--ffmpeg-location", ffmpegPath,
        ]

        switch format {
        case .mp4:
            arguments += [
                "-f", "bv*[vcodec^=avc1]+ba[ext=m4a]/bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]/bv*+ba/b",
                "--merge-output-format", "mp4",
            ]
        case .mp3:
            arguments += [
                "-f", "ba[ext=m4a]/ba/b",
                "-x",
                "--audio-format", "mp3",
                "--audio-quality", "0",
            ]
        }

        arguments += [
            "-o", outputTemplate,
            "--print-to-file", "after_move:filepath", printFile.path,
            url.absoluteString,
        ]

        return arguments
    }
}

public struct DownloadResult: Sendable {
    public let exitCode: Int32
    public let outputPath: String?
    public let errorMessage: String?
    public let wasCancelled: Bool

    public init(exitCode: Int32, outputPath: String?, errorMessage: String?, wasCancelled: Bool) {
        self.exitCode = exitCode
        self.outputPath = outputPath
        self.errorMessage = errorMessage
        self.wasCancelled = wasCancelled
    }

    public var succeeded: Bool { exitCode == 0 && !wasCancelled }
}

public enum DownloadEvent: Sendable {
    case progress(Double)
    case processing(String)
    case status(String)
}
