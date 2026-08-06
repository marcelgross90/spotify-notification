import SwiftUI

struct PlayerMenuView: View {
    @Bindable var model: PlayerViewModel

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
