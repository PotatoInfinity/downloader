import XCTest
@testable import DownloaderCore

final class LinkDetectorTests: XCTestCase {
    private let facebookLinks = [
        "https://www.facebook.com/share/r/1LXBeTH7We/?mibextid=wwXIfr",
        "https://www.facebook.com/share/r/1DhwmzyDto/?mibextid=wwXIfr",
        "https://www.facebook.com/share/v/1E2Usj4Fpk/?mibextid=wwXIfr",
        "https://www.facebook.com/share/r/1LWzv4eQvA/?mibextid=wwXIfr",
        "https://www.facebook.com/share/v/1cUNeFvo22/?mibextid=wwXIfr",
        "https://www.facebook.com/share/r/19dQJsiG11/?mibextid=wwXIfr",
    ]

    func testExtractsAllFacebookLinksFromMessyText() {
        let text = """
        first: \(facebookLinks[0]),
        second \(facebookLinks[1]).
        \(facebookLinks[2])
        and \(facebookLinks[3]); \(facebookLinks[4]) and \(facebookLinks[5]).
        """

        let result = LinkDetector.detect(in: text)
        XCTAssertEqual(result.supported.count, 6)
        XCTAssertEqual(Set(result.supported.map(\.absoluteString)), Set(facebookLinks))
    }

    func testExtractsYouTubeVariants() {
        let text = """
        https://youtu.be/dQw4w9WgXcQ?si=abc
        youtube.com/watch?v=BaW_jenozKc
        https://m.youtube.com/shorts/abcdefghijk
        """

        let result = LinkDetector.detect(in: text)
        XCTAssertEqual(result.supported.count, 3)
        XCTAssertTrue(result.supported.allSatisfy { $0.scheme == "https" })
        XCTAssertEqual(result.supported[0].host, "youtu.be")
        XCTAssertEqual(result.supported[1].host, "youtube.com")
        XCTAssertEqual(result.supported[2].host, "m.youtube.com")
    }

    func testDeduplicatesEquivalentLinks() {
        let text = """
        https://www.youtube.com/watch?v=abc123
        http://www.youtube.com/watch?v=abc123
        https://www.youtube.com/watch?v=abc123
        """

        XCTAssertEqual(LinkDetector.extract(from: text).count, 1)
    }

    func testIgnoresUnsupportedHosts() {
        let text = """
        https://www.tiktok.com/@user/video/123
        https://youtube.com.evil.example/watch?v=abc
        https://notfacebook.com/watch?v=abc
        https://www.facebook.com/watch/?v=123
        """

        let result = LinkDetector.detect(in: text)
        XCTAssertEqual(result.supported.count, 1)
        XCTAssertEqual(result.supported.first?.host, "www.facebook.com")
        XCTAssertEqual(result.unsupportedCount, 3)
    }

    func testEmptyText() {
        let result = LinkDetector.detect(in: "")
        XCTAssertTrue(result.supported.isEmpty)
        XCTAssertEqual(result.unsupportedCount, 0)
    }
}

final class DownloadJobTests: XCTestCase {
    private let url = URL(string: "https://www.facebook.com/share/r/abc")!
    private let directory = URL(fileURLWithPath: "/tmp/downloads", isDirectory: true)
    private let printFile = URL(fileURLWithPath: "/tmp/print.txt")

    func testMP4Arguments() {
        let job = DownloadJob(
            url: url,
            format: .mp4,
            outputDirectory: directory,
            ytDlpPath: "/tmp/yt-dlp",
            ffmpegPath: "/tmp/ffmpeg"
        )
        let arguments = job.arguments(printFile: printFile)

        XCTAssertTrue(arguments.contains("--merge-output-format"))
        XCTAssertTrue(arguments.contains("--no-playlist"))
        XCTAssertTrue(arguments.contains("--ffmpeg-location"))
        XCTAssertTrue(arguments.contains("after_move:filepath"))
        XCTAssertEqual(arguments.last, url.absoluteString)
        XCTAssertTrue(job.outputTemplate.hasSuffix("%(title).120B [%(id)s].%(ext)s"))
    }

    func testMP3Arguments() {
        let job = DownloadJob(
            url: url,
            format: .mp3,
            outputDirectory: directory,
            ytDlpPath: "/tmp/yt-dlp",
            ffmpegPath: "/tmp/ffmpeg"
        )
        let arguments = job.arguments(printFile: printFile)

        XCTAssertTrue(arguments.contains("-x"))
        XCTAssertTrue(arguments.contains("mp3"))
        XCTAssertFalse(arguments.contains("--merge-output-format"))
        XCTAssertEqual(arguments.last, url.absoluteString)
    }
}
