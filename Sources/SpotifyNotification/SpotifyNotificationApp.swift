import Darwin
import KeyboardShortcuts
import SwiftUI

@main
@MainActor
struct SpotifyNotificationApp: App {
    @State private var model: PlayerViewModel
    private let shortcutService: GlobalShortcutService

    init() {
        if ProcessInfo.processInfo.environment[
            "SPOTIFY_NOTIFICATION_VERIFY_SHORTCUT_RESOURCES"
        ] == "1" {
            _ = KeyboardShortcuts.RecorderCocoa(for: .playPauseSpotify)
            exit(EXIT_SUCCESS)
        }

        let model = PlayerViewModel()
        _model = State(initialValue: model)
        shortcutService = GlobalShortcutService(model: model)
        model.start()
    }

    var body: some Scene {
        MenuBarExtra {
            PlayerMenuView(model: model)
        } label: {
            HStack(spacing: 5) {
                Image(nsImage: SpotifyMenuBarIcon.image)

                if let menuBarTitle = model.menuBarTitle {
                    Text(menuBarTitle)
                        .lineLimit(1)
                        .frame(maxWidth: 190, alignment: .leading)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                model.menuBarTitle.map {
                    L10n.format("app.accessibility_label_with_track", $0)
                } ?? L10n.string("app.accessibility_label")
            )
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
        }
    }
}
