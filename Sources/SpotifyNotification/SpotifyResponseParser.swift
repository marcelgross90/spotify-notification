import Foundation

enum SpotifyResponseParser {
    static let separator = "\u{001F}"

    static func parse(_ response: String) throws -> SpotifySnapshot {
        switch response {
        case "not_running":
            return .notRunning
        case "stopped":
            return SpotifySnapshot(isRunning: true, state: .stopped, track: nil)
        default:
            break
        }

        let fields = response.components(separatedBy: separator)
        guard fields.count == 11,
              fields[0] == "track",
              let state = SpotifyPlayerState(rawValue: fields[1]),
              let durationInMilliseconds = number(from: fields[8]),
              let position = number(from: fields[9]),
              let volume = Int(fields[10]) else {
            throw SpotifyBridgeError.malformedResponse
        }

        let track = SpotifyTrack(
            id: fields[2],
            name: fields[3],
            artist: fields[4],
            album: fields[5],
            artworkURL: URL(string: fields[6]),
            spotifyURL: URL(string: fields[7]),
            duration: durationInMilliseconds / 1_000
        )

        return SpotifySnapshot(
            isRunning: true,
            state: state,
            track: track,
            position: position,
            volume: min(max(volume, 0), 100)
        )
    }

    private static func number(from value: String) -> Double? {
        Double(value.replacingOccurrences(of: ",", with: "."))
    }
}
