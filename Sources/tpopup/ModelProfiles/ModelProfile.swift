import Foundation

/// The wire protocol an endpoint speaks. OpenAI's own current API is Responses; almost
/// every other hosted provider (Gemini, OpenRouter, Groq, Mistral, DeepSeek, xAI, local
/// Ollama/LM Studio, …) accepts the older OpenAI Chat Completions dialect; Anthropic has
/// its own Messages API.
enum APIFormat: String, Codable, CaseIterable, Identifiable {
    case openAIResponses
    case openAIChatCompletions
    case anthropicMessages

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAIResponses:       return "OpenAI Responses"
        case .openAIChatCompletions: return "OpenAI Chat Completions"
        case .anthropicMessages:     return "Anthropic Messages"
        }
    }
}

/// One selectable processing tier for a provider (OpenAI's `service_tier`, Anthropic's
/// `speed`, Gemini's `service_tier`). `id` is the wire value; empty means "not sent".
struct ServiceTierOption: Identifiable, Equatable {
    let id: String
    let displayName: String
    let description: String
    /// Model IDs the provider documents for this tier; `nil` means any model. Used only
    /// for an advisory warning in the editor — the request is sent regardless.
    var supportedModels: [String]? = nil

    static let standard = ServiceTierOption(
        id: "",
        displayName: "Standard",
        description: "Regular processing at standard pricing."
    )

    /// True when `modelID` is one of `supportedModels` (exactly, or with a dated
    /// snapshot suffix), or when the tier has no documented model list.
    func supports(modelID: String) -> Bool {
        guard let supported = supportedModels else { return true }
        let id = modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        return supported.contains { id == $0 || id.hasPrefix($0 + "-20") }
    }
}

/// One configured model: where to send requests, how to authenticate, which model to ask
/// for, and any advanced per-request extras. Mode tabs (Translation, Grammar, Style) each
/// point at one profile by `id`.
struct ModelProfile: Codable, Equatable, Identifiable, Hashable {
    var id: UUID
    /// User-facing label shown in pickers, e.g. "GPT-5.5 priority".
    var name: String
    /// Which `ProviderPreset` this was created from — drives the icon, console link and
    /// placeholder hints. Purely cosmetic once `apiFormat`/`endpoint` are set.
    var presetID: String
    var apiFormat: APIFormat
    var endpoint: String
    var apiKey: String
    var modelID: String
    /// JSON object merged into the request body on every call — the escape hatch for
    /// provider-specific knobs (`service_tier`, `reasoning_effort`, `max_tokens`, …).
    /// Keys here win over the defaults the client builds.
    var extraBodyJSON: String
    /// JSON object of extra HTTP headers (`OpenAI-Organization`, `anthropic-beta`, …).
    var extraHeadersJSON: String
    /// Wire value of the chosen `ServiceTierOption`; empty means "not sent". Only
    /// meaningful when the preset declares tier options (OpenAI, Anthropic, Gemini).
    var serviceTier: String

    init(preset: ProviderPreset) {
        self.id = UUID()
        self.name = preset.name
        self.presetID = preset.id
        self.apiFormat = preset.apiFormat
        self.endpoint = preset.endpoint
        self.apiKey = ""
        self.modelID = ""
        self.extraBodyJSON = ""
        self.extraHeadersJSON = ""
        self.serviceTier = ""
    }

    // Hand-written decoding so profiles saved by older builds (without newer fields)
    // keep loading. New optional-ish fields go through `decodeIfPresent` with a default.
    private enum CodingKeys: String, CodingKey {
        case id, name, presetID, apiFormat, endpoint, apiKey, modelID
        case extraBodyJSON, extraHeadersJSON, serviceTier
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        presetID = try c.decode(String.self, forKey: .presetID)
        apiFormat = try c.decode(APIFormat.self, forKey: .apiFormat)
        endpoint = try c.decode(String.self, forKey: .endpoint)
        apiKey = try c.decode(String.self, forKey: .apiKey)
        modelID = try c.decode(String.self, forKey: .modelID)
        extraBodyJSON = try c.decodeIfPresent(String.self, forKey: .extraBodyJSON) ?? ""
        extraHeadersJSON = try c.decodeIfPresent(String.self, forKey: .extraHeadersJSON) ?? ""
        serviceTier = try c.decodeIfPresent(String.self, forKey: .serviceTier) ?? ""
    }

    /// The chosen tier among the preset's options, or Standard when unset/unknown.
    var tierOption: ServiceTierOption {
        preset.tierOptions.first { $0.id == serviceTier } ?? .standard
    }

    /// True when a non-standard tier is chosen for a provider that has tiers.
    var hasServiceTier: Bool {
        !preset.tierOptions.isEmpty && !tierOption.id.isEmpty
    }

    /// True when the extra request fields already carry the provider's tier field,
    /// which would override the picker (extras always win).
    var extraBodyOverridesServiceTier: Bool {
        (try? Self.parseJSONObject(extraBodyJSON))?[preset.tierBodyKey] != nil
    }

    var preset: ProviderPreset { ProviderPreset.preset(for: presetID) }

    /// Never empty: falls back to the model ID, then the provider name.
    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let model = modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        return model.isEmpty ? preset.name : model
    }

    var endpointHost: String? {
        URL(string: endpoint.trimmingCharacters(in: .whitespacesAndNewlines))?.host
    }

    /// Everything that would stop a request from going out, in user-facing words.
    /// Empty means the profile is ready to use.
    var problems: [String] {
        var list: [String] = []
        let trimmedEndpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmedEndpoint), url.scheme != nil, url.host != nil {
            // fine
        } else {
            list.append("endpoint URL is invalid")
        }
        if preset.requiresAPIKey && apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            list.append("API key is empty")
        }
        if modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            list.append("model ID is empty")
        }
        if Self.jsonProblem(extraBodyJSON, headers: false) != nil {
            list.append("extra request fields are not valid JSON")
        }
        if Self.jsonProblem(extraHeadersJSON, headers: true) != nil {
            list.append("extra headers are not valid JSON")
        }
        return list
    }

    var isComplete: Bool { problems.isEmpty }

    // MARK: - JSON extras

    enum JSONFieldError: LocalizedError {
        case invalid
        case notAnObject
        case headerValuesNotStrings

        var errorDescription: String? {
            switch self {
            case .invalid:                return "Not valid JSON."
            case .notAnObject:            return "Must be a JSON object, e.g. {\"key\": \"value\"}."
            case .headerValuesNotStrings: return "Header values must be strings."
            }
        }
    }

    /// Parses a JSON object from free text. Blank text is an empty object.
    static func parseJSONObject(_ text: String) throws -> [String: Any] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [:] }
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: Data(trimmed.utf8),
                                                      options: [.fragmentsAllowed])
        } catch {
            throw JSONFieldError.invalid
        }
        guard let dictionary = object as? [String: Any] else {
            throw JSONFieldError.notAnObject
        }
        return dictionary
    }

    /// Like `parseJSONObject`, but every value must be a string (HTTP header values).
    static func parseHeaders(_ text: String) throws -> [String: String] {
        let object = try parseJSONObject(text)
        var headers: [String: String] = [:]
        for (key, value) in object {
            guard let string = value as? String else { throw JSONFieldError.headerValuesNotStrings }
            headers[key] = string
        }
        return headers
    }

    /// Validation message for the Settings UI, or `nil` when the text is acceptable.
    static func jsonProblem(_ text: String, headers: Bool) -> String? {
        do {
            if headers { _ = try parseHeaders(text) } else { _ = try parseJSONObject(text) }
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
