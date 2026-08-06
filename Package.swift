// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SpotifyNotification",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "SpotifyNotification",
            targets: ["SpotifyNotification"]
        )
    ],
    targets: [
        .executableTarget(
            name: "SpotifyNotification"
        ),
        .testTarget(
            name: "SpotifyNotificationTests",
            dependencies: ["SpotifyNotification"]
        )
    ]
)
