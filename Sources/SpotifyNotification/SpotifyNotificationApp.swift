import SwiftUI

@main
@MainActor
struct SpotifyNotificationApp: App {
    @State private var model: PlayerViewModel

    init() {
        let model = PlayerViewModel()
        _model = State(initialValue: model)
        model.start()
    }

    var body: some Scene {
        MenuBarExtra {
            PlayerMenuView(model: model)
        } label: {
            Image(nsImage: SpotifyMenuBarIcon.image)
                .accessibilityLabel(L10n.string("app.accessibility_label"))
        }
        .menuBarExtraStyle(.window)
    }
}
