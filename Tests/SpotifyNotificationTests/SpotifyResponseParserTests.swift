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
            "spotify:track:123",
            "245000",
            "42.5",
            "65",
            "true",
            "false",
            "true",
            "true"
        ].joined(separator: separator)

        let snapshot = try SpotifyResponseParser.parse(response)

        #expect(snapshot.isRunning)
        #expect(snapshot.state == .playing)
        #expect(snapshot.track?.name == "Song Name")
        #expect(snapshot.track?.artist == "Artist Name")
        #expect(snapshot.track?.artworkURL?.absoluteString == "https://example.com/cover.jpg")
        #expect(snapshot.track?.duration == 245)
        #expect(snapshot.position == 42.5)
        #expect(snapshot.volume == 65)
        #expect(snapshot.isShuffleAvailable)
        #expect(!snapshot.isShuffling)
        #expect(snapshot.isRepeatAvailable)
        #expect(snapshot.isRepeating)
    }

    @Test
    func convertsSpotifyDurationFromMillisecondsToSeconds() throws {
        let separator = SpotifyResponseParser.separator
        let response = [
            "track", "playing", "id", "Short Song", "Artist", "Album", "", "",
            "9500", "3.25", "50", "true", "false", "true", "false"
        ].joined(separator: separator)

        let snapshot = try SpotifyResponseParser.parse(response)

        #expect(snapshot.track?.duration == 9.5)
        #expect(snapshot.position == 3.25)
    }

    @Test
    func parsesLocalizedDecimalPosition() throws {
        let separator = SpotifyResponseParser.separator
        let response = [
            "track", "paused", "id", "Song", "Artist", "Album", "", "",
            "180000", "12,5", "40", "false", "false", "false", "false"
        ].joined(separator: separator)

        let snapshot = try SpotifyResponseParser.parse(response)

        #expect(snapshot.position == 12.5)
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
