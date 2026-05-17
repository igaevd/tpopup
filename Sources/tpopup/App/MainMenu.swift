import AppKit

/// Installs a standard macOS main menu — App, Edit, Window.
///
/// Without this menu, SwiftUI text fields silently drop the standard editing shortcuts
/// (⌘A, ⌘C, ⌘V, ⌘X, ⌘Z, ⇧⌘Z) because AppKit routes those keystrokes through
/// `NSApp.mainMenu`, not directly to the focused view.
@MainActor
enum MainMenu {
    static func install() {
        let appName = "tpopup"
        let mainMenu = NSMenu()

        // MARK: App menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        // Routes to AppDelegate.showAboutPanel(_:) — the custom handler suppresses the
        // build number "(1)" suffix that the system's default about panel would show.
        appMenu.addItem(withTitle: "About \(appName)",
                        action: #selector(AppDelegate.showAboutPanel(_:)),
                        keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Hide \(appName)",
                        action: #selector(NSApplication.hide(_:)),
                        keyEquivalent: "h")
        let hideOthers = appMenu.addItem(withTitle: "Hide Others",
                                         action: #selector(NSApplication.hideOtherApplications(_:)),
                                         keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "Show All",
                        action: #selector(NSApplication.unhideAllApplications(_:)),
                        keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit \(appName)",
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")
        appMenuItem.submenu = appMenu

        // MARK: Edit menu — the whole reason this file exists.
        // Targets are nil so each action travels up the responder chain and lands on
        // whichever text view (NSTextField / NSTextView) is the first responder.
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)

        let editMenu = NSMenu(title: "Edit")
        // Undo/Redo: no Swift-visible class exposes these as `@objc` selectors — they
        // are synthesized by the responder chain on top of NSUndoManager — so we
        // construct the Selector explicitly. (Xcode doesn't flag this case.)
        editMenu.addItem(withTitle: "Undo",
                         action: Selector(("undo:")),
                         keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "Redo",
                                    action: Selector(("redo:")),
                                    keyEquivalent: "Z")
        redo.keyEquivalentModifierMask = [.shift, .command]
        editMenu.addItem(NSMenuItem.separator())
        // cut/copy/paste/delete/selectAll are declared on NSText (inherited by
        // NSTextField and NSTextView), so `#selector` resolves cleanly. The dispatched
        // selector — e.g. `cut:` — is what the focused text view's responder handles.
        editMenu.addItem(withTitle: "Cut",
                         action: #selector(NSText.cut(_:)),
                         keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy",
                         action: #selector(NSText.copy(_:)),
                         keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste",
                         action: #selector(NSText.paste(_:)),
                         keyEquivalent: "v")
        editMenu.addItem(withTitle: "Delete",
                         action: #selector(NSText.delete(_:)),
                         keyEquivalent: "")
        editMenu.addItem(withTitle: "Select All",
                         action: #selector(NSText.selectAll(_:)),
                         keyEquivalent: "a")
        editMenuItem.submenu = editMenu

        // MARK: Window menu
        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)

        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize",
                           action: #selector(NSWindow.performMiniaturize(_:)),
                           keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Close",
                           action: #selector(NSWindow.performClose(_:)),
                           keyEquivalent: "w")
        windowMenuItem.submenu = windowMenu

        NSApp.mainMenu = mainMenu
        NSApp.windowsMenu = windowMenu
    }
}
