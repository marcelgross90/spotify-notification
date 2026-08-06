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
    dependencies: [
        .package(
            url: "https://github.com/sparkle-project/Sparkle",
            exact: "2.9.5"
        ),
        .package(
            url: "https://github.com/sindresorhus/KeyboardShortcuts",
            exact: "3.0.1"
        )
    ],
    targets: [
        .executableTarget(
            name: "SpotifyNotification",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")
            ]
        ),
        .testTarget(
            name: "SpotifyNotificationTests",
            dependencies: ["SpotifyNotification"]
        )
    ]
)
