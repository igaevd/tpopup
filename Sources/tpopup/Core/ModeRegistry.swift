import Foundation

/// Central registry of all app modes.
///
/// Adding a new mode is a single-line change here plus a new `AppMode` definition
/// somewhere in the `Modes/` directory.
enum ModeRegistry {
    static let all: [AppMode] = [
        TranslationMode.appMode,
        GrammarMode.appMode,
        StyleMode.appMode
    ]

    static func mode(forFlag flag: String) -> AppMode? {
        all.first { $0.flag == flag }
    }
}
