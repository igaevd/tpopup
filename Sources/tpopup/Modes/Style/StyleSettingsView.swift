import SwiftUI

struct StyleSettingsView: View {
    @EnvironmentObject private var store: SettingsStore

    var body: some View {
        OpenAISettingsForm(
            apiKey: $store.style.apiKey,
            model: $store.style.model,
            prompt: $store.style.prompt
        )
    }
}
