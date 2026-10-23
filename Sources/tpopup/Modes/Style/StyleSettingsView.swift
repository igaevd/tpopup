import SwiftUI

struct StyleSettingsView: View {
    @EnvironmentObject private var store: SettingsStore

    var body: some View {
        ModeSettingsForm(settings: $store.style)
    }
}
