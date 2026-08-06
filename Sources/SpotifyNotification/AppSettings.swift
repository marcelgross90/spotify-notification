import Foundation

enum MenuBarDisplayMode: String, CaseIterable, Identifiable, Sendable {
    case iconOnly
    case title
    case artistAndTitle
    case titleAndArtist

    var id: String { rawValue }

    func text(for track: SpotifyTrack) -> String? {
        switch self {
        case .iconOnly:
            nil
        case .title:
            track.name
        case .artistAndTitle:
            "\(track.artist) — \(track.name)"
        case .titleAndArtist:
            "\(track.name) — \(track.artist)"
        }
    }
}

enum SleepTimerState: Equatable, Sendable {
    case deadline(Date)
    case endOfTrack(trackID: String)
}
