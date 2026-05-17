import SwiftUI

struct TranslationSettingsView: View {
    @EnvironmentObject private var store: SettingsStore

    var body: some View {
        OpenAISettingsForm(
            apiKey: $store.translation.apiKey,
            model: $store.translation.model,
            prompt: $store.translation.prompt
        )
    }
}
