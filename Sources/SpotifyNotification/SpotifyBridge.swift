import AppKit
import Foundation

@MainActor
protocol SpotifyControlling {
    func snapshot() throws -> SpotifySnapshot
    func playPause() throws
    func nextTrack() throws
    func previousTrack() throws
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

    private static let snapshotSource = """
    tell application id "com.spotify.client"
        if player state is stopped then return "stopped"
        set fieldSeparator to ASCII character 31
        set activeTrack to current track
        return "track" & fieldSeparator & (player state as text) & fieldSeparator & (id of activeTrack as text) & fieldSeparator & (name of activeTrack as text) & fieldSeparator & (artist of activeTrack as text) & fieldSeparator & (album of activeTrack as text) & fieldSeparator & (artwork url of activeTrack as text) & fieldSeparator & (spotify url of activeTrack as text)
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
