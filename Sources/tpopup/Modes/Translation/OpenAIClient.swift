import Foundation

/// Minimal OpenAI Chat Completions client. We use Chat Completions (not Responses) so
/// any model name the user types — including future ones — keeps working with the same
/// request/response shape.
struct OpenAIClient {
    static let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    func translate(text: String, settings: TranslationSettings) async throws -> String {
        let payload: [String: Any] = [
            "model": settings.model,
            "messages": [
                ["role": "system", "content": settings.prompt],
                ["role": "user", "content": text]
            ]
        ]

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        request.timeoutInterval = 60

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw OpenAIError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let err = json["error"] as? [String: Any],
               let msg = err["message"] as? String {
                throw OpenAIError.api(status: http.statusCode, message: msg)
            }
            throw OpenAIError.api(status: http.statusCode,
                                  message: "Server returned status \(http.statusCode).")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OpenAIError.invalidResponse
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum OpenAIError: LocalizedError {
    case network(String)
    case invalidResponse
    case api(status: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .network(let detail):
            return "Network error: \(detail)"
        case .invalidResponse:
            return "The server returned an unexpected response."
        case .api(let status, let message):
            return "OpenAI error (\(status)): \(message)"
        }
    }
}
