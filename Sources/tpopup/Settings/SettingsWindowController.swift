import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var keyMonitor: Any?

    func show() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let root = SettingsRootView { [weak self] in
            self?.confirm()
        }
        .environmentObject(SettingsStore.shared)

        let contentSize = NSSize(width: 560, height: 460)

        let hosting = NSHostingController(rootView: root)
        // Lock the size up front so the window can be built and positioned in one shot,
        // before SwiftUI's first layout pass causes any resize/jump.
        hosting.preferredContentSize = contentSize

        let window = NSWindow(contentViewController: hosting)
        window.title = Self.windowTitle()
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        // Lock the window to dark mode regardless of the system theme so it matches
        // the translation popup.
        window.appearance = NSAppearance(named: .darkAqua)

        // Belt-and-suspenders: even with preferredContentSize, force the content size to
        // match before computing the centered origin.
        window.setContentSize(contentSize)

        // Compute the origin ourselves. `window.center()` has been unreliable here —
        // the frame size sometimes isn't finalized when it runs, so the window snaps to
        // the upper-right of the screen.
        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            let frame = window.frame   // includes title bar
            let origin = NSPoint(
                x: visible.minX + (visible.width - frame.width) / 2,
                y: visible.minY + (visible.height - frame.height) / 2
            )
            window.setFrameOrigin(origin)
        }

        self.window = window

        // Esc closes the window without saving — same outcome as the red X.
        // `performClose` triggers `windowWillClose`, which terminates the app; saving
        // only happens inside `confirm()` so typed-but-uncommitted edits are discarded.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {       // kVK_Escape
                self?.window?.performClose(nil)
                return nil
            }
            return event
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Builds the settings window title from the bundle version. Reads
    /// `CFBundleShortVersionString` from `Info.plist` so the title automatically tracks
    /// the version bump made there (and the DMG name made by `pack.sh`).
    /// Falls back to the bare app name when the version key is missing — that only
    /// happens when running the dev binary out of `.build/`, not from a real bundle.
    private static func windowTitle() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return version.map { "tpopup v\($0)" } ?? "tpopup"
    }

    private func confirm() {
        // OK is the ONE path that commits typed changes to disk.
        SettingsStore.shared.save()
        window?.performClose(nil)
    }

    // MARK: - NSWindowDelegate

    /// Closing the window — by OK, the red traffic-light, or ⌘Q — terminates the app.
    /// We intentionally do *not* save here: persistence only happens inside `confirm()`
    /// so that exiting via the red X or ⌘Q discards whatever was typed.
    func windowWillClose(_ notification: Notification) {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        NSApp.terminate(nil)
    }
}
