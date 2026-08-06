import AppKit
import Foundation

@MainActor
protocol SpotifyControlling {
    func snapshot() throws -> SpotifySnapshot
    func playPause() throws
    func nextTrack() throws
    func previousTrack() throws
    func setVolume(_ volume: Int) throws
    func seek(to position: TimeInterval) throws
    func setShuffle(_ enabled: Bool) throws
    func setRepeat(_ enabled: Bool) throws
    func openSpotify()
    func openCurrentTrack(_ track: SpotifyTrack?)
}

@MainActor
final class SpotifyBridge: SpotifyControlling {
    private let bundleIdentifier = "com.spotify.client"
    private lazy var snapshotScript = NSAppleScript(source: Self.snapshotSource)
    private lazy var playPauseScript = NSAppleScript(
        source: "tell application id \"com.spotify.client\" to playpause"
    )
    private lazy var nextTrackScript = NSAppleScript(
        source: "tell application id \"com.spotify.client\" to next track"
    )
    private lazy var previousTrackScript = NSAppleScript(
        source: "tell application id \"com.spotify.client\" to previous track"
    )
    private var volumeScripts: [Int: NSAppleScript] = [:]
    private var seekScripts: [Int: NSAppleScript] = [:]
    private lazy var shuffleOnScript = NSAppleScript(
        source: "tell application id \"com.spotify.client\" to set shuffling to true"
    )
    private lazy var shuffleOffScript = NSAppleScript(
        source: "tell application id \"com.spotify.client\" to set shuffling to false"
    )
    private lazy var repeatOnScript = NSAppleScript(
        source: "tell application id \"com.spotify.client\" to set repeating to true"
    )
    private lazy var repeatOffScript = NSAppleScript(
        source: "tell application id \"com.spotify.client\" to set repeating to false"
    )

    private static let snapshotSource = """
    tell application id "com.spotify.client"
        if player state is stopped then return "stopped"
        set fieldSeparator to ASCII character 31
        set activeTrack to current track
        return "track" & fieldSeparator & (player state as text) & fieldSeparator & (id of activeTrack as text) & fieldSeparator & (name of activeTrack as text) & fieldSeparator & (artist of activeTrack as text) & fieldSeparator & (album of activeTrack as text) & fieldSeparator & (artwork url of activeTrack as text) & fieldSeparator & (spotify url of activeTrack as text) & fieldSeparator & (duration of activeTrack as text) & fieldSeparator & (player position as text) & fieldSeparator & (sound volume as text) & fieldSeparator & (shuffling enabled as text) & fieldSeparator & (shuffling as text) & fieldSeparator & (repeating enabled as text) & fieldSeparator & (repeating as text)
    end tell
    """

    func snapshot() throws -> SpotifySnapshot {
        guard !NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleIdentifier
        ).isEmpty else {
            return .notRunning
        }

        return try SpotifyResponseParser.parse(execute(snapshotScript))
    }

    func playPause() throws {
        try execute(playPauseScript)
    }

    func nextTrack() throws {
        try execute(nextTrackScript)
    }

    func previousTrack() throws {
        try execute(previousTrackScript)
    }

    func setVolume(_ volume: Int) throws {
        let clampedVolume = min(max(volume, 0), 100)
        let script: NSAppleScript
        if let cachedScript = volumeScripts[clampedVolume] {
            script = cachedScript
        } else {
            guard let newScript = NSAppleScript(
                source: "tell application id \"com.spotify.client\" to set sound volume to \(clampedVolume)"
            ) else {
                throw SpotifyBridgeError.malformedResponse
            }
            volumeScripts[clampedVolume] = newScript
            script = newScript
        }

        try execute(script)
    }

    func seek(to position: TimeInterval) throws {
        let targetSecond = max(0, Int(position.rounded()))
        let script: NSAppleScript
        if let cachedScript = seekScripts[targetSecond] {
            script = cachedScript
        } else {
            guard let newScript = NSAppleScript(
                source: "tell application id \"com.spotify.client\" to set player position to \(targetSecond)"
            ) else {
                throw SpotifyBridgeError.malformedResponse
            }
            seekScripts[targetSecond] = newScript
            script = newScript
        }

        try execute(script)
    }

    func setShuffle(_ enabled: Bool) throws {
        try execute(enabled ? shuffleOnScript : shuffleOffScript)
    }

    func setRepeat(_ enabled: Bool) throws {
        try execute(enabled ? repeatOnScript : repeatOffScript)
    }

    func openSpotify() {
        if let runningApplication = NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleIdentifier
        ).first {
            runningApplication.activate()
            return
        }

        guard let applicationURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: bundleIdentifier
        ) else {
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(
            at: applicationURL,
            configuration: configuration
        )
    }

    func openCurrentTrack(_ track: SpotifyTrack?) {
        if let url = track?.spotifyURL {
            NSWorkspace.shared.open(url)
        } else {
            openSpotify()
        }
    }

    @discardableResult
    private func execute(_ script: NSAppleScript?) throws -> String {
        guard let script else {
            throw SpotifyBridgeError.malformedResponse
        }

        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)

        if let error {
            let number = error[NSAppleScript.errorNumber] as? Int
            if number == -1743 {
                throw SpotifyBridgeError.automationDenied
            }

            let message = error[NSAppleScript.errorMessage] as? String
                ?? "Unbekannter AppleScript-Fehler"
            throw SpotifyBridgeError.script(message: message)
        }

        return result.stringValue ?? ""
    }
}
