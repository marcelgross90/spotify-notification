import Foundation
import Testing
@testable import SpotifyNotification

@MainActor
struct PlayerViewModelTests {
    @Test
    func commitsRoundedVolumeWhenEditingEnds() {
        let spotify = SpotifyControllerFake()
        let model = PlayerViewModel(
            spotify: spotify,
            notifier: TrackNotifierFake()
        )

        model.updateVolume(64.6)
        model.setVolumeEditing(false)

        #expect(spotify.lastSetVolume == 65)
    }

    @Test
    func clampsVolumeToSpotifyRange() {
        let spotify = SpotifyControllerFake()
        let model = PlayerViewModel(
            spotify: spotify,
            notifier: TrackNotifierFake()
        )

        model.updateVolume(120)
        model.setVolumeEditing(false)

        #expect(spotify.lastSetVolume == 100)
    }

    @Test
    func muteRestoresPreviousVolume() {
        let spotify = SpotifyControllerFake()
        let model = PlayerViewModel(
            spotify: spotify,
            notifier: TrackNotifierFake()
        )
        model.updateVolume(68)

        model.toggleMute()
        #expect(spotify.lastSetVolume == 0)

        model.toggleMute()
        #expect(spotify.lastSetVolume == 68)
    }

    @Test
    func unmuteUsesSensibleDefaultWithoutPreviousVolume() {
        let spotify = SpotifyControllerFake()
        let model = PlayerViewModel(
            spotify: spotify,
            notifier: TrackNotifierFake()
        )

        model.toggleMute()

        #expect(spotify.lastSetVolume == 50)
    }

    @Test
    func commitsRoundedSeekPositionWhenEditingEnds() {
        let spotify = SpotifyControllerFake()
        spotify.snapshotValue = playingSnapshot(duration: 245, position: 42)
        let model = PlayerViewModel(
            spotify: spotify,
            notifier: TrackNotifierFake()
        )
        model.refresh()

        model.updatePosition(123.6)
        model.setPositionEditing(false)

        #expect(spotify.lastSeekPosition == 124)
    }

    @Test
    func clampsSeekPositionToTrackDuration() {
        let spotify = SpotifyControllerFake()
        spotify.snapshotValue = playingSnapshot(duration: 245, position: 42)
        let model = PlayerViewModel(
            spotify: spotify,
            notifier: TrackNotifierFake()
        )
        model.refresh()

        model.updatePosition(500)
        model.setPositionEditing(false)

        #expect(spotify.lastSeekPosition == 245)
    }

    private func playingSnapshot(
        duration: TimeInterval,
        position: TimeInterval
    ) -> SpotifySnapshot {
        SpotifySnapshot(
            isRunning: true,
            state: .playing,
            track: SpotifyTrack(
                id: "track",
                name: "Song",
                artist: "Artist",
                album: "Album",
                artworkURL: nil,
                spotifyURL: nil,
                duration: duration
            ),
            position: position,
            volume: 50
        )
    }
}

@MainActor
private final class SpotifyControllerFake: SpotifyControlling {
    var lastSetVolume: Int?
    var lastSeekPosition: TimeInterval?
    var snapshotValue: SpotifySnapshot = .notRunning

    func snapshot() throws -> SpotifySnapshot {
        snapshotValue
    }

    func playPause() throws {}
    func nextTrack() throws {}
    func previousTrack() throws {}

    func setVolume(_ volume: Int) throws {
        lastSetVolume = volume
    }

    func seek(to position: TimeInterval) throws {
        lastSeekPosition = position
    }

    func openSpotify() {}
    func openCurrentTrack(_ track: SpotifyTrack?) {}
}

@MainActor
private final class TrackNotifierFake: TrackNotifying {
    func requestAuthorization() async throws -> Bool {
        true
    }

    func notify(track: SpotifyTrack) async {}
}
