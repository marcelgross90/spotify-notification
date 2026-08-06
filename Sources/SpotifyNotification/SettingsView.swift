import AppKit
import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    @Bindable var model: PlayerViewModel
    @State private var permissionService = PermissionStatusService()

    var body: some View {
        TabView {
            GeneralSettingsView(model: model)
                .tabItem {
                    Label(L10n.string("settings.general"), systemImage: "gearshape")
                }

            ShortcutSettingsView()
                .tabItem {
                    Label(L10n.string("settings.shortcuts"), systemImage: "keyboard")
                }

            PermissionSettingsView(
                model: model,
                permissionService: permissionService
            )
            .tabItem {
                Label(L10n.string("settings.permissions"), systemImage: "checkmark.shield")
            }

            UpdateSettingsView(model: model)
                .tabItem {
                    Label(L10n.string("settings.updates"), systemImage: "arrow.triangle.2.circlepath")
                }
        }
        .frame(width: 560, height: 370)
        .task {
            permissionService.refresh()
        }
    }
}

private struct GeneralSettingsView: View {
    @Bindable var model: PlayerViewModel

    var body: some View {
        Form {
            Section(L10n.string("settings.general.behavior")) {
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
            }

            Section(L10n.string("settings.menu_bar")) {
                Picker(
                    L10n.string("settings.menu_bar.content"),
                    selection: $model.menuBarDisplayMode
                ) {
                    ForEach(MenuBarDisplayMode.allCases) { mode in
                        Text(title(for: mode)).tag(mode)
                    }
                }

                if model.menuBarDisplayMode != .iconOnly {
                    LabeledContent(L10n.string("settings.menu_bar.maximum_length")) {
                        HStack(spacing: 10) {
                            Slider(
                                value: Binding(
                                    get: { Double(model.menuBarMaximumLength) },
                                    set: { model.menuBarMaximumLength = Int($0.rounded()) }
                                ),
                                in: Double(PlayerViewModel.minimumMenuBarTitleLength)...Double(PlayerViewModel.maximumMenuBarTitleLength),
                                step: 1
                            )
                            .frame(width: 170)

                            Text("\(model.menuBarMaximumLength)")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .frame(width: 28, alignment: .trailing)
                        }
                    }
                }

                MenuBarPreview(model: model)
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
    }

    private func title(for mode: MenuBarDisplayMode) -> String {
        switch mode {
        case .iconOnly:
            L10n.string("settings.menu_bar.icon_only")
        case .title:
            L10n.string("settings.menu_bar.title")
        case .artistAndTitle:
            L10n.string("settings.menu_bar.artist_title")
        case .titleAndArtist:
            L10n.string("settings.menu_bar.title_artist")
        }
    }
}

private struct MenuBarPreview: View {
    let model: PlayerViewModel

    private var previewTrack: SpotifyTrack {
        model.snapshot.track ?? SpotifyTrack(
            id: "preview",
            name: L10n.string("settings.menu_bar.preview_track"),
            artist: L10n.string("settings.menu_bar.preview_artist"),
            album: "",
            artworkURL: nil,
            spotifyURL: nil
        )
    }

    private var previewText: String? {
        guard let text = model.menuBarDisplayMode.text(for: previewTrack) else {
            return nil
        }
        guard text.count > model.menuBarMaximumLength else { return text }
        return String(text.prefix(model.menuBarMaximumLength - 1)) + "…"
    }

    var body: some View {
        LabeledContent(L10n.string("settings.menu_bar.preview")) {
            HStack(spacing: 6) {
                Image(nsImage: SpotifyMenuBarIcon.image)
                if let previewText {
                    Text(previewText)
                        .lineLimit(1)
                }
            }
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: Capsule())
            .overlay {
                Capsule().stroke(.separator.opacity(0.7), lineWidth: 0.5)
            }
        }
    }
}

private struct ShortcutSettingsView: View {
    var body: some View {
        Form {
            Section {
                shortcutRecorder(
                    L10n.string("settings.shortcuts.play_pause"),
                    name: .playPauseSpotify
                )
                shortcutRecorder(
                    L10n.string("settings.shortcuts.previous"),
                    name: .previousSpotifyTrack
                )
                shortcutRecorder(
                    L10n.string("settings.shortcuts.next"),
                    name: .nextSpotifyTrack
                )
                shortcutRecorder(
                    L10n.string("settings.shortcuts.mute"),
                    name: .muteSpotify
                )
            } header: {
                Text(L10n.string("settings.shortcuts.global"))
            } footer: {
                Text(L10n.string("settings.shortcuts.explanation"))
            }

            Section {
                Button(L10n.string("settings.shortcuts.reset")) {
                    KeyboardShortcuts.reset(
                        .playPauseSpotify,
                        .previousSpotifyTrack,
                        .nextSpotifyTrack,
                        .muteSpotify
                    )
                }
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
    }

    private func shortcutRecorder(
        _ title: String,
        name: KeyboardShortcuts.Name
    ) -> some View {
        LabeledContent(title) {
            WideShortcutRecorder(name: name)
                .frame(width: 190)
        }
    }
}

private struct WideShortcutRecorder: NSViewRepresentable {
    let name: KeyboardShortcuts.Name

    func makeNSView(context: Context) -> KeyboardShortcuts.RecorderCocoa {
        let recorder = KeyboardShortcuts.RecorderCocoa(for: name)
        recorder.setContentHuggingPriority(.defaultLow, for: .horizontal)
        recorder.setContentCompressionResistancePriority(.required, for: .horizontal)
        return recorder
    }

    func updateNSView(
        _ recorder: KeyboardShortcuts.RecorderCocoa,
        context: Context
    ) {
        recorder.shortcutName = name
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: KeyboardShortcuts.RecorderCocoa,
        context: Context
    ) -> CGSize? {
        CGSize(width: 190, height: nsView.intrinsicContentSize.height)
    }
}

private struct PermissionSettingsView: View {
    let model: PlayerViewModel
    let permissionService: PermissionStatusService

    var body: some View {
        Form {
            Section {
                permissionRow(
                    title: L10n.string("settings.permissions.automation"),
                    detail: automationDetail,
                    status: model.automationPermissionStatus,
                    destination: .automation
                )
                permissionRow(
                    title: L10n.string("settings.permissions.notifications"),
                    detail: L10n.string("settings.permissions.notifications.detail"),
                    status: permissionService.notifications,
                    destination: .notifications
                )
                permissionRow(
                    title: L10n.string("settings.permissions.login_item"),
                    detail: L10n.string("settings.permissions.login_item.detail"),
                    status: model.launchAtLoginEnabled ? .allowed : .notDetermined,
                    destination: .loginItems
                )
            }

            Section {
                Button(L10n.string("settings.permissions.refresh")) {
                    model.refresh()
                    permissionService.refresh()
                }
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
        .onAppear {
            model.refresh()
            permissionService.refresh()
        }
    }

    private var automationDetail: String {
        model.snapshot.isRunning
            ? L10n.string("settings.permissions.automation.detail")
            : L10n.string("settings.permissions.automation.spotify_closed")
    }

    private func permissionRow(
        title: String,
        detail: String,
        status: PermissionStatus,
        destination: SystemSettingsDestination
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon(for: status))
                .foregroundStyle(color(for: status))
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(statusText(for: status))
                .font(.caption.weight(.medium))
                .foregroundStyle(color(for: status))

            Button(L10n.string("settings.permissions.open")) {
                SystemSettingsService.open(destination)
            }
        }
    }

    private func icon(for status: PermissionStatus) -> String {
        switch status {
        case .allowed: "checkmark.circle.fill"
        case .denied: "xmark.circle.fill"
        case .notDetermined: "minus.circle.fill"
        case .unknown: "questionmark.circle.fill"
        }
    }

    private func color(for status: PermissionStatus) -> Color {
        switch status {
        case .allowed: .green
        case .denied: .red
        case .notDetermined: .secondary
        case .unknown: .orange
        }
    }

    private func statusText(for status: PermissionStatus) -> String {
        switch status {
        case .allowed: L10n.string("settings.permissions.allowed")
        case .denied: L10n.string("settings.permissions.denied")
        case .notDetermined: L10n.string("settings.permissions.not_determined")
        case .unknown: L10n.string("settings.permissions.unknown")
        }
    }
}

private struct UpdateSettingsView: View {
    @Bindable var model: PlayerViewModel

    var body: some View {
        Form {
            Section {
                Toggle(
                    L10n.string("menu.automatic_update_checks"),
                    isOn: $model.automaticallyChecksForUpdates
                )
                Button(L10n.string("menu.check_for_updates")) {
                    model.checkForUpdates()
                }
            } footer: {
                Text(L10n.string("settings.updates.release_notes"))
            }

            Section(L10n.string("settings.updates.version")) {
                LabeledContent(
                    L10n.string("settings.updates.installed_version"),
                    value: L10n.format("menu.version", model.appVersion, model.appBuild)
                )
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
    }
}
