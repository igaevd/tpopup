import AppKit

/// Single entry point for fatal, "stop everything and tell the user" failures during
/// a mode launch. Uses a standard `NSAlert` (centered, modal) and terminates the app
/// when dismissed.
///
/// Crucially: we do *not* switch back to `.regular` here. In translate mode the app
/// must stay an accessory (no Dock icon, even when reporting an error). To make the
/// alert appear above whatever the user was working in, we pin its window to a
/// floating level before showing it.
enum ErrorPresenter {
    @MainActor
    static func showAndQuit(_ message: String, info: String? = nil) -> Never {
        // Activate the (accessory) process so the alert can receive input.
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = message
        if let info, !info.isEmpty {
            alert.informativeText = info
        }
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")

        // Ensure the alert renders above the editor / browser the user was in.
        // `alert.window` is created lazily; touching it now forces construction so
        // the level setting actually takes effect.
        let window = alert.window
        window.level = .floating
        window.collectionBehavior.insert(.moveToActiveSpace)

        alert.runModal()

        NSApp.terminate(nil)
        exit(0)
    }
}
