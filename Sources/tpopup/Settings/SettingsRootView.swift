import SwiftUI

/// Root of the Settings window. One tab per registered mode + a fixed-position OK button.
struct SettingsRootView: View {
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                ForEach(ModeRegistry.all.indices, id: \.self) { i in
                    let mode = ModeRegistry.all[i]
                    mode.makeSettingsTab()
                        .tabItem {
                            Label(mode.displayName, systemImage: mode.icon)
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Divider()

            HStack {
                Spacer()
                Button("OK", action: onConfirm)
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
        .frame(width: 560, height: 460)
    }
}
