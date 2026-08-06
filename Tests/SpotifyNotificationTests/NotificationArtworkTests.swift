import Foundation
import Testing
@testable import SpotifyNotification

@MainActor
struct NotificationArtworkTests {
    @Test
    func derivesExtensionFromMimeType() {
        let result = TrackNotificationService.fileExtension(
            mimeType: "image/png",
            sourceURL: URL(string: "https://example.com/image")!
        )

        #expect(result == "png")
    }

    @Test
    func fallsBackToJpegForExtensionlessURL() {
        let result = TrackNotificationService.fileExtension(
            mimeType: "image/jpeg",
            sourceURL: URL(string: "https://example.com/image")!
        )

        #expect(result == "jpg")
    }
}
