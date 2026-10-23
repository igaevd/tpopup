import Foundation

/// Per-mode settings: which configured model to use and the prompt to send with the text.
/// Shared by Translation, Grammar Correction and Style Correction — they differ only in
/// their default prompt.
struct ModeSettings: Codable, Equatable {
    /// `ModelProfile.id` from `SettingsStore.models`. `nil` until the user picks one.
    var modelProfileID: UUID?
    var prompt: String

    /// First-launch settings: no model chosen, prompt from the bundled Markdown file
    /// (`Contents/Resources/<name>.md`) so it can be revised without touching Swift.
    static func initial(promptResource name: String) -> ModeSettings {
        ModeSettings(modelProfileID: nil, prompt: bundledPrompt(named: name))
    }

    static func bundledPrompt(named name: String) -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return ""
        }
        return text
    }

    func profile(in models: [ModelProfile]) -> ModelProfile? {
        guard let id = modelProfileID else { return nil }
        return models.first { $0.id == id }
    }

    /// Pre-flight check for a mode launch. Returns a one-line instruction for the user,
    /// or `nil` when a request can go out. Checks stop at the first failure on purpose —
    /// the error alert should say one thing.
    func problem(models: [ModelProfile], tabName: String) -> String? {
        if models.isEmpty {
            return "Open the app, add a model in the Models tab, then select it in the \(tabName) tab."
        }
        guard let profile = profile(in: models) else {
            return "Open the app and choose a model in the \(tabName) tab."
        }
        let problems = profile.problems
        if !problems.isEmpty {
            return "The model “\(profile.displayName)” is incomplete: \(problems.joined(separator: ", ")). Fix it in the Models tab."
        }
        if prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Open the app and fill in the prompt in the \(tabName) tab."
        }
        return nil
    }
}

/// Shape of the per-mode settings before v1.4, when every mode carried its own OpenAI key
/// and model name. Read once to migrate those into `ModelProfile`s.
struct LegacyOpenAISettings: Decodable {
    var apiKey: String?
    var model: String?
}
