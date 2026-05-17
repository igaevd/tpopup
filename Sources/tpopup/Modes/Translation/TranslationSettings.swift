import Foundation

struct TranslationSettings: Codable, Equatable {
    var apiKey: String
    var model: String
    var prompt: String

    static let `default` = TranslationSettings(
        apiKey: "",
        model: "",
        prompt: Self.bundledDefaultPrompt()
    )

    /// The first-launch prompt ships in the app bundle at
    /// `Contents/Resources/translation-ai-prompt.md`, so it can be revised as a plain
    /// text file alongside the source — no Swift edit needed.
    private static func bundledDefaultPrompt() -> String {
        guard let url = Bundle.main.url(forResource: "translation-ai-prompt",
                                        withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return ""
        }
        return text
    }
}

extension TranslationSettings {
    /// Returns a human-readable list of missing required fields, or `nil` if everything
    /// needed to make an API call is present.
    var missingFields: [String]? {
        var missing: [String] = []
        if apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            missing.append("OpenAI API key")
        }
        if model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            missing.append("model")
        }
        if prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            missing.append("prompt")
        }
        return missing.isEmpty ? nil : missing
    }
}
