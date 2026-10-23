import SwiftUI

struct GrammarSettingsView: View {
    @EnvironmentObject private var store: SettingsStore

    var body: some View {
        ModeSettingsForm(settings: $store.grammar)
    }
}
