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
    var showTrackInMenuBar: Bool {
        didSet {
            UserDefaults.standard.set(showTrackInMenuBar, forKey: Self.menuBarTrackKey)
        }
    }
    var launchAtLoginEnabled: Bool = LaunchAtLoginService.isEnabled

    private static let notificationsKey = "notificationsEnabled"
    private static let menuBarTrackKey = "showTrackInMenuBar"
    private static let maximumMenuBarTitleLength = 36
    private let spotify: SpotifyControlling
    private let notifier: TrackNotifying
    private let updateController: any AppUpdating
    private var pollingTask: Task<Void, Never>?
    private var trackChangeDetector = TrackChangeDetector()
    private var isAdjustingVolume = false
    private var positionUpdatedAt = Date.now
    private var lastNonZeroVolume: Double = 50

    var isMuted: Bool {
        volume == 0
    }

    var automaticallyChecksForUpdates: Bool {
        get { updateController.automaticallyChecksForUpdates }
        set { updateController.automaticallyChecksForUpdates = newValue }
    }

    var menuBarTitle: String? {
        guard showTrackInMenuBar,
              snapshot.isRunning,
              let title = snapshot.track?.name,
              !title.isEmpty else {
            return nil
        }

        guard title.count > Self.maximumMenuBarTitleLength else {
            return title
        }
        return String(title.prefix(Self.maximumMenuBarTitleLength - 1)) + "…"
    }

    let appVersion: String

    init(
        spotify: SpotifyControlling = SpotifyBridge(),
        notifier: TrackNotifying = TrackNotificationService(),
        updateController: any AppUpdating = SparkleUpdateController(),
        appVersion: String = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "0.0.0",
        showTrackInMenuBar: Bool? = nil
    ) {
        self.spotify = spotify
        self.notifier = notifier
        self.updateController = updateController
        self.appVersion = appVersion
        self.showTrackInMenuBar = showTrackInMenuBar
            ?? UserDefaults.standard.bool(forKey: Self.menuBarTrackKey)
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
        updateController.checkForUpdates()
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
