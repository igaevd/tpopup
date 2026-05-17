import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?

    private let launchMode: LaunchMode
    private var settingsController: SettingsWindowController?
    private var retained: [AnyObject] = []

    enum LaunchMode {
        case settings
        case run(AppMode)
    }

    init(launchMode: LaunchMode) {
        self.launchMode = launchMode
        super.init()
        AppDelegate.shared = self
    }

    /// Keeps mode controllers (popup windows etc.) alive for as long as the app runs.
    func retain(_ object: AnyObject) {
        retained.append(object)
    }

    // MARK: - NSApplicationDelegate

    func applicationWillFinishLaunching(_ notification: Notification) {
        switch launchMode {
        case .settings:
            NSApp.setActivationPolicy(.regular)
        case .run:
            // No dock icon for transient mode runs (translate popup etc.).
            NSApp.setActivationPolicy(.accessory)
        }

        // Force the entire app to dark mode regardless of the system theme. Setting
        // appearance at the application level reaches every window — including
        // system-provided ones like the standard About panel and NSAlert — which
        // per-window `appearance` assignments cannot.
        NSApp.appearance = NSAppearance(named: .darkAqua)

        // The Edit menu has to exist for ⌘A/⌘C/⌘V/⌘X/⌘Z to reach text views, and the
        // App menu carries ⌘Q. Installed in both modes — the menu bar stays hidden in
        // accessory mode, but key equivalents still dispatch through it.
        MainMenu.install()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        switch launchMode {
        case .settings:
            let controller = SettingsWindowController()
            settingsController = controller
            controller.show()
        case .run(let mode):
            mode.run()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Settings mode: red-X closes the window → terminate.
        // Translate mode: popup closes itself by calling NSApp.terminate directly.
        true
    }

    // MARK: - About panel

    /// Replaces the default "Version 1.0 (1)" display with just "Version 1.0".
    ///
    /// `AboutPanelOptionKey.version` corresponds to `CFBundleVersion` (the build number
    /// the system shows in parentheses). Passing an empty string suppresses both the
    /// number and the surrounding parens.
    @objc func showAboutPanel(_ sender: Any?) {
        NSApp.orderFrontStandardAboutPanel(options: [
            NSApplication.AboutPanelOptionKey.version: ""
        ])
    }
}
