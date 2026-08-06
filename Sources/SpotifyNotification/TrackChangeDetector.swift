import Foundation

struct TrackChangeDetector {
    private var hasEstablishedBaseline = false
    private var lastTrackID: String?

    mutating func trackToNotify(for snapshot: SpotifySnapshot) -> SpotifyTrack? {
        let newTrackID = snapshot.track?.id

        guard hasEstablishedBaseline else {
            hasEstablishedBaseline = true
            lastTrackID = newTrackID
            return nil
        }

        defer { lastTrackID = newTrackID }
        guard snapshot.state == .playing,
              let track = snapshot.track,
              track.id != lastTrackID else {
            return nil
        }

        return track
    }
}
