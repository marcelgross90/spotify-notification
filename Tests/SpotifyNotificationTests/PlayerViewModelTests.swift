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
}

@MainActor
private final class SpotifyControllerFake: SpotifyControlling {
    var lastSetVolume: Int?

    func snapshot() throws -> SpotifySnapshot {
        .notRunning
    }

    func playPause() throws {}
    func nextTrack() throws {}
    func previousTrack() throws {}

    func setVolume(_ volume: Int) throws {
        lastSetVolume = volume
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
