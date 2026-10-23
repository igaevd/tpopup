import Foundation

/// A starting point for a `ModelProfile`: endpoint, wire format, console link and hints.
/// Picking a preset in the Models tab fills in the defaults; everything stays editable.
struct ProviderPreset: Identifiable, Equatable {
    let id: String
    let name: String
    let apiFormat: APIFormat
    let endpoint: String
    let consoleURL: URL?
    let keyPlaceholder: String
    let modelPlaceholder: String
    /// SF Symbol for the icon tile (OpenAI uses its blossom mark instead).
    let symbol: String
    /// Local servers (Ollama, LM Studio) and custom endpoints usually need no key.
    let requiresAPIKey: Bool
    /// Example shown under the "Extra request fields" box.
    let bodyExample: String
    /// Example shown under the "Extra HTTP headers" box.
    let headersExample: String
    /// One-line note under the editor header, when the setup is not obvious.
    let note: String?
    /// Processing tiers the provider offers; empty hides the Service tier row.
    var tierOptions: [ServiceTierOption] = []
    /// The `/models` listing works without an API key (OpenRouter).
    var publicModelList: Bool = false

    /// Request-body field the tier is sent in. Anthropic calls it `speed`; OpenAI and
    /// Gemini (through its OpenAI-compatible endpoint) both use `service_tier`.
    var tierBodyKey: String { id == ProviderPreset.anthropic.id ? "speed" : "service_tier" }

    /// Beta header Anthropic still requires for fast mode on Claude Opus 5 / 4.8
    /// (Opus 5.5 ignores it harmlessly).
    static let anthropicFastModeBeta = "fast-mode-2026-02-01"

    /// OpenAI's two endpoints; the editor swaps between them when the API format changes.
    static let openAIResponsesEndpoint = "https://api.openai.com/v1/responses"
    static let openAIChatEndpoint = "https://api.openai.com/v1/chat/completions"

    static let openAI = ProviderPreset(
        id: "openai",
        name: "OpenAI",
        apiFormat: .openAIResponses,
        endpoint: openAIResponsesEndpoint,
        consoleURL: URL(string: "https://platform.openai.com"),
        keyPlaceholder: "sk-…",
        modelPlaceholder: "e.g. gpt-6.1-sol",
        symbol: "circle.hexagongrid",
        requiresAPIKey: true,
        bodyExample: "{\"reasoning\": {\"effort\": \"low\"}}",
        headersExample: "{\"OpenAI-Organization\": \"org_…\"}",
        note: nil,
        tierOptions: [
            .standard,
            ServiceTierOption(
                id: "flex",
                displayName: "Flex — cheaper, slower",
                description: "About half the standard price, with higher latency. Limited model availability."
            ),
            ServiceTierOption(
                id: "fast",
                displayName: "Fast — 2× price",
                description: "Faster processing at about twice the standard price (formerly “priority”)."
            ),
            ServiceTierOption(
                id: "ultrafast",
                displayName: "Ultrafast — fastest, 6× price",
                description: "Fastest output, about six times the standard price. Supported by gpt-6.1-sol and gpt-6-astra via the Responses API.",
                supportedModels: ["gpt-6.1-sol", "gpt-6-astra"]
            )
        ]
    )

    static let anthropic = ProviderPreset(
        id: "anthropic",
        name: "Anthropic",
        apiFormat: .anthropicMessages,
        endpoint: "https://api.anthropic.com/v1/messages",
        consoleURL: URL(string: "https://console.anthropic.com"),
        keyPlaceholder: "sk-ant-…",
        modelPlaceholder: "e.g. claude-opus-5-5",
        symbol: "asterisk",
        requiresAPIKey: true,
        bodyExample: "{\"max_tokens\": 8000, \"output_config\": {\"effort\": \"low\"}}",
        headersExample: "{\"anthropic-beta\": \"…\"}",
        note: nil,
        tierOptions: [
            .standard,
            ServiceTierOption(
                id: "fast",
                displayName: "Fast — 2× price",
                description: "Up to 2.5× faster output at about twice the standard price. Claude Opus 5.5, Opus 5 and Opus 4.8 only; other models return an error.",
                supportedModels: ["claude-opus-5-5", "claude-opus-5", "claude-opus-4-8"]
            )
        ]
    )

    static let gemini = ProviderPreset(
        id: "gemini",
        name: "Google Gemini",
        apiFormat: .openAIChatCompletions,
        endpoint: "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions",
        consoleURL: URL(string: "https://aistudio.google.com"),
        keyPlaceholder: "AIza…",
        modelPlaceholder: "e.g. gemini-2.5-flash",
        symbol: "sparkle",
        requiresAPIKey: true,
        bodyExample: "{\"reasoning_effort\": \"low\"}",
        headersExample: "{\"X-Custom-Header\": \"value\"}",
        note: "Uses Gemini's OpenAI-compatible endpoint.",
        tierOptions: [
            .standard,
            ServiceTierOption(
                id: "flex",
                displayName: "Flex — 50% price",
                description: "Half the standard price, best effort: may wait minutes or fail with 429/503 under load."
            ),
            ServiceTierOption(
                id: "priority",
                displayName: "Priority — ~1.8× price",
                description: "Higher priority at about 1.8× the standard price. Overflow is served at Standard automatically."
            )
        ]
    )

    static let openRouter = ProviderPreset(
        id: "openrouter",
        name: "OpenRouter",
        apiFormat: .openAIChatCompletions,
        endpoint: "https://openrouter.ai/api/v1/chat/completions",
        consoleURL: URL(string: "https://openrouter.ai"),
        keyPlaceholder: "sk-or-…",
        modelPlaceholder: "e.g. openai/gpt-5.5",
        symbol: "arrow.triangle.branch",
        requiresAPIKey: true,
        bodyExample: "{\"provider\": {\"sort\": \"latency\"}}",
        headersExample: "{\"HTTP-Referer\": \"https://example.com\", \"X-Title\": \"tpopup\"}",
        note: "One key, any model — use the provider/model form for the model ID.",
        publicModelList: true
    )

    static let groq = ProviderPreset(
        id: "groq",
        name: "Groq",
        apiFormat: .openAIChatCompletions,
        endpoint: "https://api.groq.com/openai/v1/chat/completions",
        consoleURL: URL(string: "https://console.groq.com"),
        keyPlaceholder: "gsk_…",
        modelPlaceholder: "e.g. llama-3.3-70b-versatile",
        symbol: "bolt.fill",
        requiresAPIKey: true,
        bodyExample: "{\"temperature\": 0.2}",
        headersExample: "{\"X-Custom-Header\": \"value\"}",
        note: nil
    )

    static let mistral = ProviderPreset(
        id: "mistral",
        name: "Mistral",
        apiFormat: .openAIChatCompletions,
        endpoint: "https://api.mistral.ai/v1/chat/completions",
        consoleURL: URL(string: "https://console.mistral.ai"),
        keyPlaceholder: "API key",
        modelPlaceholder: "e.g. mistral-large-latest",
        symbol: "wind",
        requiresAPIKey: true,
        bodyExample: "{\"temperature\": 0.2}",
        headersExample: "{\"X-Custom-Header\": \"value\"}",
        note: nil
    )

    static let deepSeek = ProviderPreset(
        id: "deepseek",
        name: "DeepSeek",
        apiFormat: .openAIChatCompletions,
        endpoint: "https://api.deepseek.com/chat/completions",
        consoleURL: URL(string: "https://platform.deepseek.com"),
        keyPlaceholder: "sk-…",
        modelPlaceholder: "e.g. deepseek-chat",
        symbol: "water.waves",
        requiresAPIKey: true,
        bodyExample: "{\"temperature\": 0.2}",
        headersExample: "{\"X-Custom-Header\": \"value\"}",
        note: nil
    )

    static let xAI = ProviderPreset(
        id: "xai",
        name: "xAI",
        apiFormat: .openAIChatCompletions,
        endpoint: "https://api.x.ai/v1/chat/completions",
        consoleURL: URL(string: "https://console.x.ai"),
        keyPlaceholder: "xai-…",
        modelPlaceholder: "e.g. grok-4",
        symbol: "xmark.diamond",
        requiresAPIKey: true,
        bodyExample: "{\"temperature\": 0.2}",
        headersExample: "{\"X-Custom-Header\": \"value\"}",
        note: nil
    )

    static let ollama = ProviderPreset(
        id: "ollama",
        name: "Ollama (local)",
        apiFormat: .openAIChatCompletions,
        endpoint: "http://localhost:11434/v1/chat/completions",
        consoleURL: URL(string: "https://ollama.com/library"),
        keyPlaceholder: "not needed for a local server",
        modelPlaceholder: "e.g. llama3.2",
        symbol: "desktopcomputer",
        requiresAPIKey: false,
        bodyExample: "{\"options\": {\"temperature\": 0.2}}",
        headersExample: "{\"X-Custom-Header\": \"value\"}",
        note: "Runs on this Mac; make sure the Ollama app is running."
    )

    static let custom = ProviderPreset(
        id: "custom",
        name: "Custom endpoint",
        apiFormat: .openAIChatCompletions,
        endpoint: "",
        consoleURL: nil,
        keyPlaceholder: "leave empty if the server needs none",
        modelPlaceholder: "model ID the server expects",
        symbol: "slider.horizontal.3",
        requiresAPIKey: false,
        bodyExample: "{\"temperature\": 0.2}",
        headersExample: "{\"X-Custom-Header\": \"value\"}",
        note: "Any server speaking the OpenAI Chat Completions or Anthropic Messages format."
    )

    /// Order shown in the "+" menu.
    static let all: [ProviderPreset] = [
        openAI, anthropic, gemini, openRouter, groq, mistral, deepSeek, xAI, ollama, custom
    ]

    static func preset(for id: String) -> ProviderPreset {
        all.first { $0.id == id } ?? custom
    }
}
