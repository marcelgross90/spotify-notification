import Foundation
@preconcurrency import UserNotifications

@MainActor
protocol TrackNotifying {
    func requestAuthorization() async throws -> Bool
    func notify(track: SpotifyTrack, playsSound: Bool) async
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

    func notify(track: SpotifyTrack, playsSound: Bool) async {
        let content = UNMutableNotificationContent()
        content.title = track.name
        content.subtitle = track.artist
        content.body = track.album
        content.sound = playsSound ? .default : nil
        if let attachment = await artworkAttachment(for: track) {
            content.attachments = [attachment]
        }

        let request = UNNotificationRequest(
            identifier: "track-\(track.id)",
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }

    private func artworkAttachment(for track: SpotifyTrack) async -> UNNotificationAttachment? {
        guard let artworkURL = track.artworkURL else { return nil }

        do {
            let (downloadURL, response) = try await URLSession.shared.download(from: artworkURL)
            let fileManager = FileManager.default
            let directory = try artworkDirectory(fileManager: fileManager)
            removeExpiredArtwork(in: directory, fileManager: fileManager)

            let fileExtension = Self.fileExtension(
                mimeType: response.mimeType,
                sourceURL: artworkURL
            )
            let destinationURL = directory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(fileExtension)

            try fileManager.moveItem(at: downloadURL, to: destinationURL)
            return try UNNotificationAttachment(
                identifier: "album-cover",
                url: destinationURL
            )
        } catch {
            return nil
        }
    }

    private func artworkDirectory(fileManager: FileManager) throws -> URL {
        let cachesDirectory = try fileManager.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = cachesDirectory
            .appendingPathComponent("SpotifyNotification", isDirectory: true)
            .appendingPathComponent("NotificationArtwork", isDirectory: true)
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }

    private func removeExpiredArtwork(in directory: URL, fileManager: FileManager) {
        let expirationDate = Date().addingTimeInterval(-86_400)
        let files = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        )

        for file in files ?? [] {
            let values = try? file.resourceValues(forKeys: [.contentModificationDateKey])
            if let modificationDate = values?.contentModificationDate,
               modificationDate < expirationDate {
                try? fileManager.removeItem(at: file)
            }
        }
    }

    static func fileExtension(mimeType: String?, sourceURL: URL) -> String {
        switch mimeType?.lowercased() {
        case "image/png":
            return "png"
        case "image/gif":
            return "gif"
        case "image/webp":
            return "webp"
        case "image/heic", "image/heif":
            return "heic"
        default:
            let sourceExtension = sourceURL.pathExtension.lowercased()
            return sourceExtension.isEmpty ? "jpg" : sourceExtension
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if notification.request.content.sound == nil {
            completionHandler([.banner])
        } else {
            completionHandler([.banner, .sound])
        }
    }
}
