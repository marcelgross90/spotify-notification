import AppKit
import Observation
import UserNotifications

enum PermissionStatus: Equatable, Sendable {
    case unknown
    case notDetermined
    case allowed
    case denied
}

@Observable
@MainActor
final class PermissionStatusService {
    private(set) var notifications: PermissionStatus = .unknown

    func refresh() {
        Task {
            let status: PermissionStatus = await withCheckedContinuation { continuation in
                UNUserNotificationCenter.current().getNotificationSettings { settings in
                    let status: PermissionStatus = switch settings.authorizationStatus {
                    case .authorized, .provisional, .ephemeral:
                        .allowed
                    case .denied:
                        .denied
                    case .notDetermined:
                        .notDetermined
                    @unknown default:
                        .unknown
                    }
                    continuation.resume(returning: status)
                }
            }
            notifications = status
        }
    }
}

enum SystemSettingsDestination {
    case automation
    case notifications
    case loginItems

    fileprivate var url: URL? {
        let value = switch self {
        case .automation:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
        case .notifications:
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=de.marcelgross.SpotifyNotification"
        case .loginItems:
            "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"
        }
        return URL(string: value)
    }
}

@MainActor
enum SystemSettingsService {
    static func open(_ destination: SystemSettingsDestination) {
        if let url = destination.url, NSWorkspace.shared.open(url) {
            return
        }

        guard let settingsURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.apple.systempreferences"
        ) else {
            return
        }
        NSWorkspace.shared.open(settingsURL)
    }
}
