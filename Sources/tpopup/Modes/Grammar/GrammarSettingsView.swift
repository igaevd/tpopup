import SwiftUI

struct GrammarSettingsView: View {
    @EnvironmentObject private var store: SettingsStore

    var body: some View {
        OpenAISettingsForm(
            apiKey: $store.grammar.apiKey,
            model: $store.grammar.model,
            prompt: $store.grammar.prompt
        )
    }
}
