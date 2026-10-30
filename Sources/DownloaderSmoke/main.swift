import Foundation
import DownloaderCore

struct SmokeFailure: Error, CustomStringConvertible {
    let description: String
}

@main
struct DownloaderSmoke {
    @MainActor
    static func main() async {
        var ytDlp = "tools/yt-dlp"
        var ffmpeg = "tools/ffmpeg"
        var output = "/tmp/downloader-smoke"
        var format = MediaFormat.mp4
        var urls: [URL] = []
        var arguments = Array(CommandLine.arguments.dropFirst())

        func takeValue(_ name: String) -> String? {
            guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else {
                return nil
            }
            let value = arguments[index + 1]
            arguments.removeSubrange(index...(index + 1))
            return value
        }

        if let value = takeValue("--ytdlp") { ytDlp = value }
        if let value = takeValue("--ffmpeg") { ffmpeg = value }
        if let value = takeValue("--output") { output = value }
        if let value = takeValue("--format") {
            guard let parsed = MediaFormat(rawValue: value.uppercased()) else {
                print("invalid format: \(value)")
                exit(2)
            }
            format = parsed
        }

        for argument in arguments {
            if let url = URL(string: argument) {
                urls.append(url)
            }
        }

        guard !urls.isEmpty else {
            print("usage: DownloaderSmoke [--format mp3|mp4] [--output DIR] [--ytdlp PATH] [--ffmpeg PATH] URL...")
            exit(2)
        }

        let outputDirectory = URL(fileURLWithPath: output, isDirectory: true)
        var failures = 0

        for url in urls {
            print("link: \(url.absoluteString)")
            let job = DownloadJob(
                url: url,
                format: format,
                outputDirectory: outputDirectory,
                ytDlpPath: ytDlp,
                ffmpegPath: ffmpeg
            )

            let result = await DownloadRunner.run(job: job) { event in
                switch event {
                case .progress(let fraction):
                    print(String(format: "progress: %.1f%%", fraction * 100))
                case .processing(let message):
                    print("processing: \(message)")
                case .status(let message):
                    print("status: \(message)")
                }
            }

            if result.succeeded {
                print("done: \(result.outputPath ?? "downloaded")")
            } else {
                failures += 1
                print("failed: \(result.errorMessage ?? "unknown error")")
            }
        }

        exit(failures == 0 ? 0 : 1)
    }
}
