import Foundation

@MainActor
public enum DownloadRunner {
    public static func run(
        job: DownloadJob,
        onEvent: @escaping (DownloadEvent) -> Void = { _ in },
        onProcessStart: @escaping (Process) -> Void = { _ in }
    ) async -> DownloadResult {
        let fileManager = FileManager.default
        let printFile = fileManager.temporaryDirectory
            .appendingPathComponent("downloader-filepath-\(UUID().uuidString).txt")

        defer { try? fileManager.removeItem(at: printFile) }

        do {
            try fileManager.createDirectory(
                at: job.outputDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            return DownloadResult(
                exitCode: -1,
                outputPath: nil,
                errorMessage: "Could not create the download folder.",
                wasCancelled: false
            )
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: job.ytDlpPath)
        process.arguments = job.arguments(printFile: printFile)
        process.currentDirectoryURL = job.outputDirectory
        process.standardInput = FileHandle.nullDevice

        var environment = ProcessInfo.processInfo.environment
        environment["LANG"] = "en_US.UTF-8"
        environment["LC_ALL"] = "en_US.UTF-8"
        environment["PATH"] = "\(URL(fileURLWithPath: job.ytDlpPath).deletingLastPathComponent().path):/usr/bin:/bin:/usr/sbin:/sbin"
        process.environment = environment

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            return DownloadResult(
                exitCode: -1,
                outputPath: nil,
                errorMessage: "Could not start yt-dlp.",
                wasCancelled: false
            )
        }

        onProcessStart(process)

        var lastError: String?
        var lastLine = ""

        do {
            for try await line in pipe.fileHandleForReading.bytes.lines {
                let cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleaned.isEmpty else { continue }
                lastLine = cleaned

                if let error = errorMessage(from: cleaned) {
                    lastError = error
                }

                if let percent = progress(from: cleaned) {
                    onEvent(.progress(percent))
                }

                if cleaned.contains("[Merger]") {
                    onEvent(.processing("Merging"))
                } else if cleaned.contains("[ExtractAudio]") {
                    onEvent(.processing("Converting to MP3"))
                } else if cleaned.contains("[VideoConvertor]") || cleaned.contains("[VideoRemuxer]") {
                    onEvent(.processing("Converting"))
                } else if cleaned.contains("[FixupM4a]") {
                    onEvent(.processing("Finalizing"))
                }
            }
        } catch {
            // If the pipe is interrupted (for example, after cancel), the
            // process exit status below is still authoritative.
        }

        process.waitUntilExit()

        let outputPath = finalPath(from: printFile)
        let cancelled = process.terminationReason == .uncaughtSignal
            && (process.terminationStatus == 15 || process.terminationStatus == 9)

        if process.terminationStatus == 0 && !cancelled {
            return DownloadResult(
                exitCode: 0,
                outputPath: outputPath,
                errorMessage: nil,
                wasCancelled: false
            )
        }

        let message = cancelled
            ? "Cancelled."
            : (lastError ?? (lastLine.isEmpty ? "Download failed." : lastLine))

        return DownloadResult(
            exitCode: process.terminationStatus,
            outputPath: outputPath,
            errorMessage: message,
            wasCancelled: cancelled
        )
    }

    private static func finalPath(from file: URL) -> String? {
        guard let contents = try? String(contentsOf: file, encoding: .utf8) else { return nil }
        return contents
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .last(where: { !$0.isEmpty })
    }

    private static func errorMessage(from line: String) -> String? {
        guard line.contains("ERROR:") else { return nil }
        guard let range = line.range(of: "ERROR:") else { return nil }
        let message = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
        return message.isEmpty ? nil : message
    }

    private static func progress(from line: String) -> Double? {
        guard line.contains("[download]"),
              let range = line.range(
                of: #"[0-9]+(?:\.[0-9]+)?%"#,
                options: .regularExpression
              ) else { return nil }

        let token = line[range].dropLast()
        guard let value = Double(token) else { return nil }
        return min(max(value / 100, 0), 1)
    }
}
