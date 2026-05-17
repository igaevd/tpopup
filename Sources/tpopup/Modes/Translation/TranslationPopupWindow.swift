import AppKit

/// Borderless popup window that can still become key so it receives keyboard input
/// (specifically: Escape to dismiss).
final class TranslationPopupWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
