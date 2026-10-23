import SwiftUI

/// Root of the Settings window. One tab per registered mode, a Models tab for the shared
/// list of configured models, and a fixed-position OK button.
struct SettingsRootView: View {
    static let contentSize = CGSize(width: 700, height: 560)
    static let modelsTabID = "models"

    let onConfirm: () -> Void

    @EnvironmentObject private var store: SettingsStore
    @EnvironmentObject private var status: StatusCenter
    @State private var selectedTab: String

    /// `initialTab` is a mode flag or `modelsTabID`; defaults to the first mode tab.
    init(initialTab: String? = nil, onConfirm: @escaping () -> Void) {
        self.onConfirm = onConfirm
        _selectedTab = State(initialValue: initialTab ?? ModeRegistry.all.first?.flag ?? Self.modelsTabID)
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                ForEach(ModeRegistry.all, id: \.flag) { mode in
                    mode.makeSettingsTab()
                        .tabItem {
                            Label(mode.displayName, systemImage: mode.icon)
                        }
                        .tag(mode.flag)
                }

                ModelsSettingsView()
                    .tabItem {
                        Label("Models", systemImage: "cpu")
                    }
                    .tag(Self.modelsTabID)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Divider()

            HStack(spacing: 16) {
                StatusFooterView()
                Spacer(minLength: 0)
                Button("OK", action: onConfirm)
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(height: 62)
        }
        .frame(width: Self.contentSize.width, height: Self.contentSize.height)
        .onChange(of: selectedTab) { _, _ in
            status.clearUnlessRunning()
        }
        .onAppear {
            // Nothing works until at least one model exists, so land there first.
            if store.models.isEmpty && selectedTab != Self.modelsTabID {
                selectedTab = Self.modelsTabID
            }
        }
    }
}
