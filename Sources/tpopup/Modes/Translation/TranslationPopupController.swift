import AppKit
import SwiftUI

/// Owns the translation popup window's lifecycle: pre-flight checks, window construction,
/// the OpenAI request, and dismissal (Esc / focus loss).
///
/// Sizing strategy (cursor-independent — popup always centers on the active screen):
///
/// 1. Pick a target width from a step function of source-text length (so short text gets
///    a narrow popup and long text gets a wide one, with `visibleFrame.width / 2` as the
///    hard cap).
/// 2. Measure each section's text height at that width.
/// 3. Natural total height = source section + divider + translation section, where
///    each section = text height + chrome (padding + spacing + button row).
/// 4. If natural fits in `visibleFrame.height / 2` → use it; no scrollbars.
/// 5. Else, try the same calculation at `maxW`; wider lines, shorter section.
/// 6. Else, clamp to `maxW × maxH`, split between the sections proportionally to their
///    natural heights; each section's internal `ScrollView` kicks in.
@MainActor
final class TranslationPopupController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let viewModel = TranslationViewModel()
    private let layoutModel = TranslationLayoutModel()
    private var keyMonitor: Any?
    private var translationTask: Task<Void, Never>?

    /// We launch into a brief activation race with whatever app the user was just in.
    /// Don't dismiss on focus loss until that race is over.
    private var armedForFocusLossDismiss = false

    /// Visible bounds of the screen the popup will live on. Captured once at run() so
    /// resizes after the translation arrives stay on the same screen.
    private var screenVisibleFrame: NSRect = .zero

    /// The popup's width, decided once at `run()` based on the source text plus a
    /// prediction that the translation will be roughly the same height. Locking the
    /// width means the source text wraps identically before and after the translation
    /// arrives — without this lock, the popup could widen mid-flight (preferred →
    /// max width fallback) and the user would see the source visibly re-render.
    private var lockedWidth: CGFloat = 600

    // MARK: - Layout constants (must agree with TranslationPopupView)

    private static let sectionChrome: CGFloat = 80          // padding + spacing + button row + slack
    private static let sectionMinHeight: CGFloat = 100      // enough for spinner + buttons
    private static let dividerHeight: CGFloat = 1
    private static let textHorizontalPadding: CGFloat = 36  // 18 each side
    private static let textFontSize: CGFloat = 17
    private static let measurementSafetyMargin: CGFloat = 8

    /// Maximum window size, as a fraction of the active screen's visible bounds in each
    /// direction. 80% means the popup can fill most of the screen before any scrollbar
    /// appears.
    private static let maxSizeFraction: CGFloat = 0.8

    // MARK: - Entry point

    func run() {
        debugLog("run() entered")

        // Pre-flight: settings filled in?
        let settings = SettingsStore.shared.translation
        if let missing = settings.missingFields {
            let info: String
            if missing.count >= 3 {
                info = "Open the app to fill in your translation settings."
            } else {
                info = "Open the app and set the \(joined(missing)) in the Translation tab."
            }
            ErrorPresenter.showAndQuit("Translation settings are incomplete.", info: info)
        }

        // Pre-flight: clipboard has text?
        guard let source = Clipboard.readText() else {
            ErrorPresenter.showAndQuit(
                "Nothing to translate.",
                info: "Copy some text first, then trigger the translation again."
            )
        }

        debugLog("pre-flight passed; source.length=\(source.count) model=\(settings.model)")

        // Pick the screen we'll center the popup on. Default to the main screen.
        let screen = NSScreen.main ?? NSScreen.screens.first!
        screenVisibleFrame = screen.visibleFrame

        // Seed the view model + initial layout so the popup opens already correctly
        // sized for the source text + spinner.
        viewModel.start(with: source)
        lockedWidth = chooseLockedWidth()
        let initialLayout = computeLayout()
        applyLayout(initialLayout, resizeWindow: false)
        showWindow(with: initialLayout.windowSize)

        // Fire the request.
        translationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await OpenAIClient().translate(text: source, settings: settings)
                self.debugLog("OpenAI request succeeded; chars=\(result.count)")
                self.viewModel.finish(translation: result)
            } catch {
                self.debugLog("OpenAI request failed: \(error.localizedDescription)")
                self.viewModel.fail(error.localizedDescription)
            }
            // Re-measure and grow/shrink the window for the new content. Width is
            // locked, so only the height (translation section) changes.
            let layout = self.computeLayout()
            self.debugLog("post-translation layout: \(Int(layout.windowSize.width))×\(Int(layout.windowSize.height))")
            self.applyLayout(layout, resizeWindow: true)
        }
    }

    // MARK: - Window setup

    private func showWindow(with contentSize: NSSize) {
        let rootView = TranslationPopupView(viewModel: viewModel, layout: layoutModel)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(origin: .zero, size: contentSize)

        let window = TranslationPopupWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isMovableByWindowBackground = false
        window.level = .floating
        window.collectionBehavior = [.ignoresCycle, .moveToActiveSpace]
        // Force dark appearance so system-driven colors inside the popup (notably
        // `selectedTextBackgroundColor`) use the muted dark-mode variant rather than
        // the harsh light-blue light-mode default leaking onto our dark background.
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = hostingView
        window.delegate = self

        self.window = window
        positionWindow(contentSize: contentSize)

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        debugLog("window shown frame=\(window.frame) key=\(window.isKeyWindow)")

        // Esc anywhere in our process dismisses the popup.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {       // kVK_Escape
                self?.debugLog("Esc pressed")
                self?.dismiss()
                return nil
            }
            return event
        }

        // Arm focus-loss dismissal after a short delay so the initial activation race
        // can't kill the popup before it's even visible.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            self?.armedForFocusLossDismiss = true
            self?.debugLog("focus-loss dismiss armed")
        }
    }

    /// Center the popup on the visible frame of the active screen.
    private func positionWindow(contentSize: NSSize) {
        guard let window else { return }

        let visible = screenVisibleFrame
        let x = visible.minX + (visible.width  - contentSize.width)  / 2
        let y = visible.minY + (visible.height - contentSize.height) / 2

        window.setFrame(
            NSRect(x: x, y: y, width: contentSize.width, height: contentSize.height),
            display: true,
            animate: false
        )
    }

    // MARK: - Layout

    private struct Layout {
        let windowSize: NSSize
        let sourceSectionHeight: CGFloat
        let translationSectionHeight: CGFloat
    }

    private func computeLayout() -> Layout {
        let maxH = floor(screenVisibleFrame.height * Self.maxSizeFraction)

        if let layout = tryLayout(width: lockedWidth, maxH: maxH) {
            return layout
        }
        // Doesn't fit at the locked width — clamp the height and let ScrollViews engage.
        // We never widen the popup at this point because that would re-wrap the source
        // text and look like the font size changed.
        return clampedLayout(width: lockedWidth, maxH: maxH)
    }

    /// One-time width decision made before the popup is shown.
    ///
    /// Tries the preferred (content-sized) width first, predicting that the translation
    /// will have roughly the same height as the source. If that prediction wouldn't fit
    /// in `maxH`, locks the popup at `maxW` so the translation has room to land without
    /// the popup needing to re-flow.
    private func chooseLockedWidth() -> CGFloat {
        let maxW = floor(screenVisibleFrame.width  * Self.maxSizeFraction)
        let maxH = floor(screenVisibleFrame.height * Self.maxSizeFraction)
        let preferredW = preferredWidth(maxW: maxW)

        let textWidth = preferredW - Self.textHorizontalPadding
        let sourceTextH = measureTextHeight(viewModel.sourceText, width: textWidth)
        let sourceH = max(sourceTextH + Self.sectionChrome, Self.sectionMinHeight)
        // Predict: translation height ≈ source height.
        let predictedTransH = max(sourceTextH + Self.sectionChrome, Self.sectionMinHeight)
        let predictedTotal = sourceH + Self.dividerHeight + predictedTransH

        return predictedTotal <= maxH ? preferredW : maxW
    }

    /// Step function of source-text length. Source-only (not source + translation)
    /// because translation is unknown at the first render and we don't want the popup
    /// width to jump when it arrives.
    private func preferredWidth(maxW: CGFloat) -> CGFloat {
        let count = viewModel.sourceText.count
        let base: CGFloat
        switch count {
        case 0...30:    base = 420
        case 31...80:   base = 500
        case 81...200:  base = 600
        case 201...500: base = 700
        default:        base = 800
        }
        return min(base, maxW)
    }

    /// Returns a layout that fits within `maxH` at the given width, or nil if it can't.
    private func tryLayout(width: CGFloat, maxH: CGFloat) -> Layout? {
        let textWidth = width - Self.textHorizontalPadding

        let sourceTextH      = measureTextHeight(viewModel.sourceText, width: textWidth)
        let translationTextH = currentTranslationTextHeight(textWidth: textWidth)

        let sourceH      = max(sourceTextH      + Self.sectionChrome, Self.sectionMinHeight)
        let translationH = max(translationTextH + Self.sectionChrome, Self.sectionMinHeight)
        let total        = sourceH + Self.dividerHeight + translationH

        guard total <= maxH else { return nil }

        return Layout(
            windowSize: NSSize(width: width, height: total),
            sourceSectionHeight: sourceH,
            translationSectionHeight: translationH
        )
    }

    /// Layout when even `maxW × maxH` isn't enough. Each section's `ScrollView` will
    /// engage; the heights are split proportionally to natural heights with a floor.
    private func clampedLayout(width: CGFloat, maxH: CGFloat) -> Layout {
        let textWidth = width - Self.textHorizontalPadding

        let sourceTextH      = measureTextHeight(viewModel.sourceText, width: textWidth)
        let translationTextH = currentTranslationTextHeight(textWidth: textWidth)

        let sourceNatural      = max(sourceTextH      + Self.sectionChrome, Self.sectionMinHeight)
        let translationNatural = max(translationTextH + Self.sectionChrome, Self.sectionMinHeight)
        let totalNatural       = sourceNatural + translationNatural

        let totalForSections = maxH - Self.dividerHeight
        var sourceH      = (totalForSections * sourceNatural / totalNatural).rounded()
        var translationH = totalForSections - sourceH

        if sourceH < Self.sectionMinHeight {
            sourceH      = Self.sectionMinHeight
            translationH = max(totalForSections - sourceH, Self.sectionMinHeight)
        }
        if translationH < Self.sectionMinHeight {
            translationH = Self.sectionMinHeight
            sourceH      = max(totalForSections - translationH, Self.sectionMinHeight)
        }

        return Layout(
            windowSize: NSSize(width: width, height: sourceH + Self.dividerHeight + translationH),
            sourceSectionHeight: sourceH,
            translationSectionHeight: translationH
        )
    }

    private func currentTranslationTextHeight(textWidth: CGFloat) -> CGFloat {
        if viewModel.isLoading { return 22 }      // spinner row
        if let err = viewModel.errorMessage { return measureTextHeight(err, width: textWidth) }
        return measureTextHeight(viewModel.translation, width: textWidth)
    }

    private func applyLayout(_ layout: Layout, resizeWindow: Bool) {
        layoutModel.popupWidth              = layout.windowSize.width
        layoutModel.sourceSectionHeight     = layout.sourceSectionHeight
        layoutModel.translationSectionHeight = layout.translationSectionHeight

        if resizeWindow {
            positionWindow(contentSize: layout.windowSize)
        }
    }

    private func measureTextHeight(_ text: String, width: CGFloat) -> CGFloat {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }

        // Must match the SwiftUI Text font in `TranslationPopupView` (SF Mono via
        // `.system(size: 17, design: .monospaced)`), otherwise our height estimate
        // diverges from the actual rendering and small content trips a scrollbar.
        let font = NSFont.monospacedSystemFont(ofSize: Self.textFontSize, weight: .regular)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let bounds = (trimmed as NSString).boundingRect(
            with: NSSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        )
        // SwiftUI's actual measurement runs slightly larger than this; add a buffer so
        // small text never triggers a "barely overflowing" scrollbar.
        return ceil(bounds.height) + Self.measurementSafetyMargin
    }

    // MARK: - Dismissal

    func dismiss() {
        debugLog("dismiss() called")
        translationTask?.cancel()
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        window?.orderOut(nil)
        window = nil
        NSApp.terminate(nil)
    }

    // MARK: - NSWindowDelegate

    func windowDidBecomeKey(_ notification: Notification) {
        debugLog("windowDidBecomeKey")
    }

    func windowDidResignKey(_ notification: Notification) {
        debugLog("windowDidResignKey (armed=\(armedForFocusLossDismiss))")
        guard armedForFocusLossDismiss else { return }
        dismiss()
    }

    // MARK: - Debug

    /// Honors the `TPOPUP_DEBUG` env var so we can flip it on for diagnostics without
    /// shipping noise in release.
    private func debugLog(_ message: @autoclosure () -> String) {
        guard ProcessInfo.processInfo.environment["TPOPUP_DEBUG"] != nil else { return }
        NSLog("[tpopup] %@", message())
    }

    // MARK: - Helpers

    private func joined(_ items: [String]) -> String {
        switch items.count {
        case 0:  return ""
        case 1:  return items[0]
        case 2:  return "\(items[0]) and \(items[1])"
        default:
            let head = items.dropLast().joined(separator: ", ")
            return "\(head), and \(items.last!)"
        }
    }
}
