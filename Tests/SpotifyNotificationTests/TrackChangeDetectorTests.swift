import Foundation
import Testing
@testable import SpotifyNotification

struct TrackChangeDetectorTests {
    @Test
    func doesNotNotifyForInitialTrack() {
        var detector = TrackChangeDetector()

        #expect(detector.trackToNotify(for: snapshot(id: "one")) == nil)
    }

    @Test
    func notifiesWhenPlayingTrackChanges() {
        var detector = TrackChangeDetector()
        _ = detector.trackToNotify(for: snapshot(id: "one"))

        let notificationTrack = detector.trackToNotify(for: snapshot(id: "two"))

        #expect(notificationTrack?.id == "two")
    }

    @Test
    func doesNotNotifyForPauseOrRepeatedPolling() {
        var detector = TrackChangeDetector()
        _ = detector.trackToNotify(for: snapshot(id: "one"))

        #expect(detector.trackToNotify(for: snapshot(id: "one")) == nil)
        #expect(detector.trackToNotify(for: snapshot(id: "one", state: .paused)) == nil)
    }

    @Test
    func notifiesWhenPlaybackStartsAfterStoppedState() {
        var detector = TrackChangeDetector()
        _ = detector.trackToNotify(for: snapshot(id: "one"))
        _ = detector.trackToNotify(
            for: SpotifySnapshot(isRunning: true, state: .stopped, track: nil)
        )

        #expect(detector.trackToNotify(for: snapshot(id: "one"))?.id == "one")
    }

    private func snapshot(
        id: String,
        state: SpotifyPlayerState = .playing
    ) -> SpotifySnapshot {
        SpotifySnapshot(
            isRunning: true,
            state: state,
            track: SpotifyTrack(
                id: id,
                name: "Song \(id)",
                artist: "Artist",
                album: "Album",
                artworkURL: nil,
                spotifyURL: URL(string: "spotify:track:\(id)")
            )
        )
    }
}
