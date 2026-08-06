import SwiftUI

struct PlayerMenuView: View {
    @Bindable var model: PlayerViewModel
    private let spotifyGreen = Color(red: 0.114, green: 0.725, blue: 0.329)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            playerContent

            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let notificationMessage = model.notificationMessage {
                Text(notificationMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            Toggle("Titelwechsel-Mitteilungen", isOn: $model.notificationsEnabled)

            Toggle(
                "Beim Anmelden öffnen",
                isOn: Binding(
                    get: { model.launchAtLoginEnabled },
                    set: { enabled in
                        model.setLaunchAtLogin(enabled)
                    }
                )
            )

            HStack {
                Spacer()

                Button("Beenden") {
                    model.quit()
                }
            }
        }
        .padding(16)
        .frame(width: 340)
    }

    @ViewBuilder
    private var playerContent: some View {
        if !model.snapshot.isRunning {
            VStack(spacing: 12) {
                ContentUnavailableView(
                    "Spotify ist geschlossen",
                    systemImage: "music.note",
                    description: Text("Öffne Spotify, um die Wiedergabe anzuzeigen und zu steuern.")
                )

                Button("Spotify öffnen") {
                    model.openSpotify()
                }
            }
        } else if let track = model.snapshot.track {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    artwork(for: track)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(track.name)
                            .font(.headline)
                            .lineLimit(2)
                        Text(track.artist)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text(track.album)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 24) {
                    Spacer()
                    controlButton("backward.fill", "Vorheriger Titel", model.previousTrack)
                    controlButton(
                        model.snapshot.state == .playing ? "pause.fill" : "play.fill",
                        model.snapshot.state == .playing ? "Pause" : "Wiedergabe",
                        model.playPause
                    )
                    controlButton("forward.fill", "Nächster Titel", model.nextTrack)
                    Spacer()
                }

                playbackProgress(for: track)

                volumeControl

                Button("In Spotify anzeigen") {
                    model.openCurrentTrack()
                }
                .frame(maxWidth: .infinity)
            }
        } else {
            VStack(spacing: 12) {
                ContentUnavailableView(
                    "Keine Wiedergabe",
                    systemImage: "pause.circle",
                    description: Text("Starte einen Titel in Spotify.")
                )

                Button("Spotify anzeigen") {
                    model.openSpotify()
                }
            }
        }
    }

    @ViewBuilder
    private func playbackProgress(for track: SpotifyTrack) -> some View {
        if track.duration > 0 {
            let position = min(max(model.snapshot.position, 0), track.duration)

            VStack(spacing: 4) {
                ProgressView(value: position, total: track.duration)
                    .progressViewStyle(.linear)
                    .tint(spotifyGreen)

                HStack {
                    Text(formattedTime(position))
                    Spacer()
                    Text(formattedTime(track.duration))
                }
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)
            }
        }
    }

    private var volumeControl: some View {
        HStack(spacing: 10) {
            Button {
                model.toggleMute()
            } label: {
                Image(systemName: model.isMuted ? "speaker.slash.fill" : "speaker.fill")
                    .frame(width: 18, height: 18)
                    .foregroundStyle(model.isMuted ? spotifyGreen : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(model.isMuted ? "Spotify-Ton einschalten" : "Spotify stummschalten")
            .help(model.isMuted ? "Ton einschalten" : "Stummschalten")

            Slider(
                value: Binding(
                    get: { model.volume },
                    set: { value in
                        model.updateVolume(value)
                    }
                ),
                in: 0...100,
                step: 1,
                onEditingChanged: { editing in
                    model.setVolumeEditing(editing)
                }
            )
            .tint(spotifyGreen)
            .accessibilityLabel("Spotify-Lautstärke")

            Image(systemName: "speaker.wave.3.fill")
                .foregroundStyle(.secondary)
        }
        .font(.caption)
    }

    private func formattedTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = max(0, Int(seconds.rounded(.down)))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let remainingSeconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        }
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }

    private func artwork(for track: SpotifyTrack) -> some View {
        AsyncImage(url: track.artworkURL) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            ZStack {
                Color.secondary.opacity(0.15)
                Image(systemName: "music.note")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func controlButton(
        _ systemName: String,
        _ accessibilityLabel: String,
        _ action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title2)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
