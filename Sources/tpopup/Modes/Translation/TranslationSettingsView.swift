import SwiftUI

struct TranslationSettingsView: View {
    @EnvironmentObject private var store: SettingsStore

    var body: some View {
        ModeSettingsForm(settings: $store.translation)
    }
}
