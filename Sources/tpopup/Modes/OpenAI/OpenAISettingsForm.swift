import SwiftUI

/// Shared OpenAI-backed settings tab. Both the Translation and Grammar Correction modes
/// use it; they only differ in which `SettingsStore` slot is bound. Keeping the layout in
/// one place means a future tweak (provider card design, field order, etc.) updates every
/// mode at once.
struct OpenAISettingsForm: View {
    @Binding var apiKey: String
    @Binding var model: String
    @Binding var prompt: String

    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case apiKey, model, prompt }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            providerCard

            Grid(alignment: .leadingFirstTextBaseline,
                 horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    Text("API Key")
                        .gridColumnAlignment(.trailing)
                        .foregroundStyle(.secondary)
                    TextField("sk-…", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .apiKey)
                }
                GridRow {
                    Text("Model")
                        .gridColumnAlignment(.trailing)
                        .foregroundStyle(.secondary)
                    TextField("e.g. gpt-4o", text: $model)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .model)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Prompt")
                    .foregroundStyle(.secondary)
                TextEditor(text: $prompt)
                    .font(.system(size: 12))
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
                    .frame(minHeight: 120)
                    .focused($focusedField, equals: .prompt)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        // Without this, SwiftUI auto-focuses the first focusable thing in the tab —
        // which is the OpenAI link in the provider card, and it shows a blue focus ring.
        .defaultFocus($focusedField, .apiKey)
    }

    // MARK: - Provider header

    private var providerCard: some View {
        HStack(alignment: .center, spacing: 14) {
            providerIcon

            VStack(alignment: .leading, spacing: 2) {
                Text("OpenAI")
                    .font(.system(size: 15, weight: .semibold))
                Link("platform.openai.com",
                     destination: URL(string: "https://platform.openai.com")!)
                    .font(.system(size: 11))
                    .focusable(false)
                Text(OpenAIClient.endpoint.absoluteString)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }

    /// OpenAI "blossom" mark on a dark rounded tile.
    private var providerIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(white: 0.18), Color(white: 0.06)],
                    startPoint: .top, endPoint: .bottom
                ))

            if let nsImage = OpenAIBrand.blossomImage() {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
            }
        }
        .frame(width: 44, height: 44)
    }
}
