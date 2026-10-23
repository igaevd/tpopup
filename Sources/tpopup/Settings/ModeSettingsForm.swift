import SwiftUI

/// Shared settings tab body for every mode: pick one of the configured models, edit the
/// prompt. Credentials and endpoints live in the Models tab, so a key is entered once and
/// reused by every mode that points at the same profile.
struct ModeSettingsForm: View {
    @EnvironmentObject private var store: SettingsStore
    @Binding var settings: ModeSettings

    @FocusState private var promptFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            modelCard

            VStack(alignment: .leading, spacing: 6) {
                Text("Prompt")
                    .foregroundStyle(.secondary)
                BoxedTextEditor(text: $settings.prompt, minHeight: 120)
                    .focused($promptFocused)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .onAppear {
            // A reference to a model that no longer exists would leave the picker blank;
            // fall back to the "Choose a model…" placeholder instead.
            if settings.modelProfileID != nil, selectedProfile == nil {
                settings.modelProfileID = nil
            }
        }
    }

    private var selectedProfile: ModelProfile? {
        settings.profile(in: store.models)
    }

    // MARK: - Model picker card

    private var modelCard: some View {
        HStack(alignment: .center, spacing: 14) {
            ProviderIconView(preset: selectedProfile?.preset)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 10) {
                    Text("Model")
                        .foregroundStyle(.secondary)
                    Picker("Model", selection: $settings.modelProfileID) {
                        if selectedProfile == nil {
                            Text(store.models.isEmpty ? "No models configured" : "Choose a model…")
                                .tag(UUID?.none)
                        }
                        ForEach(store.models) { profile in
                            Text(profile.displayName).tag(Optional(profile.id))
                        }
                    }
                    .labelsHidden()
                    .disabled(store.models.isEmpty)
                    .frame(maxWidth: 300, alignment: .leading)
                }

                detailLine
            }

            Spacer()
        }
        .settingsCard()
    }

    private func summaryLine(for profile: ModelProfile) -> String {
        var parts = [profile.preset.name, profile.modelID]
        if profile.hasServiceTier {
            parts.append(profile.tierOption.id)
        }
        parts.append(profile.endpointHost ?? profile.endpoint)
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var detailLine: some View {
        if store.models.isEmpty {
            Label("Add a model in the Models tab first.", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(.orange)
        } else if let profile = selectedProfile {
            if profile.isComplete {
                Text(summaryLine(for: profile))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .textSelection(.enabled)
            } else {
                Label("Incomplete: \(profile.problems.joined(separator: ", ")). Fix it in the Models tab.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            }
        } else {
            Text("Pick which configured model this mode should use.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
}
