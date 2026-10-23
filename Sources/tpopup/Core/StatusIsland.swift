import AppKit
import SwiftUI

/// The "island" progress indicator for the Grammar and Style modes: a small black pill
/// hanging from the top edge of the screen, centred, holding three fading dots and one
/// word. It lives above the menu bar, ignores the mouse, and slides in and out.
///
/// On a MacBook with a notch nothing can be drawn inside the notch, so there the pill
/// widens to the notch and puts its content in a band beneath it. On every other display
/// it is exactly as big as its content.
struct StatusIslandView: View {
    let label: String
    /// Height of the physical notch (0 when there is none).
    var notchHeight: CGFloat = 0
    /// Width the pill must at least cover (the notch), 0 when there is none.
    var minWidth: CGFloat = 0

    static let bandHeight: CGFloat = 30
    static let cornerRadius: CGFloat = 12

    var body: some View {
        VStack(spacing: 0) {
            if notchHeight > 0 {
                Color.clear.frame(height: notchHeight)
            }
            HStack(spacing: 7) {
                FadingDots()
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.95))
                    .lineLimit(1)
                    .fixedSize()
            }
            .frame(height: Self.bandHeight)
        }
        .padding(.horizontal, 14)
        .frame(minWidth: minWidth)
        .background(
            UnevenRoundedRectangle(
                cornerRadii: .init(bottomLeading: Self.cornerRadius, bottomTrailing: Self.cornerRadius),
                style: .continuous
            )
            .fill(Color.black)
        )
    }
}

/// Three 4 pt dots that light up in sequence (no movement).
private struct FadingDots: View {
    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.white)
                        .frame(width: 4, height: 4)
                        .opacity(Self.opacity(at: t, index: index))
                }
            }
        }
        .accessibilityHidden(true)
    }

    /// 1.2 s cycle, each dot 0.15 s behind the previous; sine pulse from 0.2 to 1.0.
    private static func opacity(at time: TimeInterval, index: Int) -> Double {
        let phase = (time / 1.2 - Double(index) * 0.15).truncatingRemainder(dividingBy: 1)
        let pulse = max(0, sin(phase * .pi))
        return 0.2 + 0.8 * pulse
    }
}

/// Owns the island's borderless window: creation, placement over the menu bar on the
/// screen under the mouse, and the slide-in / slide-out animation.
@MainActor
final class StatusIslandWindow {
    private var window: NSWindow?
    private let model = Model()

    private final class Model: ObservableObject {
        @Published var shown = false
    }

    /// Wraps the island so the slide animation is driven by SwiftUI state.
    private struct Root: View {
        @ObservedObject var model: Model
        let island: StatusIslandView
        let height: CGFloat

        var body: some View {
            island
                .offset(y: model.shown ? 0 : -height)
                .animation(.spring(response: 0.35, dampingFraction: 0.82), value: model.shown)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    func show(label: String) {
        let screen = Self.screenUnderMouse()
        let notchHeight = screen.safeAreaInsets.top
        let notchWidth = Self.notchWidth(of: screen)

        let island = StatusIslandView(label: label, notchHeight: notchHeight, minWidth: notchWidth)
        let size = NSHostingView(rootView: island).fittingSize
        let hosting = NSHostingView(rootView: Root(model: model, island: island, height: size.height))
        hosting.frame = NSRect(origin: .zero, size: size)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isMovableByWindowBackground = false
        // Above the menu bar, on every Space, and not something ⌘-Tab or Mission Control
        // should know about.
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = hosting

        // Hanging from the very top of the screen (the full frame, menu bar included).
        let frame = screen.frame
        window.setFrameOrigin(NSPoint(
            x: frame.minX + (frame.width - size.width) / 2,
            y: frame.maxY - size.height
        ))

        // `orderFrontRegardless` — never `makeKey` — so focus stays in the user's editor.
        window.orderFrontRegardless()
        self.window = window

        // Start hidden above the edge, then slide in on the next run-loop turn.
        DispatchQueue.main.async { [model] in
            model.shown = true
        }
    }

    /// Slides out, then removes the window. `completion` runs once it is gone.
    func hide(completion: (() -> Void)? = nil) {
        guard let window else { completion?(); return }
        model.shown = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            window.orderOut(nil)
            if self?.window === window { self?.window = nil }
            completion?()
        }
    }

    // MARK: - Screen geometry

    private static func screenUnderMouse() -> NSScreen {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }

    /// Width of the notch, or 0 when the screen has none. The areas either side of the
    /// notch are what macOS exposes; the notch is what is left between them.
    private static func notchWidth(of screen: NSScreen) -> CGFloat {
        guard screen.safeAreaInsets.top > 0,
              let left = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea else { return 0 }
        let width = screen.frame.width - left.width - right.width
        return max(0, width)
    }
}
