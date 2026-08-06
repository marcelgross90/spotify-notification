import Sparkle

@MainActor
protocol AppUpdating: AnyObject {
    var automaticallyChecksForUpdates: Bool { get set }
    func checkForUpdates()
}

@MainActor
final class SparkleUpdateController: AppUpdating {
    private let controller = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
