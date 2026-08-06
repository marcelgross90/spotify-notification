import Testing
@testable import SpotifyNotification

struct UpdateServiceTests {
    @Test(arguments: [
        ("0.5.1", "0.5.0"),
        ("0.6.0", "0.5.9"),
        ("1.0.0", "0.99.99"),
        ("v2.1.0", "2.0.9"),
        ("1.2.10", "1.2.9")
    ])
    func detectsNewerVersions(candidate: String, current: String) {
        #expect(GitHubUpdateService.isVersion(candidate, newerThan: current))
    }

    @Test(arguments: [
        ("0.5.0", "0.5.0"),
        ("0.4.9", "0.5.0"),
        ("v1.0.0", "1.0.0"),
        ("1.2", "1.2.0"),
        ("invalid", "1.0.0")
    ])
    func rejectsCurrentOlderAndInvalidVersions(candidate: String, current: String) {
        #expect(!GitHubUpdateService.isVersion(candidate, newerThan: current))
    }
}
