# Spotify Notification

A lightweight macOS menu bar player for the locally installed Spotify desktop app. It shows the current track, provides essential playback controls, and displays a native notification when the track changes — without requiring a Spotify login.

[![CI](https://github.com/marcelgross90/spotify-notification/actions/workflows/ci.yml/badge.svg)](https://github.com/marcelgross90/spotify-notification/actions/workflows/ci.yml)
[![Latest release](https://img.shields.io/github/v/release/marcelgross90/spotify-notification)](https://github.com/marcelgross90/spotify-notification/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## Features

- Current track, artist, album, and cover art
- Play, pause, previous track, and next track
- Smooth playback progress with interactive seeking
- Spotify volume control and mute toggle
- Shuffle and context repeat when supported by the current Spotify playback context
- Native macOS track-change notifications with cover art
- Optional launch at login
- Optional current track title next to the menu bar icon
- Manual update checks through GitHub Releases
- Native Liquid Glass design on macOS 26 with a material fallback on older systems
- No Spotify OAuth, cloud storage, analytics, statistics, or telemetry

## Languages

The app follows the macOS system language and currently includes:

- English
- German
- French
- Spanish
- Italian
- Dutch
- Portuguese

English is used as the fallback for unsupported languages.

## Requirements

- macOS 14 or later
- Apple Silicon Mac for the prebuilt release
- Spotify desktop app for macOS

## Installation

1. Download the latest ZIP from [GitHub Releases](https://github.com/marcelgross90/spotify-notification/releases/latest).
2. Extract `Spotify Notification.app` and move it to the Applications folder.
3. Open the app. Because personal releases are not notarized with an Apple Developer account, macOS may require confirmation in **System Settings → Privacy & Security** on first launch.
4. Allow Automation access when macOS asks for permission to control Spotify.
5. Allow notifications if track-change alerts are desired.

The app runs only in the menu bar and does not add an icon to the Dock.

## Updates

Open the three-dot menu and select **Check for updates**. The app queries the public GitHub Releases API and reports whether a newer version exists. If an update is available, the release page can be opened directly to review and download it.

No GitHub token or background update service is used.

## Privacy

Spotify Notification communicates only with:

- the locally installed Spotify app through Apple's Automation interface;
- Spotify's cover-art URL when artwork is displayed or attached to a notification;
- the public GitHub Releases API when an update check is requested.

No listening history, account information, or usage data is collected or stored.

## Build from source

Building requires Xcode 26 or later.

```sh
git clone git@github.com:marcelgross90/spotify-notification.git
cd spotify-notification
make test
make app
```

The packaged app is written to:

```text
dist/Spotify Notification.app
```

The packaging script applies an ad-hoc code signature suitable for personal use.

## Creating a release

1. Update `CFBundleShortVersionString` and `CFBundleVersion` in `App/Info.plist`.
2. Commit and push the change to `main`.
3. Create and push a matching version tag, for example `v0.6.0`.

The release workflow validates the tag, runs all tests, builds the app, creates a ZIP and SHA-256 checksum, and publishes both files as a GitHub Release.

## Project structure

```text
App/                         App metadata, icon, and localizations
Sources/SpotifyNotification/ Swift and SwiftUI application code
Tests/                       Unit tests
scripts/                     Packaging and validation scripts
.github/workflows/           Continuous integration and release automation
```

## License

Spotify Notification is available under the [MIT License](LICENSE).

Spotify is a trademark of Spotify AB. This project is not affiliated with or endorsed by Spotify.
