import AVFoundation
import Foundation
import NaturalLanguage

/// Wraps `AVSpeechSynthesizer`, choosing the voice from the language of the text — but only
/// ever among the languages the user has configured in macOS (`Locale.preferredLanguages`).
///
/// Constraining detection to the system's languages is what makes short input reliable. An
/// unconstrained `NLLanguageRecognizer` is statistical and guesses wildly on one or two
/// words: it reports an English word ("table") as French and a Russian word ("Привет") as
/// Bulgarian. Restricted to, say, {English, Russian} those become unambiguous by script, so
/// even a single character resolves correctly — and the popup speaks it in the right voice.
///
/// We read the language set from the system rather than hardcoding it, so adding a language
/// in macOS is all it takes; nothing here is tied to a specific language pair.
///
/// Publishes `speakingID` so the popup view can swap the speaker icon for a stop button
/// while the matching section is being read aloud.
@MainActor
final class SpeechService: NSObject, ObservableObject {
    static let shared = SpeechService()

    @Published private(set) var speakingID: UUID?

    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func isSpeaking(id: UUID) -> Bool {
        speakingID == id
    }

    func speak(_ text: String, id: UUID) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: trimmed)
        if let code = detectLanguageCode(for: trimmed),
           let voice = AVSpeechSynthesisVoice(language: code) {
            utterance.voice = voice
        }

        speakingID = id
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        speakingID = nil
    }

    /// Detects the language of `text`, restricted to the languages the user actually works
    /// in — read from macOS via `Locale.preferredLanguages`. Returns a primary language
    /// code (e.g. "en", "ru") that `AVSpeechSynthesisVoice(language:)` resolves to the
    /// user's system-default voice for that language (Zoe, Katya, …).
    private func detectLanguageCode(for text: String) -> String? {
        let preferred = systemLanguageCodes()

        let recognizer = NLLanguageRecognizer()

        // The system's priority order becomes the prior, so that same-script pairs (e.g.
        // English vs. French, where a short word is genuinely ambiguous) lean toward the
        // user's primary language. For different-script pairs this is a no-op — script
        // alone already decides.
        if !preferred.isEmpty {
            let totalRank = Double((1...preferred.count).reduce(0, +))
            var hints: [NLLanguage: Double] = [:]
            for (index, code) in preferred.enumerated() {
                hints[NLLanguage(rawValue: code)] = Double(preferred.count - index) / totalRank
            }
            recognizer.languageHints = hints
        }

        // Hard-constrain the result only when we know at least two languages. With a single
        // known language we must not constrain, or we'd force every block into it and
        // mis-speak the other side of the translation.
        if preferred.count >= 2 {
            recognizer.languageConstraints = preferred.map { NLLanguage(rawValue: $0) }
        }

        recognizer.processString(text)
        return recognizer.dominantLanguage?.rawValue
    }

    /// Distinct primary language subtags from the user's macOS language list, in priority
    /// order — e.g. `["en-US", "ru-US", "en"]` → `["en", "ru"]`. The region is dropped on
    /// purpose: macOS can report a language against the user's region (Russian shows up as
    /// "ru-US" for a US-region user), which no installed voice matches, whereas the bare
    /// primary code resolves to the right regional voice.
    private func systemLanguageCodes() -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for tag in Locale.preferredLanguages {
            let primary = String(tag.prefix { $0 != "-" && $0 != "_" }).lowercased()
            guard !primary.isEmpty, seen.insert(primary).inserted else { continue }
            result.append(primary)
        }
        return result
    }
}

extension SpeechService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.speakingID = nil }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.speakingID = nil }
    }
}
