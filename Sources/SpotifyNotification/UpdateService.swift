import Foundation

enum UpdateCheckResult: Equatable, Sendable {
    case upToDate
    case updateAvailable(version: String, releaseURL: URL)
}

protocol UpdateChecking: Sendable {
    func check(currentVersion: String) async throws -> UpdateCheckResult
}

struct GitHubUpdateService: UpdateChecking {
    private static let latestReleaseURL = URL(
        string: "https://api.github.com/repos/marcelgross90/spotify-notification/releases/latest"
    )!

    func check(currentVersion: String) async throws -> UpdateCheckResult {
        var request = URLRequest(url: Self.latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("SpotifyNotification", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadRevalidatingCacheData
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw UpdateCheckError.releaseUnavailable
        }

        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        let version = Self.normalizedVersion(release.tagName)
        guard !version.isEmpty,
              let releaseURL = URL(string: release.htmlURL),
              releaseURL.host == "github.com" else {
            throw UpdateCheckError.invalidRelease
        }

        if Self.isVersion(version, newerThan: currentVersion) {
            return .updateAvailable(version: version, releaseURL: releaseURL)
        }
        return .upToDate
    }

    static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let candidateParts = versionParts(candidate)
        let currentParts = versionParts(current)
        guard !candidateParts.isEmpty, !currentParts.isEmpty else { return false }

        let count = max(candidateParts.count, currentParts.count)
        for index in 0..<count {
            let candidatePart = index < candidateParts.count ? candidateParts[index] : 0
            let currentPart = index < currentParts.count ? currentParts[index] : 0
            if candidatePart != currentPart {
                return candidatePart > currentPart
            }
        }
        return false
    }

    private static func normalizedVersion(_ version: String) -> String {
        var normalized = version.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.lowercased().hasPrefix("v") {
            normalized.removeFirst()
        }
        return normalized.split(separator: "-", maxSplits: 1).first.map(String.init) ?? ""
    }

    private static func versionParts(_ version: String) -> [Int] {
        normalizedVersion(version)
            .split(separator: ".")
            .compactMap { Int($0) }
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: String

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }
}

enum UpdateCheckError: LocalizedError {
    case releaseUnavailable
    case invalidRelease

    var errorDescription: String? {
        switch self {
        case .releaseUnavailable:
            L10n.string("update.error.unavailable")
        case .invalidRelease:
            L10n.string("update.error.invalid_release")
        }
    }
}
