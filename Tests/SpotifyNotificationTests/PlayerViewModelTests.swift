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

    @Test
    func advancesDisplayedPositionContinuouslyWhilePlaying() {
        let spotify = SpotifyControllerFake()
        spotify.snapshotValue = playingSnapshot(duration: 245, position: 42)
        let model = PlayerViewModel(
            spotify: spotify,
            notifier: TrackNotifierFake()
        )
        let refreshDate = Date(timeIntervalSince1970: 1_000)
        model.refresh(at: refreshDate)

        let displayedPosition = model.displayedPosition(
            at: refreshDate.addingTimeInterval(2.5)
        )

        #expect(displayedPosition == 44.5)
    }

    @Test
    func keepsDisplayedPositionStillWhilePaused() {
        let spotify = SpotifyControllerFake()
        spotify.snapshotValue = SpotifySnapshot(
            isRunning: true,
            state: .paused,
            track: playingSnapshot(duration: 245, position: 42).track,
            position: 42,
            volume: 50
        )
        let model = PlayerViewModel(
            spotify: spotify,
            notifier: TrackNotifierFake()
        )
        let refreshDate = Date(timeIntervalSince1970: 1_000)
        model.refresh(at: refreshDate)

        let displayedPosition = model.displayedPosition(
            at: refreshDate.addingTimeInterval(2.5)
        )

        #expect(displayedPosition == 42)
    }

    @Test
    func enablesShuffleWhenItIsAvailableAndInactive() {
        let spotify = SpotifyControllerFake()
        spotify.snapshotValue = playingSnapshot(
            duration: 245,
            position: 42,
            isShuffleAvailable: true
        )
        let model = PlayerViewModel(
            spotify: spotify,
            notifier: TrackNotifierFake()
        )
        model.refresh()

        model.toggleShuffle()

        #expect(spotify.lastShuffleState == true)
    }

    @Test
    func disablesRepeatWhenItIsAvailableAndActive() {
        let spotify = SpotifyControllerFake()
        spotify.snapshotValue = playingSnapshot(
            duration: 245,
            position: 42,
            isRepeatAvailable: true,
            isRepeating: true
        )
        let model = PlayerViewModel(
            spotify: spotify,
            notifier: TrackNotifierFake()
        )
        model.refresh()

        model.toggleRepeat()

        #expect(spotify.lastRepeatState == false)
    }

    @Test
    func forwardsManualUpdateCheckToUpdater() {
        let updater = AppUpdaterFake()
        let model = PlayerViewModel(
            spotify: SpotifyControllerFake(),
            notifier: TrackNotifierFake(),
            updateController: updater,
            appVersion: "0.5.0"
        )

        model.checkForUpdates()

        #expect(updater.checkCount == 1)
    }

    @Test
    func changesAutomaticUpdateChecksThroughUpdater() {
        let updater = AppUpdaterFake()
        let model = PlayerViewModel(
            spotify: SpotifyControllerFake(),
            notifier: TrackNotifierFake(),
            updateController: updater
        )

        model.automaticallyChecksForUpdates = true

        #expect(updater.automaticallyChecksForUpdates)
    }

    @Test
    func exposesCurrentTrackForMenuBarWhenEnabled() {
        let spotify = SpotifyControllerFake()
        spotify.snapshotValue = playingSnapshot(duration: 245, position: 42)
        let model = PlayerViewModel(
            spotify: spotify,
            notifier: TrackNotifierFake(),
            showTrackInMenuBar: true
        )

        model.refresh()

        #expect(model.menuBarTitle == "Song")
    }

    @Test
    func hidesCurrentTrackForMenuBarWhenDisabled() {
        let spotify = SpotifyControllerFake()
        spotify.snapshotValue = playingSnapshot(duration: 245, position: 42)
        let model = PlayerViewModel(
            spotify: spotify,
            notifier: TrackNotifierFake(),
            showTrackInMenuBar: false
        )

        model.refresh()

        #expect(model.menuBarTitle == nil)
    }

    private func playingSnapshot(
        duration: TimeInterval,
        position: TimeInterval,
        isShuffleAvailable: Bool = false,
        isShuffling: Bool = false,
        isRepeatAvailable: Bool = false,
        isRepeating: Bool = false
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
            volume: 50,
            isShuffleAvailable: isShuffleAvailable,
            isShuffling: isShuffling,
            isRepeatAvailable: isRepeatAvailable,
            isRepeating: isRepeating
        )
    }
}

@MainActor
private final class SpotifyControllerFake: SpotifyControlling {
    var lastSetVolume: Int?
    var lastSeekPosition: TimeInterval?
    var lastShuffleState: Bool?
    var lastRepeatState: Bool?
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

    func setShuffle(_ enabled: Bool) throws {
        lastShuffleState = enabled
    }

    func setRepeat(_ enabled: Bool) throws {
        lastRepeatState = enabled
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

@MainActor
private final class AppUpdaterFake: AppUpdating {
    var automaticallyChecksForUpdates = false
    var checkCount = 0

    func checkForUpdates() {
        checkCount += 1
    }
}
