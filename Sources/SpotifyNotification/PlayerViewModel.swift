import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class PlayerViewModel {
    private(set) var snapshot: SpotifySnapshot = .notRunning
    private(set) var errorMessage: String?
    private(set) var notificationMessage: String?
    private(set) var volume: Double = 0
    private(set) var position: Double = 0
    private(set) var isSeeking = false
    private(set) var isCheckingForUpdates = false
    private(set) var updateMessage: String?
    private(set) var availableUpdateURL: URL?
    var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: Self.notificationsKey)
            if notificationsEnabled {
                requestNotificationAuthorization()
            } else {
                notificationMessage = nil
            }
        }
    }
    var launchAtLoginEnabled: Bool = LaunchAtLoginService.isEnabled

    private static let notificationsKey = "notificationsEnabled"
    private let spotify: SpotifyControlling
    private let notifier: TrackNotifying
    private let updateChecker: any UpdateChecking
    private var pollingTask: Task<Void, Never>?
    private var trackChangeDetector = TrackChangeDetector()
    private var isAdjustingVolume = false
    private var positionUpdatedAt = Date.now
    private var lastNonZeroVolume: Double = 50

    var isMuted: Bool {
        volume == 0
    }

    let appVersion: String

    init(
        spotify: SpotifyControlling = SpotifyBridge(),
        notifier: TrackNotifying = TrackNotificationService(),
        updateChecker: any UpdateChecking = GitHubUpdateService(),
        appVersion: String = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "0.0.0"
    ) {
        self.spotify = spotify
        self.notifier = notifier
        self.updateChecker = updateChecker
        self.appVersion = appVersion
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

        if notificationsEnabled {
            requestNotificationAuthorization()
        }

        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.refresh()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func refresh(at date: Date = .now) {
        do {
            let newSnapshot = try spotify.snapshot()
            errorMessage = nil
            processTrackChange(newSnapshot)
            snapshot = newSnapshot
            if !isAdjustingVolume {
                volume = Double(newSnapshot.volume)
                if volume > 0 {
                    lastNonZeroVolume = volume
                }
            }
            if !isSeeking {
                position = min(
                    max(newSnapshot.position, 0),
                    newSnapshot.track?.duration ?? 0
                )
                positionUpdatedAt = date
            }
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

    func updateVolume(_ newValue: Double) {
        volume = min(max(newValue, 0), 100)
        if volume > 0 {
            lastNonZeroVolume = volume
        }
    }

    func setVolumeEditing(_ editing: Bool) {
        isAdjustingVolume = editing
        guard !editing else { return }

        perform {
            try spotify.setVolume(Int(volume.rounded()))
        }
    }

    func toggleMute() {
        let targetVolume: Double
        if isMuted {
            targetVolume = lastNonZeroVolume
        } else {
            lastNonZeroVolume = volume
            targetVolume = 0
        }

        volume = targetVolume
        perform {
            try spotify.setVolume(Int(targetVolume.rounded()))
        }
    }

    func updatePosition(_ newValue: Double) {
        let duration = snapshot.track?.duration ?? 0
        position = min(max(newValue, 0), duration)
    }

    func displayedPosition(at date: Date) -> Double {
        guard !isSeeking,
              snapshot.state == .playing,
              let duration = snapshot.track?.duration else {
            return position
        }

        let elapsed = max(0, date.timeIntervalSince(positionUpdatedAt))
        return min(position + elapsed, duration)
    }

    func setPositionEditing(_ editing: Bool) {
        isSeeking = editing
        guard !editing else { return }

        let targetPosition = position.rounded()
        perform {
            try spotify.seek(to: targetPosition)
        }
    }

    func toggleShuffle() {
        guard snapshot.isShuffleAvailable else { return }
        perform {
            try spotify.setShuffle(!snapshot.isShuffling)
        }
    }

    func toggleRepeat() {
        guard snapshot.isRepeatAvailable else { return }
        perform {
            try spotify.setRepeat(!snapshot.isRepeating)
        }
    }

    func openSpotify() {
        spotify.openSpotify()
    }

    func openCurrentTrack() {
        spotify.openCurrentTrack(snapshot.track)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLoginService.setEnabled(enabled)
            launchAtLoginEnabled = LaunchAtLoginService.isEnabled
            errorMessage = nil
        } catch {
            launchAtLoginEnabled = LaunchAtLoginService.isEnabled
            errorMessage = L10n.format("error.launch_at_login", error.localizedDescription)
        }
    }

    func checkForUpdates() {
        guard !isCheckingForUpdates else { return }

        isCheckingForUpdates = true
        updateMessage = nil
        availableUpdateURL = nil

        Task {
            do {
                switch try await updateChecker.check(currentVersion: appVersion) {
                case .upToDate:
                    updateMessage = L10n.format("update.status.current", appVersion)
                case let .updateAvailable(version, releaseURL):
                    updateMessage = L10n.format("update.status.available", version)
                    availableUpdateURL = releaseURL
                }
            } catch {
                updateMessage = L10n.format("update.status.failed", error.localizedDescription)
            }
            isCheckingForUpdates = false
        }
    }

    func openAvailableUpdate() {
        guard let availableUpdateURL else { return }
        NSWorkspace.shared.open(availableUpdateURL)
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

    private func requestNotificationAuthorization() {
        Task {
            do {
                let granted = try await notifier.requestAuthorization()
                notificationMessage = granted
                    ? nil
                    : L10n.string("notification.permission.disabled")
            } catch {
                notificationMessage = L10n.format(
                    "notification.permission.failed",
                    error.localizedDescription
                )
            }
        }
    }
}
