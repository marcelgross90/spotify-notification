import AppKit
import Foundation
import SwiftUI

@MainActor
protocol TrackNotifying {
    func notify(track: SpotifyTrack) async
}

@MainActor
final class NowPlayingOverlayController: TrackNotifying {
    private let panelSize = NSSize(width: 360, height: 96)
    private var panel: NSPanel?
    private var dismissTask: Task<Void, Never>?

    func notify(track: SpotifyTrack) async {
        let artwork = await loadArtwork(from: track.artworkURL)
        show(track: track, artwork: artwork)
    }

    private func loadArtwork(from url: URL?) async -> NSImage? {
        guard let url else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return NSImage(data: data)
        } catch {
            return nil
        }
    }

    private func show(track: SpotifyTrack, artwork: NSImage?) {
        dismissTask?.cancel()

        let panel = makePanelIfNeeded()
        panel.contentView = NSHostingView(
            rootView: NowPlayingOverlayView(track: track, artwork: artwork)
        )

        let finalFrame = frameForOverlay()
        let startFrame = finalFrame.offsetBy(dx: 24, dy: 0)
        panel.setFrame(startFrame, display: true)
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.28
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(finalFrame, display: true)
        }

        dismissTask = Task { [weak self, weak panel] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled, let panel else { return }

            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().alphaValue = 0
                panel.animator().setFrame(
                    finalFrame.offsetBy(dx: 16, dy: 0),
                    display: true
                )
            }, completionHandler: {
                Task { @MainActor in
                    panel.orderOut(nil)
                    self?.dismissTask = nil
                }
            })
        }
    }

    private func makePanelIfNeeded() -> NSPanel {
        if let panel { return panel }

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary
        ]
        panel.isReleasedWhenClosed = false

        self.panel = panel
        return panel
    }

    private func frameForOverlay() -> NSRect {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
        let visibleFrame = screen.visibleFrame

        return NSRect(
            x: visibleFrame.maxX - panelSize.width - 18,
            y: visibleFrame.maxY - panelSize.height - 18,
            width: panelSize.width,
            height: panelSize.height
        )
    }
}

private struct NowPlayingOverlayView: View {
    let track: SpotifyTrack
    let artwork: NSImage?

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(track.name)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(track.artist)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(track.album)
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            artworkView
        }
        .padding(12)
        .frame(width: 360, height: 96)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var artworkView: some View {
        if let artwork {
            Image(nsImage: artwork)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.secondary.opacity(0.14))
                .frame(width: 72, height: 72)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
        }
    }
}
