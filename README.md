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
- Configurable menu bar text format and length
- Copy track details or the Spotify link
- Sleep timer for a duration or the end of the current track
- User-configurable global keyboard shortcuts without extra permissions
- Native settings and permission status window
- Secure in-app updates powered by Sparkle
- Optional daily background update checks
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

Open the three-dot menu and select **Check for updates**. If a signed update is available, the app shows its release information and can download, install, and relaunch itself after confirmation. Automatic daily checks are optional and disabled by default.

Updates are delivered through [Sparkle](https://sparkle-project.org/) and GitHub Releases. Both the appcast feed and every update archive are verified with an EdDSA signature before extraction. Silent automatic downloads are explicitly disabled.

Personal builds use an ad-hoc application signature and are not notarized. The initial installation therefore still requires the one-time Gatekeeper confirmation described above. Sparkle update signatures protect subsequent updates independently of an Apple Developer ID.

## Privacy

Spotify Notification communicates only with:

- the locally installed Spotify app through Apple's Automation interface;
- Spotify's cover-art URL when artwork is displayed or attached to a notification;
- the signed update feed and archive hosted on GitHub Releases when an update check is requested or enabled in the background.

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

Before the first release, configure the private Sparkle key as a GitHub Actions secret. The key remains in the local macOS Keychain and is exported only to GitHub's encrypted secret storage:

```sh
brew install gh
gh auth login
./scripts/configure-sparkle-secret.sh
```

Then create a release:

1. Update `CFBundleShortVersionString` and `CFBundleVersion` in `App/Info.plist`.
2. Commit and push the change to `main`.
3. Create and push a matching version tag, for example `v0.7.0`.

The release workflow validates the tag, runs all tests, builds the app, signs the update archive and appcast, and publishes the ZIP, appcast, and SHA-256 checksum as a GitHub Release. The private update key is never written to the repository or workflow logs.

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

The bundled Sparkle framework and KeyboardShortcuts package are distributed under their own permissive licenses, included inside the application bundle.

Spotify is a trademark of Spotify AB. This project is not affiliated with or endorsed by Spotify.
