import Combine
import Foundation

/// Persists settings to `UserDefaults` as JSON blobs: the list of configured models plus
/// one `ModeSettings` per mode.
///
/// The store is a thin observable wrapper so SwiftUI views can bind to it.
@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    /// In-memory settings. Typing in the Settings form mutates these directly through
    /// SwiftUI bindings but **does not** reach disk — call `save()` for that. This way
    /// the user can edit, decide they don't want the changes, close via the red X or
    /// ⌘Q, and the previously-saved version on disk is unaffected.
    @Published var models: [ModelProfile]
    @Published var translation: ModeSettings
    @Published var grammar: ModeSettings
    @Published var style: ModeSettings

    private enum Keys {
        static let models = "models"
        static let translation = "translation"
        static let grammar = "grammar"
        static let style = "style"
    }

    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // `ModeSettings` decodes the pre-1.4 blobs too: `modelProfileID` is optional, so
        // a blob without it yields nil and the prompt is kept.
        self.translation = Self.load(ModeSettings.self, forKey: Keys.translation, defaults: defaults)
            ?? ModeSettings.initial(promptResource: "translation-ai-prompt")
        self.grammar = Self.load(ModeSettings.self, forKey: Keys.grammar, defaults: defaults)
            ?? ModeSettings.initial(promptResource: "grammar-ai-prompt")
        self.style = Self.load(ModeSettings.self, forKey: Keys.style, defaults: defaults)
            ?? ModeSettings.initial(promptResource: "style-ai-prompt")

        if let saved = Self.load([ModelProfile].self, forKey: Keys.models, defaults: defaults) {
            self.models = saved
        } else {
            // First launch of a build with the Models tab: turn the per-mode OpenAI
            // key + model pairs (if any) into profiles so nothing stops working.
            self.models = []
            migrateLegacyCredentials()
            save()
        }
    }

    // MARK: - Models

    @discardableResult
    func addModel(from preset: ProviderPreset) -> ModelProfile {
        let profile = ModelProfile(preset: preset)
        models.append(profile)
        return profile
    }

    /// Removes a profile and clears any mode that pointed at it, so the mode tab shows
    /// "Choose a model…" instead of a dangling reference.
    func removeModel(id: UUID) {
        models.removeAll { $0.id == id }
        if translation.modelProfileID == id { translation.modelProfileID = nil }
        if grammar.modelProfileID == id { grammar.modelProfileID = nil }
        if style.modelProfileID == id { style.modelProfileID = nil }
    }

    // MARK: - Persistence

    /// Persists current in-memory settings to UserDefaults. Invoked by the OK button, by
    /// the Save button in the model editor, and once after a legacy migration. Closing the
    /// window any other way discards whatever was typed since the last successful save.
    func save() {
        persist(models, forKey: Keys.models)
        persist(translation, forKey: Keys.translation)
        persist(grammar, forKey: Keys.grammar)
        persist(style, forKey: Keys.style)
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

    // MARK: - Migration from per-mode OpenAI credentials (pre-1.4)

    private func migrateLegacyCredentials() {
        var created: [ModelProfile] = []

        func profileID(forLegacyKey key: String) -> UUID? {
            guard let legacy = Self.load(LegacyOpenAISettings.self, forKey: key, defaults: defaults) else {
                return nil
            }
            let apiKey = (legacy.apiKey ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let model = (legacy.model ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !apiKey.isEmpty, !model.isEmpty else { return nil }

            // Modes that shared one key + model collapse into a single profile.
            if let existing = created.first(where: { $0.apiKey == apiKey && $0.modelID == model }) {
                return existing.id
            }
            var profile = ModelProfile(preset: .openAI)
            profile.name = "OpenAI \(model)"
            profile.apiKey = apiKey
            profile.modelID = model
            created.append(profile)
            return profile.id
        }

        translation.modelProfileID = profileID(forLegacyKey: Keys.translation)
        grammar.modelProfileID = profileID(forLegacyKey: Keys.grammar)
        style.modelProfileID = profileID(forLegacyKey: Keys.style)
        models = created
    }
}
