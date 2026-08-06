import Foundation
@preconcurrency import UserNotifications

@MainActor
protocol TrackNotifying {
    func requestAuthorization() async throws -> Bool
    func notify(track: SpotifyTrack) async
}

@MainActor
final class TrackNotificationService: NSObject, TrackNotifying, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    func notify(track: SpotifyTrack) async {
        let content = UNMutableNotificationContent()
        content.title = track.name
        content.subtitle = track.artist
        content.body = track.album
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "track-\(track.id)",
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
