import Foundation

enum SpotifyPlayerState: String, Equatable, Sendable {
    case playing
    case paused
    case stopped
}

struct SpotifyTrack: Equatable, Sendable {
    let id: String
    let name: String
    let artist: String
    let album: String
    let artworkURL: URL?
    let spotifyURL: URL?
}

struct SpotifySnapshot: Equatable, Sendable {
    let isRunning: Bool
    let state: SpotifyPlayerState
    let track: SpotifyTrack?

    static let notRunning = SpotifySnapshot(
        isRunning: false,
        state: .stopped,
        track: nil
    )
}

enum SpotifyBridgeError: LocalizedError, Equatable {
    case automationDenied
    case malformedResponse
    case script(message: String)

    var errorDescription: String? {
        switch self {
        case .automationDenied:
            "macOS hat den Zugriff auf Spotify nicht erlaubt. Bitte aktiviere ihn unter Datenschutz & Sicherheit > Automation."
        case .malformedResponse:
            "Spotify hat unerwartete Wiedergabedaten geliefert."
        case let .script(message):
            "Spotify konnte nicht abgefragt werden: \(message)"
        }
    }
}
