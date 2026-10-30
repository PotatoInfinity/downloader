import AppKit
import Foundation
import DownloaderCore

struct DownloadItem: Identifiable {
    enum State: Equatable {
        case queued
        case downloading(progress: Double?)
        case processing(String)
        case retrying(attempt: Int, delay: Int)
        case completed(path: String?)
        case failed(String)
        case cancelled
    }

    let id = UUID()
    let url: URL
    var state: State = .queued

    var title: String {
        if case .completed(let path) = state, let path {
            return URL(fileURLWithPath: path).lastPathComponent
        }

        var host = url.host?.lowercased() ?? "link"
        if host.hasPrefix("www.") {
            host.removeFirst(4)
        }
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return path.isEmpty ? host : "\(host)/\(path)"
    }

    var isFinished: Bool {
        switch state {
        case .completed, .failed, .cancelled: return true
        case .queued, .downloading, .processing, .retrying: return false
        }
    }

    var isCompleted: Bool {
        if case .completed = state { return true }
        return false
    }

    var failureMessage: String? {
        if case .failed(let message) = state { return message }
        return nil
    }

    var retryMessage: String? {
        if case .retrying(let attempt, let delay) = state {
            return "Retrying in \(delay)s (\(attempt)/3)."
        }
        return nil
    }

    var progress: Double? {
        if case .downloading(let progress) = state { return progress }
        return nil
    }

    var stateLabel: String {
        switch state {
        case .queued:
            return "Waiting"
        case .downloading(let progress):
            guard let progress else { return "Starting" }
            return "\(Int((progress * 100).rounded()))%"
        case .processing(let label):
            return label
        case .retrying(let attempt, _):
            return "Retry \(attempt)/3"
        case .completed:
            return "Done"
        case .failed:
            return "Failed"
        case .cancelled:
            return "Cancelled"
        }
    }

    var symbolName: String {
        switch state {
        case .queued: return "clock"
        case .downloading: return "arrow.down"
        case .processing: return "gearshape"
        case .retrying: return "arrow.clockwise"
        case .completed: return "checkmark"
        case .failed: return "exclamationmark"
        case .cancelled: return "minus"
        }
    }

    var isFailed: Bool {
        if case .failed = state { return true }
        return false
    }
}

@MainActor
final class DownloadManager: ObservableObject {
    @Published var input = ""
    @Published var format: MediaFormat = .mp4
    @Published private(set) var items: [DownloadItem] = []
    @Published private(set) var isDownloading = false
    @Published private(set) var currentIndex: Int?
    @Published private(set) var startupError: String?

    let outputDirectory: URL
    private let tools: ToolPaths?
    private var currentProcess: Process?
    private var cancelRequested = false
    private var runTask: Task<Void, Never>?

    init() {
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        let override = ProcessInfo.processInfo.environment["FETCH_OUTPUT_DIR"]

        if let override, !override.isEmpty {
            outputDirectory = URL(fileURLWithPath: override, isDirectory: true)
        } else {
            outputDirectory = desktop.appendingPathComponent("download_tool", isDirectory: true)
        }

        tools = ToolPaths.resolve()
        if tools == nil {
            startupError = "yt-dlp or ffmpeg is missing."
        }
    }

    var links: [URL] { LinkDetector.detect(in: input).supported }

    var unsupportedCount: Int { LinkDetector.detect(in: input).unsupportedCount }

    var isReady: Bool { tools != nil }

    var finishedCount: Int { items.filter(\.isFinished).count }

    var successCount: Int { items.filter(\.isCompleted).count }

    var failureCount: Int { items.filter(\.isFailed).count }

    var cancelledCount: Int {
        items.filter {
            if case .cancelled = $0.state { return true }
            return false
        }.count
    }

    var canReveal: Bool { successCount > 0 }

    var outputLabel: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return outputDirectory.path.replacingOccurrences(of: home, with: "~")
    }

    var statusText: String {
        if let startupError {
            return startupError
        }
        if isDownloading {
            return "\(finishedCount) of \(items.count) finished."
        }
        if items.isEmpty {
            return "Save to \(outputLabel)"
        }
        if failureCount > 0 {
            return "\(successCount) saved, \(failureCount) failed."
        }
        if cancelledCount > 0 {
            return successCount > 0
                ? "\(successCount) saved, \(cancelledCount) cancelled."
                : "Cancelled."
        }
        if successCount == items.count {
            return "\(successCount) saved."
        }
        return "\(finishedCount) of \(items.count) finished."
    }

    func start() {
        guard !isDownloading, let tools else { return }
        let urls = links
        guard !urls.isEmpty else { return }

        let selectedFormat = format
        items = urls.map { DownloadItem(url: $0) }
        isDownloading = true
        cancelRequested = false
        startupError = nil

        runTask = Task { [weak self] in
            await self?.run(urls, format: selectedFormat, tools: tools)
        }
    }

    func cancel() {
        guard isDownloading else { return }
        cancelRequested = true
        runTask?.cancel()
        if let process = currentProcess, process.isRunning {
            process.terminate()
        }
    }

    func clearInput() {
        input = ""
    }

    func revealOutputFolder() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: outputDirectory.path) {
            try? fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        }
        NSWorkspace.shared.open(outputDirectory)
    }

    private func run(_ urls: [URL], format: MediaFormat, tools: ToolPaths) async {
        outer: for (index, url) in urls.enumerated() {
            if cancelRequested || Task.isCancelled {
                cancelRemaining(from: index)
                break
            }

            currentIndex = index
            var retry = 0

            while true {
                if cancelRequested || Task.isCancelled {
                    items[index].state = .cancelled
                    cancelRemaining(from: index + 1)
                    break outer
                }

                items[index].state = .downloading(progress: nil)

                let job = DownloadJob(
                    url: url,
                    format: format,
                    outputDirectory: outputDirectory,
                    ytDlpPath: tools.ytDlp,
                    ffmpegPath: tools.ffmpeg
                )

                let result = await DownloadRunner.run(
                    job: job,
                    onEvent: { [weak self] event in
                        self?.apply(event, at: index)
                    },
                    onProcessStart: { [weak self] process in
                        self?.currentProcess = process
                    }
                )

                currentProcess = nil

                if cancelRequested || result.wasCancelled || Task.isCancelled {
                    items[index].state = .cancelled
                    cancelRemaining(from: index + 1)
                    break outer
                }

                if result.succeeded {
                    items[index].state = .completed(path: result.outputPath)
                    break
                }

                guard retry < 3 else {
                    items[index].state = .failed(result.errorMessage ?? "Download failed.")
                    break
                }

                retry += 1
                let delay = retry * 5
                items[index].state = .retrying(attempt: retry, delay: delay)

                do {
                    try await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
                } catch {
                    items[index].state = .cancelled
                    cancelRemaining(from: index + 1)
                    break outer
                }
            }
        }

        currentIndex = nil
        currentProcess = nil
        isDownloading = false
        runTask = nil
    }

    private func apply(_ event: DownloadEvent, at index: Int) {
        guard items.indices.contains(index) else { return }
        switch event {
        case .progress(let fraction):
            items[index].state = .downloading(progress: fraction)
        case .processing(let label):
            items[index].state = .processing(label)
        case .status:
            break
        }
    }

    private func cancelRemaining(from index: Int) {
        guard index < items.count else { return }
        for itemIndex in index..<items.count where !items[itemIndex].isFinished {
            items[itemIndex].state = .cancelled
        }
    }
}
