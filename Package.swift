// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Downloader",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Downloader", targets: ["Downloader"]),
        .executable(name: "DownloaderSmoke", targets: ["DownloaderSmoke"]),
    ],
    targets: [
        .target(name: "DownloaderCore"),
        .executableTarget(name: "Downloader", dependencies: ["DownloaderCore"]),
        .executableTarget(name: "DownloaderSmoke", dependencies: ["DownloaderCore"]),
        .testTarget(name: "DownloaderCoreTests", dependencies: ["DownloaderCore"]),
    ],
    swiftLanguageVersions: [.v5]
)
