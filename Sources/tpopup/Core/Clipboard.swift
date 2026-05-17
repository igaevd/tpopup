import AppKit
import Foundation

enum Clipboard {
    /// Returns trimmed clipboard text if and only if the pasteboard currently holds
    /// a non-empty string. Images and other non-text payloads return `nil`.
    static func readText() -> String? {
        let pasteboard = NSPasteboard.general
        guard pasteboard.canReadObject(forClasses: [NSString.self], options: nil),
              let raw = pasteboard.string(forType: .string) else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : raw
    }

    static func write(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
