import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class PlayerViewModel {
    private(set) var snapshot: SpotifySnapshot = .notRunning
    private(set) var errorMessage: String?
    var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: Self.notificationsKey)
        }
    }
    var launchAtLoginEnabled: Bool = LaunchAtLoginService.isEnabled

    private static let notificationsKey = "notificationsEnabled"
    private let spotify: SpotifyControlling
    private let notifier: TrackNotifying
    private var pollingTask: Task<Void, Never>?
    private var trackChangeDetector = TrackChangeDetector()

    init(
        spotify: SpotifyControlling = SpotifyBridge(),
        notifier: TrackNotifying = NowPlayingOverlayController()
    ) {
        self.spotify = spotify
        self.notifier = notifier
        if UserDefaults.standard.object(forKey: Self.notificationsKey) == nil {
            notificationsEnabled = true
        } else {
            notificationsEnabled = UserDefaults.standard.bool(
                forKey: Self.notificationsKey
            )
        }
    }

    func start() {
        guard pollingTask == nil else { return }

        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.refresh()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func refresh() {
        do {
            let newSnapshot = try spotify.snapshot()
            errorMessage = nil
            processTrackChange(newSnapshot)
            snapshot = newSnapshot
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func playPause() {
        perform(spotify.playPause)
    }

    func nextTrack() {
        perform(spotify.nextTrack)
    }

    func previousTrack() {
        perform(spotify.previousTrack)
    }

    func openSpotify() {
        spotify.openSpotify()
    }

    func openCurrentTrack() {
        spotify.openCurrentTrack(snapshot.track)
    }

    func previewOverlay() {
        let track = snapshot.track ?? SpotifyTrack(
            id: "overlay-preview",
            name: "Titel der Wiedergabe",
            artist: "Künstler",
            album: "Album",
            artworkURL: nil,
            spotifyURL: nil
        )
        Task { await notifier.notify(track: track) }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLoginService.setEnabled(enabled)
            launchAtLoginEnabled = LaunchAtLoginService.isEnabled
            errorMessage = nil
        } catch {
            launchAtLoginEnabled = LaunchAtLoginService.isEnabled
            errorMessage = "Autostart konnte nicht geändert werden: \(error.localizedDescription)"
        }
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
            errorMessage = nil
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func processTrackChange(_ newSnapshot: SpotifySnapshot) {
        let notificationTrack = trackChangeDetector.trackToNotify(for: newSnapshot)
        guard notificationsEnabled, let track = notificationTrack else {
            return
        }

        Task { await notifier.notify(track: track) }
    }
}
