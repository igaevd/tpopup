import Foundation

/// Sends "system prompt + user text → reply text" to whatever a `ModelProfile` points at.
///
/// Two wire formats are supported. The request is built from the profile's defaults, then
/// the profile's extra body fields and extra headers are merged on top (extras win), so
/// provider-specific knobs never need code changes here.
struct LLMClient {
    static let anthropicVersion = "2026-10-21"
    private static let anthropicDefaultMaxTokens = 16000

    func complete(text: String, prompt: String, profile: ModelProfile) async throws -> String {
        let endpoint = profile.endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: endpoint), url.scheme != nil, url.host != nil else {
            throw LLMError.configuration("The endpoint URL “\(endpoint)” is not valid.")
        }

        let extraBody: [String: Any]
        let extraHeaders: [String: String]
        do {
            extraBody = try ModelProfile.parseJSONObject(profile.extraBodyJSON)
        } catch {
            throw LLMError.configuration("Extra request fields: \(error.localizedDescription)")
        }
        do {
            extraHeaders = try ModelProfile.parseHeaders(profile.extraHeadersJSON)
        } catch {
            throw LLMError.configuration("Extra HTTP headers: \(error.localizedDescription)")
        }

        let apiKey = profile.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let modelID = profile.modelID.trimmingCharacters(in: .whitespacesAndNewlines)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any]
        switch profile.apiFormat {
        case .openAIResponses:
            body = [
                "model": modelID,
                "instructions": prompt,
                "input": text
            ]
            if !apiKey.isEmpty {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }
        case .openAIChatCompletions:
            body = [
                "model": modelID,
                "messages": [
                    ["role": "system", "content": prompt],
                    ["role": "user", "content": text]
                ]
            ]
            if !apiKey.isEmpty {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }
        case .anthropicMessages:
            body = [
                "model": modelID,
                "max_tokens": Self.anthropicDefaultMaxTokens,
                "system": prompt,
                "messages": [
                    ["role": "user", "content": text]
                ]
            ]
            if !apiKey.isEmpty {
                request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            }
            request.setValue(Self.anthropicVersion, forHTTPHeaderField: "anthropic-version")
        }

        // Processing tier from the dedicated picker, in the provider's own field. Extras
        // merged below still win, so a hand-written value in the JSON box overrides it.
        if profile.hasServiceTier {
            body[profile.preset.tierBodyKey] = profile.tierOption.id
        }

        for (key, value) in extraBody { body[key] = value }
        for (key, value) in extraHeaders { request.setValue(value, forHTTPHeaderField: key) }

        // Anthropic fast mode on Claude Opus 5 / 4.8 still needs its beta flag; merge it
        // into whatever `anthropic-beta` the user may already send.
        if profile.hasServiceTier, profile.presetID == ProviderPreset.anthropic.id {
            let beta = ProviderPreset.anthropicFastModeBeta
            let existing = request.value(forHTTPHeaderField: "anthropic-beta") ?? ""
            let flags = existing.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if !flags.contains(beta) {
                request.setValue((flags + [beta]).joined(separator: ","), forHTTPHeaderField: "anthropic-beta")
            }
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw LLMError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard (200..<300).contains(http.statusCode) else {
            // OpenAI-style and Anthropic-style error bodies both nest `error.message`.
            if let err = json?["error"] as? [String: Any],
               let message = err["message"] as? String {
                throw LLMError.api(provider: profile.preset.name, status: http.statusCode, message: message)
            }
            throw LLMError.api(provider: profile.preset.name,
                               status: http.statusCode,
                               message: "Server returned status \(http.statusCode).")
        }

        guard let json else { throw LLMError.invalidResponse }

        let reply: String
        switch profile.apiFormat {
        case .openAIResponses:
            reply = try Self.parseResponsesAPI(json, provider: profile.preset.name)
        case .openAIChatCompletions:
            reply = try Self.parseChatCompletion(json)
        case .anthropicMessages:
            reply = try Self.parseAnthropicMessage(json)
        }
        return reply.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Response parsing

    /// Responses API: `output` is a list of items (reasoning, message, …); the answer is
    /// the `output_text` content of the message items.
    private static func parseResponsesAPI(_ json: [String: Any], provider: String) throws -> String {
        // A 200 with a populated `error` object (e.g. a failed response) still carries
        // the message in the same place as an HTTP error body.
        if let err = json["error"] as? [String: Any],
           let message = err["message"] as? String {
            throw LLMError.api(provider: provider, status: 200, message: message)
        }
        guard let output = json["output"] as? [[String: Any]] else {
            throw LLMError.invalidResponse
        }
        var text = ""
        for item in output where (item["type"] as? String) == "message" {
            guard let parts = item["content"] as? [[String: Any]] else { continue }
            for part in parts {
                switch part["type"] as? String {
                case "output_text":
                    text += part["text"] as? String ?? ""
                case "refusal":
                    if text.isEmpty {
                        throw LLMError.refused(part["refusal"] as? String ?? "The model declined this request.")
                    }
                default:
                    break
                }
            }
        }
        if text.isEmpty, let details = json["incomplete_details"] as? [String: Any],
           let reason = details["reason"] as? String {
            throw LLMError.api(provider: provider, status: 200, message: "Response incomplete: \(reason).")
        }
        guard !text.isEmpty else { throw LLMError.invalidResponse }
        return text
    }

    private static func parseChatCompletion(_ json: [String: Any]) throws -> String {
        guard let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any] else {
            throw LLMError.invalidResponse
        }
        if let content = message["content"] as? String {
            return content
        }
        // Some OpenAI-compatible servers return content as an array of text parts.
        if let parts = message["content"] as? [[String: Any]] {
            let text = parts.compactMap { $0["text"] as? String }.joined()
            if !text.isEmpty { return text }
        }
        if let refusal = message["refusal"] as? String, !refusal.isEmpty {
            throw LLMError.refused(refusal)
        }
        throw LLMError.invalidResponse
    }

    private static func parseAnthropicMessage(_ json: [String: Any]) throws -> String {
        guard let blocks = json["content"] as? [[String: Any]] else {
            throw LLMError.invalidResponse
        }
        // Thinking blocks (when enabled) come first; only the text blocks are the answer.
        let text = blocks
            .filter { ($0["type"] as? String) == "text" }
            .compactMap { $0["text"] as? String }
            .joined()
        if text.isEmpty, (json["stop_reason"] as? String) == "refusal" {
            throw LLMError.refused("The model declined to process this text.")
        }
        guard !text.isEmpty else { throw LLMError.invalidResponse }
        return text
    }
}

enum LLMError: LocalizedError {
    case configuration(String)
    case network(String)
    case invalidResponse
    case refused(String)
    case api(provider: String, status: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .configuration(let detail):
            return "Model configuration problem: \(detail)"
        case .network(let detail):
            return "Network error: \(detail)"
        case .invalidResponse:
            return "The server returned an unexpected response."
        case .refused(let detail):
            return "Request refused: \(detail)"
        case .api(let provider, let status, let message):
            return "\(provider) error (\(status)): \(message)"
        }
    }
}
