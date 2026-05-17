import AppKit
import SwiftUI

/// Borderless, transparent floating window that hosts the grammar-correction status pill.
///
/// Crucially, it never becomes key — `orderFrontRegardless` shows the window without
/// stealing focus from the editor the user just triggered the correction in. That way the
/// editor's text selection is preserved, so the synthesized ⌘V at the end actually
/// replaces the selection instead of landing in some unrelated control.
@MainActor
final class GrammarStatusWindow {
    private var window: NSWindow?

    func show(onScreen screen: NSScreen) {
        let hosting = NSHostingView(rootView: GrammarStatusView())
        let size = GrammarStatusView.size
        hosting.frame = NSRect(origin: .zero, size: size)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle, .stationary]
        window.ignoresMouseEvents = true
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = hosting

        // Center on the active screen's visible frame.
        let vf = screen.visibleFrame
        let origin = NSPoint(
            x: vf.minX + (vf.width - size.width) / 2,
            y: vf.minY + (vf.height - size.height) / 2
        )
        window.setFrameOrigin(origin)

        // `orderFrontRegardless` — not `makeKeyAndOrderFront` — so we don't activate the
        // app or grab focus from whatever editor the user is in.
        window.orderFrontRegardless()
        self.window = window
    }

    func hide() {
        window?.orderOut(nil)
        window = nil
    }
}
