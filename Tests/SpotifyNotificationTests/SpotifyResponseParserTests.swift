import Testing
@testable import SpotifyNotification

struct SpotifyResponseParserTests {
    @Test
    func parsesTrackResponse() throws {
        let separator = SpotifyResponseParser.separator
        let response = [
            "track",
            "playing",
            "spotify:track:123",
            "Song Name",
            "Artist Name",
            "Album Name",
            "https://example.com/cover.jpg",
            "spotify:track:123"
        ].joined(separator: separator)

        let snapshot = try SpotifyResponseParser.parse(response)

        #expect(snapshot.isRunning)
        #expect(snapshot.state == .playing)
        #expect(snapshot.track?.name == "Song Name")
        #expect(snapshot.track?.artist == "Artist Name")
        #expect(snapshot.track?.artworkURL?.absoluteString == "https://example.com/cover.jpg")
    }

    @Test
    func parsesStoppedResponse() throws {
        let snapshot = try SpotifyResponseParser.parse("stopped")

        #expect(snapshot.isRunning)
        #expect(snapshot.state == .stopped)
        #expect(snapshot.track == nil)
    }

    @Test
    func parsesNotRunningResponse() throws {
        let snapshot = try SpotifyResponseParser.parse("not_running")

        #expect(!snapshot.isRunning)
        #expect(snapshot.track == nil)
    }

    @Test
    func rejectsMalformedResponse() {
        #expect(throws: SpotifyBridgeError.malformedResponse) {
            try SpotifyResponseParser.parse("track\u{001F}playing")
        }
    }
}
