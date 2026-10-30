import Foundation

public enum MediaFormat: String, CaseIterable, Identifiable, Sendable {
    case mp4 = "MP4"
    case mp3 = "MP3"

    public var id: String { rawValue }
}

public struct LinkDetection: Equatable, Sendable {
    public let supported: [URL]
    public let unsupportedCount: Int

    public init(supported: [URL], unsupportedCount: Int) {
        self.supported = supported
        self.unsupportedCount = unsupportedCount
    }
}

public enum LinkDetector {
    private static let detector = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.link.rawValue
    )

    private static let supportedHosts: Set<String> = [
        "youtube.com",
        "youtu.be",
        "youtube-nocookie.com",
        "facebook.com",
        "fb.watch",
        "fb.com",
    ]

    public static func detect(in text: String) -> LinkDetection {
        guard !text.isEmpty, let detector else {
            return LinkDetection(supported: [], unsupportedCount: 0)
        }

        var supported: [URL] = []
        var unsupported = Set<String>()
        var seen = Set<String>()
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)

        detector.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            guard let rawURL = match?.url,
                  let url = normalize(rawURL) else { return }

            guard isSupported(url) else {
                if let key = canonicalKey(url) {
                    unsupported.insert(key)
                }
                return
            }

            guard let key = canonicalKey(url), seen.insert(key).inserted else { return }
            supported.append(url)
        }

        return LinkDetection(supported: supported, unsupportedCount: unsupported.count)
    }

    public static func extract(from text: String) -> [URL] {
        detect(in: text).supported
    }

    public static func isSupported(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return supportedHosts.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    private static func normalize(_ url: URL) -> URL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.host != nil else { return nil }

        // Data detectors sometimes return scheme-less links as http. Both supported
        // sites are HTTPS-only.
        components.scheme = "https"
        components.host = components.host?.lowercased()

        // A trailing period, comma, or bracket is punctuation around the link,
        // not part of it. Trim it from the path/query.
        if let path = components.percentEncodedPath as String? {
            components.percentEncodedPath = trimTrailingPunctuation(path)
        }
        if let query = components.percentEncodedQuery {
            components.percentEncodedQuery = trimTrailingPunctuation(query)
        }

        return components.url
    }

    private static func trimTrailingPunctuation(_ value: String) -> String {
        let punctuation = CharacterSet(charactersIn: ".,;:!?)]}\"'")
        var result = value
        while let scalar = result.unicodeScalars.last, punctuation.contains(scalar) {
            result.removeLast()
        }
        return result
    }

    private static func canonicalKey(_ url: URL) -> String? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.scheme = components.scheme?.lowercased()
        components.host = components.host?.lowercased()
        return components.url?.absoluteString
    }
}
