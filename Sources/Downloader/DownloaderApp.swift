import AppKit
import SwiftUI
import DownloaderCore

@main
struct DownloaderApp: App {
    @StateObject private var manager = DownloadManager()

    var body: some Scene {
        Window("Downloader", id: "main") {
            ContentView()
                .environmentObject(manager)
        }
        .defaultSize(width: 540, height: 560)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
