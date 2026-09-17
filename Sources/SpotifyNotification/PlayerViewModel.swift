import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class PlayerViewModel {
    private(set) var snapshot: SpotifySnapshot = .notRunning
    private(set) var errorMessage: String?
    private(set) var notificationMessage: String?
    private(set) var actionMessage: String?
    private(set) var automationPermissionStatus: PermissionStatus = .unknown
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
    var notificationSoundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationSoundEnabled, forKey: Self.notificationSoundKey)
        }
    }
    var menuBarDisplayMode: MenuBarDisplayMode {
        didSet {
            UserDefaults.standard.set(menuBarDisplayMode.rawValue, forKey: Self.menuBarDisplayModeKey)
        }
    }
    var menuBarMaximumLength: Int {
        didSet {
            UserDefaults.standard.set(menuBarMaximumLength, forKey: Self.menuBarMaximumLengthKey)
        }
    }
    var showTrackInMenuBar: Bool {
        get { menuBarDisplayMode != .iconOnly }
        set { menuBarDisplayMode = newValue ? .title : .iconOnly }
    }
    var launchAtLoginEnabled: Bool = LaunchAtLoginService.isEnabled
    private(set) var sleepTimer: SleepTimerState?

    private static let notificationsKey = "notificationsEnabled"
    private static let notificationSoundKey = "notificationSoundEnabled"
    private static let menuBarTrackKey = "showTrackInMenuBar"
    private static let menuBarDisplayModeKey = "menuBarDisplayMode"
    private static let menuBarMaximumLengthKey = "menuBarMaximumLength"
    static let minimumMenuBarTitleLength = 20
    static let maximumMenuBarTitleLength = 80
    static let defaultMenuBarTitleLength = 36
    private let spotify: SpotifyControlling
    private let notifier: TrackNotifying
    private let updateController: any AppUpdating
    private var pollingTask: Task<Void, Never>?
    private var actionMessageTask: Task<Void, Never>?
    private var trackChangeDetector = TrackChangeDetector()
    private var isAdjustingVolume = false
    private var positionUpdatedAt = Date.now
    private var lastNonZeroVolume: Double = 50

    var isMuted: Bool {
        volume == 0
    }

    var automaticallyChecksForUpdates: Bool {
        didSet {
            updateController.automaticallyChecksForUpdates = automaticallyChecksForUpdates
            if !automaticallyChecksForUpdates && automaticallyDownloadsUpdates {
                automaticallyDownloadsUpdates = false
            }
        }
    }

    var automaticallyDownloadsUpdates: Bool {
        didSet {
            if automaticallyDownloadsUpdates && !automaticallyChecksForUpdates {
                automaticallyChecksForUpdates = true
            }
            updateController.automaticallyDownloadsUpdates = automaticallyDownloadsUpdates
        }
    }

    var menuBarTitle: String? {
        guard snapshot.isRunning,
              let track = snapshot.track,
              let title = menuBarDisplayMode.text(for: track),
              !title.isEmpty else {
            return nil
        }

        guard title.count > menuBarMaximumLength else {
            return title
        }
        return String(title.prefix(menuBarMaximumLength - 1)) + "…"
    }

    let appVersion: String
    let appBuild: String

    init(
        spotify: SpotifyControlling = SpotifyBridge(),
        notifier: TrackNotifying = TrackNotificationService(),
        updateController: any AppUpdating = SparkleUpdateController(),
        appVersion: String = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "0.0.0",
        appBuild: String = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? "0",
        showTrackInMenuBar: Bool? = nil,
        menuBarDisplayMode: MenuBarDisplayMode? = nil,
        menuBarMaximumLength: Int? = nil,
        notificationSoundEnabled: Bool? = nil
    ) {
        self.spotify = spotify
        self.notifier = notifier
        self.updateController = updateController
        self.automaticallyChecksForUpdates = updateController.automaticallyChecksForUpdates
        self.automaticallyDownloadsUpdates = updateController.automaticallyChecksForUpdates
            && updateController.automaticallyDownloadsUpdates
        self.appVersion = appVersion
        self.appBuild = appBuild
        let storedDisplayMode = UserDefaults.standard.string(
            forKey: Self.menuBarDisplayModeKey
        ).flatMap(MenuBarDisplayMode.init(rawValue:))
        if let menuBarDisplayMode {
            self.menuBarDisplayMode = menuBarDisplayMode
        } else if let showTrackInMenuBar {
            self.menuBarDisplayMode = showTrackInMenuBar ? .title : .iconOnly
        } else if let storedDisplayMode {
            self.menuBarDisplayMode = storedDisplayMode
        } else {
            self.menuBarDisplayMode = UserDefaults.standard.bool(forKey: Self.menuBarTrackKey)
                ? .title
                : .iconOnly
        }
        let storedMaximumLength = menuBarMaximumLength
            ?? UserDefaults.standard.integer(forKey: Self.menuBarMaximumLengthKey)
        self.menuBarMaximumLength = min(
            max(
                storedMaximumLength == 0 ? Self.defaultMenuBarTitleLength : storedMaximumLength,
                Self.minimumMenuBarTitleLength
            ),
            Self.maximumMenuBarTitleLength
        )
        if UserDefaults.standard.object(forKey: Self.notificationsKey) == nil {
            notificationsEnabled = true
        } else {
            notificationsEnabled = UserDefaults.standard.bool(
                forKey: Self.notificationsKey
            )
        }
        if let notificationSoundEnabled {
            self.notificationSoundEnabled = notificationSoundEnabled
        } else if UserDefaults.standard.object(forKey: Self.notificationSoundKey) == nil {
            self.notificationSoundEnabled = true
        } else {
            self.notificationSoundEnabled = UserDefaults.standard.bool(
                forKey: Self.notificationSoundKey
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
            var newSnapshot = try spotify.snapshot()
            errorMessage = nil
            if newSnapshot.isRunning {
                automationPermissionStatus = .allowed
            }
            processTrackChange(newSnapshot)
            if try processSleepTimer(for: newSnapshot, at: date) {
                newSnapshot = try spotify.snapshot()
            }
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
            if error as? SpotifyBridgeError == .automationDenied {
                automationPermissionStatus = .denied
            }
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

    func copyTrackDetails() {
        guard let track = snapshot.track else { return }
        copyToPasteboard("\(track.name) — \(track.artist)")
    }

    func copySpotifyLink() {
        guard let link = snapshot.track?.spotifyURL?.absoluteString else { return }
        copyToPasteboard(link)
    }

    func startSleepTimer(minutes: Int, now: Date = .now) {
        guard minutes > 0 else { return }
        sleepTimer = .deadline(now.addingTimeInterval(TimeInterval(minutes * 60)))
    }

    func startSleepTimerAfterCurrentTrack() {
        guard let trackID = snapshot.track?.id else { return }
        sleepTimer = .endOfTrack(trackID: trackID)
    }

    func cancelSleepTimer() {
        sleepTimer = nil
    }

    func sleepTimerRemainingMinutes(at date: Date = .now) -> Int? {
        guard case let .deadline(deadline) = sleepTimer else { return nil }
        return max(1, Int(ceil(deadline.timeIntervalSince(date) / 60)))
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

        let playsSound = notificationSoundEnabled
        Task { await notifier.notify(track: track, playsSound: playsSound) }
    }

    private func processSleepTimer(
        for newSnapshot: SpotifySnapshot,
        at date: Date
    ) throws -> Bool {
        guard let sleepTimer else { return false }

        let shouldStop: Bool
        switch sleepTimer {
        case let .deadline(deadline):
            shouldStop = date >= deadline
        case let .endOfTrack(trackID):
            shouldStop = newSnapshot.track?.id != trackID
        }

        guard shouldStop else { return false }
        self.sleepTimer = nil

        guard newSnapshot.state == .playing else { return false }
        try spotify.playPause()
        return true
    }

    private func copyToPasteboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        showActionMessage(L10n.string("action.copied"))
    }

    private func showActionMessage(_ message: String) {
        actionMessageTask?.cancel()
        actionMessage = message
        actionMessageTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.actionMessage = nil
        }
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
