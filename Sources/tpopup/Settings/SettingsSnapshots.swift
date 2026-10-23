#if DEBUG
import AppKit
import SwiftUI

/// Renders each Settings tab into a PNG, in-process (no screen capture involved).
/// Debug builds only; triggered by the `TPOPUP_SNAPSHOT_DIR` environment variable.
@MainActor
enum SettingsSnapshots {
    static func write(toDirectory dir: String) async {
        let tabs = ModeRegistry.all.map(\.flag) + [SettingsRootView.modelsTabID]
        let size = SettingsRootView.contentSize

        // Every tab gets its own window so List/TextEditor (AppKit-backed) lay out for real.
        var windows: [(String, NSWindow)] = []
        var statuses: [(String, StatusCenter)] = []
        for tab in tabs {
            let status = StatusCenter()
            statuses.append((tab, status))
            let root = SettingsRootView(initialTab: tab, onConfirm: {})
                .environmentObject(SettingsStore.shared)
                .environmentObject(status)
            let hosting = NSHostingView(rootView: root)
            hosting.frame = NSRect(origin: .zero, size: size)
            hosting.appearance = NSAppearance(named: .darkAqua)
            hosting.wantsLayer = true
            let window = NSWindow(contentRect: NSRect(origin: NSPoint(x: -4000, y: -4000), size: size),
                                  styleMask: [.titled], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: .darkAqua)
            window.contentView = hosting
            window.orderFrontRegardless()
            windows.append((tab, window))
        }

        // Give SwiftUI (and any in-flight fetch) time to settle before drawing. Awaiting,
        // rather than spinning a nested run loop, lets other main-actor work run.
        func settle(_ seconds: TimeInterval) async {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        }
        await settle(1.5)

        // The Models tab snapshot shows a sample failure so the footer can be checked.
        // Set after the editor has appeared (its appearance clears stale status, as it
        // does when the user switches profiles).
        for (tab, status) in statuses where tab == SettingsRootView.modelsTabID {
            status.message = .init(kind: .success, text: "gpt-6.1-sol replied “pong” in 0.8 s")
        }
        await settle(0.5)

        // Also render the Browse popover for the first profile, standalone, so its layout
        // (and a live fetch against whatever endpoint it has) can be checked.
        if let first = SettingsStore.shared.models.first {
            let popover = ModelBrowserPopover(profile: first, currentModelID: first.modelID) { _ in }
            let hosting = NSHostingView(rootView: popover)
            hosting.frame = NSRect(x: 0, y: 0, width: 340, height: 380)
            hosting.appearance = NSAppearance(named: .darkAqua)
            hosting.wantsLayer = true
            let window = NSWindow(contentRect: NSRect(x: -4000, y: -4000, width: 340, height: 380),
                                  styleMask: [.titled], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: .darkAqua)
            window.contentView = hosting
            window.orderFrontRegardless()
            windows.append(("browser", window))
            await settle(3.0)
        }

        // And the translation popup with sample content, as the user sees it after a
        // translation lands (editable source, retranslate button, no caret).
        do {
            let viewModel = TranslationViewModel()
            viewModel.start(with: "press")
            viewModel.finish(translation: "Пресса")
            let layout = TranslationLayoutModel()
            layout.popupWidth = 420
            layout.sourceSectionHeight = 110
            layout.translationSectionHeight = 110
            let popup = TranslationPopupView(viewModel: viewModel, layout: layout, onRetranslate: {}, onSwap: {})
            let hosting = NSHostingView(rootView: popup)
            hosting.frame = NSRect(x: 0, y: 0, width: 420, height: 221)
            hosting.appearance = NSAppearance(named: .darkAqua)
            hosting.wantsLayer = true
            let window = NSWindow(contentRect: NSRect(x: -4000, y: -4000, width: 420, height: 221),
                                  styleMask: [.borderless], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: .darkAqua)
            window.contentView = hosting
            window.orderFrontRegardless()
            windows.append(("popup", window))
            await settle(1.0)
        }

        // The grammar/style island, with and without a notch.
        for (name, notch) in [("island", CGFloat(0)), ("island-notch", CGFloat(32))] {
            let island = StatusIslandView(label: "correcting", notchHeight: notch, minWidth: notch > 0 ? 200 : 0)
            let size = NSHostingView(rootView: island).fittingSize
            let padded = NSSize(width: size.width + 80, height: size.height + 30)
            let hosting = NSHostingView(rootView:
                island.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .background(Color(white: 0.16)))
            hosting.frame = NSRect(origin: .zero, size: padded)
            hosting.appearance = NSAppearance(named: .darkAqua)
            hosting.wantsLayer = true
            let window = NSWindow(contentRect: NSRect(origin: NSPoint(x: -4000, y: -4000), size: padded),
                                  styleMask: [.borderless], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: .darkAqua)
            window.contentView = hosting
            window.orderFrontRegardless()
            windows.append((name, window))
        }
        await settle(0.5)

        for (tab, window) in windows {
            guard let view = window.contentView else { continue }
            view.layoutSubtreeIfNeeded()
            guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
            NSAppearance(named: .darkAqua)?.performAsCurrentDrawingAppearance {
                // cacheDisplay skips the window background; paint it first so secondary
                // text (light gray in dark mode) is visible in the PNG.
                NSGraphicsContext.saveGraphicsState()
                if let context = NSGraphicsContext(bitmapImageRep: rep) {
                    NSGraphicsContext.current = context
                    NSColor.windowBackgroundColor.setFill()
                    view.bounds.fill()
                    context.flushGraphics()
                }
                NSGraphicsContext.restoreGraphicsState()
                view.cacheDisplay(in: view.bounds, to: rep)
            }
            guard let png = rep.representation(using: .png, properties: [:]) else { continue }
            let url = URL(fileURLWithPath: dir).appendingPathComponent("settings-\(tab).png")
            try? png.write(to: url)
            NSLog("[tpopup] snapshot written: %@", url.path)
        }
    }
}
#endif
