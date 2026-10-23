import Foundation

/// Fetches the model list for a profile from the provider's list-models endpoint. Used by
/// the Browse popover only; the list is never stored — only the chosen model ID is.
///
/// The URL is derived from the chat endpoint, so presets and custom servers alike work:
/// `…/v1/chat/completions`, `…/v1/responses` and `…/v1/messages` all map to `…/v1/models`.
/// OpenAI, Anthropic, Gemini (OpenAI-compatible), OpenRouter, Groq, Mistral, DeepSeek,
/// xAI and Ollama all answer with `{"data": [{"id": "…"}, …]}`.
enum ModelListFetcher {
    static func modelsURL(for profile: ModelProfile) -> URL? {
        var base = profile.endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasSuffix("/") { base.removeLast() }
        for suffix in ["/chat/completions", "/responses", "/messages"] where base.hasSuffix(suffix) {
            base.removeLast(suffix.count)
            break
        }
        guard let url = URL(string: base + "/models"), url.scheme != nil, url.host != nil else {
            return nil
        }
        return url
    }

    /// Whether a listing request can be made at all: a valid endpoint, and a key unless
    /// the provider's listing is public (OpenRouter) or local (Ollama, custom servers).
    static func canList(_ profile: ModelProfile) -> Bool {
        guard modelsURL(for: profile) != nil else { return false }
        let hasKey = !profile.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasKey || !profile.preset.requiresAPIKey || profile.preset.publicModelList
    }

    static func fetch(for profile: ModelProfile) async throws -> [String] {
        guard let baseURL = modelsURL(for: profile) else {
            throw LLMError.configuration("Cannot derive a models URL from “\(profile.endpoint)”.")
        }
        let extraHeaders: [String: String]
        do {
            extraHeaders = try ModelProfile.parseHeaders(profile.extraHeadersJSON)
        } catch {
            throw LLMError.configuration("Extra HTTP headers: \(error.localizedDescription)")
        }
        let apiKey = profile.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let isAnthropic = profile.apiFormat == .anthropicMessages

        var ids: [String] = []
        // Anthropic paginates (`has_more` / `last_id`); everyone else returns one page.
        var afterID: String? = nil
        var pages = 0
        repeat {
            var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
            if isAnthropic {
                var items = [URLQueryItem(name: "limit", value: "1000")]
                if let afterID { items.append(URLQueryItem(name: "after_id", value: afterID)) }
                components.queryItems = items
            }
            var request = URLRequest(url: components.url!)
            request.httpMethod = "GET"
            request.timeoutInterval = 30
            if isAnthropic {
                if !apiKey.isEmpty { request.setValue(apiKey, forHTTPHeaderField: "x-api-key") }
                request.setValue(LLMClient.anthropicVersion, forHTTPHeaderField: "anthropic-version")
            } else if !apiKey.isEmpty {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }
            for (key, value) in extraHeaders { request.setValue(value, forHTTPHeaderField: key) }

            let (data, response): (Data, URLResponse)
            do {
                (data, response) = try await URLSession.shared.data(for: request)
            } catch {
                throw LLMError.network(error.localizedDescription)
            }
            guard let http = response as? HTTPURLResponse else { throw LLMError.invalidResponse }
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard (200..<300).contains(http.statusCode) else {
                if let err = json?["error"] as? [String: Any], let message = err["message"] as? String {
                    throw LLMError.api(provider: profile.preset.name, status: http.statusCode, message: message)
                }
                throw LLMError.api(provider: profile.preset.name, status: http.statusCode,
                                   message: "Server returned status \(http.statusCode).")
            }
            guard let json, let items = json["data"] as? [[String: Any]] else {
                throw LLMError.invalidResponse
            }
            ids += items.compactMap { $0["id"] as? String }

            pages += 1
            afterID = nil
            if isAnthropic, (json["has_more"] as? Bool) == true, let last = json["last_id"] as? String {
                afterID = last
            }
        } while afterID != nil && pages < 20

        return normalize(ids)
    }

    /// Gemini's OpenAI-compatible listing prefixes IDs with `models/`, which the chat
    /// endpoint does not want back. Dedupe and sort for the drop-down.
    private static func normalize(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in ids {
            var id = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if id.hasPrefix("models/") { id.removeFirst("models/".count) }
            guard !id.isEmpty, seen.insert(id).inserted else { continue }
            result.append(id)
        }
        return result.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}
