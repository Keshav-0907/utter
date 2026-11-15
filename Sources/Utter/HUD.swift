import AppKit
import SwiftUI

@MainActor
final class HUDModel: ObservableObject {
    enum Phase: Equatable {
        case hidden, listening, processing
        case message(String)
    }

    static let barCount = 7

    @Published var phase: Phase = .hidden
    @Published var levels = [CGFloat](repeating: 0, count: HUDModel.barCount)
    @Published var text = ""
    @Published var showText = false
    @Published var locked = false
}

private struct HUDView: View {
    @ObservedObject var model: HUDModel

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear
            if model.phase != .hidden {
                pill.transition(.scale(scale: 0.7, anchor: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.22), value: model.phase)
        .animation(.easeOut(duration: 0.15), value: model.text.isEmpty)
        .animation(.spring(duration: 0.2), value: model.locked)
    }

    private var pill: some View {
        HStack(spacing: 8) {
            switch model.phase {
            case .listening:
                if model.locked {
                    Image(systemName: "lock.fill").font(.system(size: 9, weight: .bold)).foregroundStyle(.white.opacity(0.75))
                }
                bars
                if model.showText, !model.text.isEmpty {
                    Text(model.text)
                        .lineLimit(1)
                        .truncationMode(.head)
                        .frame(maxWidth: 280, alignment: .trailing)
                }
            case .processing:
                ProgressView()
                    .controlSize(.small)
                    .colorScheme(.dark)
            case .message(let message):
                Text(message).lineLimit(1)
            case .hidden:
                EmptyView()
            }
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .frame(minWidth: 56, minHeight: 26, maxHeight: 26)
        .background(Capsule().fill(Color.black.opacity(0.85)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5))
        .padding(.bottom, 2)
    }

    private var bars: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<HUDModel.barCount, id: \.self) { index in
                Capsule()
                    .fill(Color.white)
                    .frame(width: 2.5, height: 3 + model.levels[index] * 13)
            }
        }
        .frame(height: 16)
        .animation(.linear(duration: 0.08), value: model.levels)
    }
}

/// A small pill at the bottom centre of the screen: level bars while listening,
/// a spinner while finishing. Never takes focus or mouse events.
@MainActor
final class HUD {
    private let panel: NSPanel
    private let model = HUDModel()
    private let size = NSSize(width: 420, height: 40)
    private var generation = 0

    init() {
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        // Panels hide themselves when their app is not frontmost; this one must show over other apps.
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        let host = NSHostingView(rootView: HUDView(model: model))
        host.frame = NSRect(origin: .zero, size: size)
        panel.contentView = host
    }

    func listening() {
        model.text = ""
        model.levels = [CGFloat](repeating: 0, count: HUDModel.barCount)
        model.showText = Settings.showLiveText
        model.locked = false
        present(.listening)
    }

    func locked(_ value: Bool) {
        model.locked = value
    }

    func level(_ value: CGFloat) {
        guard model.phase == .listening else { return }
        model.levels.removeFirst()
        model.levels.append(value)
    }

    func partial(_ text: String) {
        model.text = text
    }

    func processing() {
        present(.processing)
    }

    func message(_ text: String, for duration: TimeInterval = 1.6) {
        present(.message(text))
        let current = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self, self.generation == current else { return }
            self.hide()
        }
    }

    func hide() {
        generation += 1
        let current = generation
        model.phase = .hidden
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self, self.generation == current else { return }
            self.panel.orderOut(nil)
        }
    }

    private func present(_ phase: HUDModel.Phase) {
        generation += 1
        if model.phase == .hidden {
            let mouse = NSEvent.mouseLocation
            let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
            if let frame = screen?.visibleFrame {
                panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: frame.minY + 10))
            }
        }
        panel.orderFrontRegardless()
        model.phase = phase
    }
}
