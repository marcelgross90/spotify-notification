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
    let duration: TimeInterval

    init(
        id: String,
        name: String,
        artist: String,
        album: String,
        artworkURL: URL?,
        spotifyURL: URL?,
        duration: TimeInterval = 0
    ) {
        self.id = id
        self.name = name
        self.artist = artist
        self.album = album
        self.artworkURL = artworkURL
        self.spotifyURL = spotifyURL
        self.duration = duration
    }
}

struct SpotifySnapshot: Equatable, Sendable {
    let isRunning: Bool
    let state: SpotifyPlayerState
    let track: SpotifyTrack?
    let position: TimeInterval
    let volume: Int

    init(
        isRunning: Bool,
        state: SpotifyPlayerState,
        track: SpotifyTrack?,
        position: TimeInterval = 0,
        volume: Int = 0
    ) {
        self.isRunning = isRunning
        self.state = state
        self.track = track
        self.position = position
        self.volume = volume
    }

    static let notRunning = SpotifySnapshot(
        isRunning: false,
        state: .stopped,
        track: nil,
        position: 0,
        volume: 0
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
