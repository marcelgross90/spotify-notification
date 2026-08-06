import SwiftUI

struct PlayerMenuView: View {
    @Bindable var model: PlayerViewModel
    private let spotifyGreen = Color(red: 0.114, green: 0.725, blue: 0.329)

    var body: some View {
        liquidGlassPanel {
            VStack(alignment: .leading, spacing: 18) {
                playerContent

                if let errorMessage = model.errorMessage {
                    statusMessage(errorMessage, color: .red)
                }

                if let notificationMessage = model.notificationMessage {
                    statusMessage(notificationMessage, color: .orange)
                }

            }
            .padding(22)
        }
        .padding(10)
        .frame(width: 390)
    }

    @ViewBuilder
    private var playerContent: some View {
        if !model.snapshot.isRunning {
            unavailablePlayer(
                title: L10n.string("player.spotify_closed.title"),
                systemImage: "music.note",
                description: L10n.string("player.spotify_closed.description"),
                buttonTitle: L10n.string("player.spotify_open")
            )
        } else if let track = model.snapshot.track {
            VStack(alignment: .leading, spacing: 18) {
                trackHeader(for: track)
                playbackProgress(for: track)
                playbackControls
                Divider()
                playerFooter
            }
        } else {
            unavailablePlayer(
                title: L10n.string("player.no_playback.title"),
                systemImage: "pause.circle",
                description: L10n.string("player.no_playback.description"),
                buttonTitle: L10n.string("player.spotify_show")
            )
        }
    }

    private func trackHeader(for track: SpotifyTrack) -> some View {
        HStack(spacing: 16) {
            artwork(for: track)

            VStack(alignment: .leading, spacing: 5) {
                Text(track.name)
                    .font(.system(size: 20, weight: .bold))
                    .lineLimit(2)
                Text("\(track.artist) — \(track.album)")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func playbackProgress(for track: SpotifyTrack) -> some View {
        if track.duration > 0 {
            TimelineView(
                .animation(
                    minimumInterval: 1.0 / 30.0,
                    paused: model.snapshot.state != .playing || model.isSeeking
                )
            ) { context in
                let displayedPosition = model.displayedPosition(at: context.date)

                VStack(spacing: 6) {
                    Slider(
                        value: Binding(
                            get: { displayedPosition },
                            set: { model.updatePosition($0) }
                        ),
                        in: 0...track.duration,
                        onEditingChanged: { editing in
                            model.setPositionEditing(editing)
                        }
                    )
                    .controlSize(.small)
                    .tint(spotifyGreen)
                    .accessibilityLabel(L10n.string("player.position"))
                    .accessibilityValue(formattedTime(displayedPosition))

                    HStack {
                        Text(formattedTime(displayedPosition))
                        Spacer()
                        Text(formattedTime(track.duration))
                    }
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var playbackControls: some View {
        HStack(spacing: 22) {
            Spacer(minLength: 0)
            modeButton(
                "shuffle",
                isActive: model.snapshot.isShuffling,
                isEnabled: model.snapshot.isShuffleAvailable,
                activeLabel: L10n.string("player.shuffle.disable"),
                inactiveLabel: L10n.string("player.shuffle.enable"),
                action: { model.toggleShuffle() }
            )
            controlButton(
                "backward.fill",
                L10n.string("player.previous"),
                model.previousTrack
            )
            playPauseButton
            controlButton("forward.fill", L10n.string("player.next"), model.nextTrack)
            modeButton(
                "repeat",
                isActive: model.snapshot.isRepeating,
                isEnabled: model.snapshot.isRepeatAvailable,
                activeLabel: L10n.string("player.repeat.disable"),
                inactiveLabel: L10n.string("player.repeat.enable"),
                action: { model.toggleRepeat() }
            )
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var playPauseButton: some View {
        let systemName = model.snapshot.state == .playing ? "pause.fill" : "play.fill"
        let label = model.snapshot.state == .playing
            ? L10n.string("player.pause")
            : L10n.string("player.play")

        if #available(macOS 26.0, *) {
            Button(action: model.playPause) {
                Image(systemName: systemName)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.glass)
            .accessibilityLabel(label)
        } else {
            Button(action: model.playPause) {
                Image(systemName: systemName)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 42, height: 42)
                    .background(.regularMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
        }
    }

    private var playerFooter: some View {
        HStack(spacing: 14) {
            Button(L10n.string("player.show_in_spotify"), action: model.openCurrentTrack)
                .buttonStyle(.plain)
                .font(.system(size: 14, weight: .medium))

            Spacer(minLength: 8)

            volumeControl
            optionsMenu
        }
    }

    private var volumeControl: some View {
        HStack(spacing: 8) {
            Button(action: model.toggleMute) {
                Image(systemName: model.isMuted ? "speaker.slash.fill" : "speaker.fill")
                    .frame(width: 17, height: 17)
                    .foregroundStyle(model.isMuted ? spotifyGreen : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                model.isMuted
                    ? L10n.string("player.unmute_spotify")
                    : L10n.string("player.mute_spotify")
            )
            .help(
                model.isMuted
                    ? L10n.string("player.unmute")
                    : L10n.string("player.mute")
            )

            Slider(
                value: Binding(
                    get: { model.volume },
                    set: { model.updateVolume($0) }
                ),
                in: 0...100,
                onEditingChanged: { editing in
                    model.setVolumeEditing(editing)
                }
            )
            .frame(width: 78)
            .controlSize(.small)
            .tint(spotifyGreen)
            .accessibilityLabel(L10n.string("player.volume"))
        }
    }

    private var optionsMenu: some View {
        Menu {
            Toggle(
                L10n.string("menu.track_notifications"),
                isOn: $model.notificationsEnabled
            )
            Toggle(
                L10n.string("menu.launch_at_login"),
                isOn: Binding(
                    get: { model.launchAtLoginEnabled },
                    set: { enabled in
                        model.setLaunchAtLogin(enabled)
                    }
                )
            )
            Toggle(
                L10n.string("menu.show_track_in_menu_bar"),
                isOn: $model.showTrackInMenuBar
            )

            Divider()

            Text(L10n.format("menu.version", model.appVersion))
            Toggle(
                L10n.string("menu.automatic_update_checks"),
                isOn: Binding(
                    get: { model.automaticallyChecksForUpdates },
                    set: { enabled in
                        model.automaticallyChecksForUpdates = enabled
                    }
                )
            )
            Button(L10n.string("menu.check_for_updates"), action: model.checkForUpdates)

            Divider()

            Button(L10n.string("menu.quit"), action: model.quit)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 28, height: 28)
                .contentShape(Circle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel(L10n.string("menu.more_options"))
        .help(L10n.string("menu.more_options"))
    }

    private func unavailablePlayer(
        title: String,
        systemImage: String,
        description: String,
        buttonTitle: String
    ) -> some View {
        VStack(spacing: 14) {
            ContentUnavailableView(
                title,
                systemImage: systemImage,
                description: Text(description)
            )

            Button(buttonTitle, action: model.openSpotify)
                .buttonStyle(.borderedProminent)

            Divider()
            optionsMenu
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func statusMessage(_ message: String, color: Color) -> some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.caption)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
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
                Color.secondary.opacity(0.12)
                Image(systemName: "music.note")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 84, height: 84)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 0.5)
        }
    }

    private func controlButton(
        _ systemName: String,
        _ accessibilityLabel: String,
        _ action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private func modeButton(
        _ systemName: String,
        isActive: Bool,
        isEnabled: Bool,
        activeLabel: String,
        inactiveLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 26, height: 26)
                .foregroundStyle(isActive ? spotifyGreen : Color.secondary)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.32)
        .accessibilityLabel(isActive ? activeLabel : inactiveLabel)
        .help(isActive ? activeLabel : inactiveLabel)
    }

    @ViewBuilder
    private func liquidGlassPanel<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        if #available(macOS 26.0, *) {
            content()
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        } else {
            content()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.separator.opacity(0.5), lineWidth: 1)
                }
        }
    }
}
