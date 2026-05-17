import Combine
import Foundation

/// Persists per-mode settings to `UserDefaults` as JSON blobs.
///
/// Each mode keeps its own typed `Codable` settings struct; the store is just a thin
/// observable wrapper so SwiftUI views can bind to them.
@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    /// In-memory settings. Typing in the Settings form mutates this directly through
    /// SwiftUI bindings but **does not** reach disk — call `save()` for that. This way
    /// the user can edit, decide they don't want the changes, close via the red X or
    /// ⌘Q, and the previously-saved version on disk is unaffected.
    @Published var translation: TranslationSettings
    @Published var grammar: GrammarSettings

    private enum Keys {
        static let translation = "translation"
        static let grammar = "grammar"
    }

    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.translation = Self.load(TranslationSettings.self,
                                     forKey: Keys.translation,
                                     defaults: defaults)
            ?? TranslationSettings.default
        self.grammar = Self.load(GrammarSettings.self,
                                 forKey: Keys.grammar,
                                 defaults: defaults)
            ?? GrammarSettings.default
    }

    /// Persists current in-memory settings to UserDefaults. Only invoked when the user
    /// explicitly confirms (OK button). Closing the window any other way discards
    /// whatever was typed since the last successful save.
    func save() {
        persist(translation, forKey: Keys.translation)
        persist(grammar, forKey: Keys.grammar)
        defaults.synchronize()
    }

    private func persist<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private static func load<T: Decodable>(_ type: T.Type,
                                           forKey key: String,
                                           defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
