import SwiftUI

@main
@MainActor
struct SpotifyNotificationApp: App {
    @State private var model: PlayerViewModel

    init() {
        let model = PlayerViewModel()
        _model = State(initialValue: model)
        model.start()

        if CommandLine.arguments.contains("--preview-overlay") {
            Task {
                try? await Task.sleep(for: .seconds(1))
                model.refresh()
                model.previewOverlay()
            }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            PlayerMenuView(model: model)
        } label: {
            Image(nsImage: SpotifyMenuBarIcon.image)
                .accessibilityLabel("Spotify Notification")
        }
        .menuBarExtraStyle(.window)
    }
}
