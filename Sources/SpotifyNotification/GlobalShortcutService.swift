import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let playPauseSpotify = Self("playPauseSpotify")
    static let previousSpotifyTrack = Self("previousSpotifyTrack")
    static let nextSpotifyTrack = Self("nextSpotifyTrack")
    static let muteSpotify = Self("muteSpotify")
}

@MainActor
final class GlobalShortcutService {
    init(model: PlayerViewModel) {
        KeyboardShortcuts.removeAllHandlers()

        KeyboardShortcuts.onKeyUp(for: .playPauseSpotify) { [weak model] in
            model?.playPause()
        }
        KeyboardShortcuts.onKeyUp(for: .previousSpotifyTrack) { [weak model] in
            model?.previousTrack()
        }
        KeyboardShortcuts.onKeyUp(for: .nextSpotifyTrack) { [weak model] in
            model?.nextTrack()
        }
        KeyboardShortcuts.onKeyUp(for: .muteSpotify) { [weak model] in
            model?.toggleMute()
        }
    }
}
