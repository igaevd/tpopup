import SwiftUI

/// Form for one `ModelProfile`. The basics (name, provider, endpoint, key, model ID) sit in
/// a grid; the two JSON "extras" live under a collapsed Advanced section so the common
/// case stays uncluttered.
struct ModelProfileEditor: View {
    @Binding var profile: ModelProfile

    @EnvironmentObject private var store: SettingsStore
    @EnvironmentObject private var status: StatusCenter
    @State private var advancedExpanded = false
    @State private var browsing = false
    /// Set when the user clicks Save; cleared by the next edit so the button re-arms.
    @State private var saved = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case name, endpoint, apiKey, modelID, body, headers }

    var body: some View {
        VStack(spacing: 0) {
            editorScroll
            Divider()
                .padding(.top, 10)
            actionBar
        }
        .onAppear {
            advancedExpanded = !profile.extraBodyJSON.isEmpty || !profile.extraHeadersJSON.isEmpty
            status.clearUnlessRunning()
        }
        .onChange(of: profile.presetID) { oldID, newID in
            applyPreset(from: oldID, to: newID)
        }
        .onChange(of: profile.apiFormat) { oldFormat, newFormat in
            swapOpenAIEndpoint(from: oldFormat, to: newFormat)
        }
        .onChange(of: profile) { _, _ in
            // Any edit invalidates the last test result and re-arms Save.
            status.clearUnlessRunning()
            saved = false
        }
        .defaultFocus($focusedField, .name)
    }

    private var editorScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                Grid(alignment: .leadingFirstTextBaseline,
                     horizontalSpacing: 12, verticalSpacing: 10) {
                    GridRow {
                        fieldLabel("Name")
                        TextField(profile.preset.name, text: $profile.name)
                            .focused($focusedField, equals: .name)
                    }
                    GridRow {
                        fieldLabel("Provider")
                        Picker("", selection: $profile.presetID) {
                            ForEach(ProviderPreset.all) { preset in
                                Text(preset.name).tag(preset.id)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 240, alignment: .leading)
                    }
                    if let formats = selectableFormats {
                        GridRow {
                            fieldLabel("API format")
                            Picker("", selection: $profile.apiFormat) {
                                ForEach(formats) { format in
                                    Text(format.displayName).tag(format)
                                }
                            }
                            .labelsHidden()
                            .frame(maxWidth: 240, alignment: .leading)
                        }
                    }
                    GridRow {
                        fieldLabel("Endpoint")
                        TextField("https://…", text: $profile.endpoint)
                            .font(.system(size: 12, design: .monospaced))
                            .focused($focusedField, equals: .endpoint)
                    }
                    GridRow {
                        fieldLabel("API Key")
                        TextField(profile.preset.keyPlaceholder, text: $profile.apiKey)
                            .focused($focusedField, equals: .apiKey)
                    }
                    GridRow {
                        fieldLabel("Model ID")
                        HStack(spacing: 10) {
                            TextField(profile.preset.modelPlaceholder, text: $profile.modelID)
                                .focused($focusedField, equals: .modelID)
                            browseButton
                        }
                    }
                    if !profile.preset.tierOptions.isEmpty {
                        GridRow(alignment: .firstTextBaseline) {
                            fieldLabel("Service tier")
                            serviceTierControl
                        }
                    }
                }
                .textFieldStyle(.roundedBorder)

                DisclosureGroup(isExpanded: $advancedExpanded) {
                    advanced
                } label: {
                    Text("Advanced")
                        .font(.system(size: 13, weight: .semibold))
                }
            }
            .padding(.trailing, 4)
        }
    }

    // MARK: - Save / Test

    private var actionBar: some View {
        HStack(spacing: 10) {
            Spacer(minLength: 8)

            Button {
                runTest()
            } label: {
                Label("Test", systemImage: "bolt.fill")
                    .frame(minWidth: 56)
            }
            .buttonStyle(.bordered)
            .disabled(!profile.isComplete || status.isRunning)
            .help(profile.isComplete
                  ? "Send “ping” to this model and show its reply"
                  : "Fill in the missing fields first")

            Button {
                store.save()
                saved = true
            } label: {
                Label(saved ? "Saved" : "Save",
                      systemImage: saved ? "checkmark.circle.fill" : "checkmark.circle")
                    .frame(minWidth: 56)
            }
            .buttonStyle(.borderedProminent)
            .disabled(saved)
            .help("Write all settings to disk now; the window stays open")
        }
        .padding(.top, 10)
        .padding(.trailing, 4)
    }

    /// Link-style "Browse ⌄" that opens the live model list for this endpoint.
    private var browseButton: some View {
        let canBrowse = ModelListFetcher.canList(profile)
        return Button {
            browsing = true
        } label: {
            HStack(spacing: 3) {
                Text("Browse")
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .font(.system(size: 13))
            .foregroundStyle(canBrowse ? Color.accentColor : Color.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canBrowse)
        .help(canBrowse
              ? "Fetch the current model list from \(profile.endpointHost ?? profile.endpoint) and pick one"
              : "Enter the endpoint and API key first")
        .popover(isPresented: $browsing, arrowEdge: .bottom) {
            ModelBrowserPopover(profile: profile, currentModelID: profile.modelID) { model in
                profile.modelID = model
                browsing = false
            }
        }
    }

    /// One tiny round-trip with the profile exactly as edited (saved or not).
    private func runTest() {
        let snapshot = profile
        status.message = .init(kind: .running, text: "Sending “ping” to \(snapshot.modelID)…")
        Task { @MainActor in
            let start = Date()
            do {
                let reply = try await LLMClient().complete(
                    text: "ping",
                    prompt: "This is a connectivity test. Reply with exactly one word: pong",
                    profile: snapshot
                )
                let seconds = String(format: "%.1f", Date().timeIntervalSince(start))
                let short = reply.replacingOccurrences(of: "\n", with: " ")
                status.message = .init(kind: .success,
                                       text: "\(snapshot.modelID) replied “\(short.prefix(60))” in \(seconds) s")
            } catch {
                status.message = .init(kind: .failure, text: error.localizedDescription)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            ProviderIconView(preset: profile.preset)

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Text("\(profile.preset.name) · \(profile.apiFormat.displayName)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                if let url = profile.preset.consoleURL, let host = url.host {
                    Link(host, destination: url)
                        .font(.system(size: 11))
                        .focusable(false)
                }
            }

            Spacer()

            if let first = profile.problems.first {
                Label(first, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .lineLimit(2)
                    .frame(maxWidth: 160, alignment: .trailing)
                    .help(profile.problems.joined(separator: "\n"))
            }
        }
        .settingsCard()
    }

    // MARK: - Service tier (providers that offer one)

    private var serviceTierControl: some View {
        VStack(alignment: .leading, spacing: 5) {
            Picker("", selection: $profile.serviceTier) {
                ForEach(profile.preset.tierOptions) { tier in
                    Text(tier.displayName).tag(tier.id)
                }
            }
            .labelsHidden()
            .frame(maxWidth: 240, alignment: .leading)

            Text(profile.tierOption.description)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            if profile.hasServiceTier,
               !profile.modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !profile.tierOption.supports(modelID: profile.modelID),
               let supported = profile.tierOption.supportedModels {
                Label("\(profile.preset.name) does not offer this tier for \(profile.modelID.trimmingCharacters(in: .whitespacesAndNewlines)); the request will be rejected. Documented models: \(supported.joined(separator: ", ")).",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if profile.presetID == ProviderPreset.openAI.id,
               profile.serviceTier == "ultrafast",
               profile.apiFormat == .openAIChatCompletions {
                HStack(spacing: 8) {
                    Label("Ultrafast is documented for the Responses API only.",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                    Button("Use Responses API") {
                        profile.apiFormat = .openAIResponses
                    }
                    .controlSize(.small)
                }
            }

            if profile.hasServiceTier, profile.extraBodyOverridesServiceTier {
                Label("Extra request fields also set \(profile.preset.tierBodyKey) and take precedence.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Advanced

    private var advanced: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let note = profile.preset.note {
                Text(note)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            jsonField(
                title: "Extra request fields",
                hint: "JSON merged into every request body — provider-specific options such as "
                    + "service tier or reasoning effort. Example: \(profile.preset.bodyExample)",
                text: $profile.extraBodyJSON,
                field: .body,
                problem: ModelProfile.jsonProblem(profile.extraBodyJSON, headers: false)
            )

            jsonField(
                title: "Extra HTTP headers",
                hint: "JSON object of header name → value, sent with every request. "
                    + "Example: \(profile.preset.headersExample)",
                text: $profile.extraHeadersJSON,
                field: .headers,
                problem: ModelProfile.jsonProblem(profile.extraHeadersJSON, headers: true)
            )
        }
        .padding(.top, 8)
    }

    private func jsonField(title: String,
                           hint: String,
                           text: Binding<String>,
                           field: Field,
                           problem: String?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .foregroundStyle(.secondary)
            BoxedTextEditor(text: text,
                            font: .system(size: 12, design: .monospaced),
                            minHeight: 64, maxHeight: 64)
                .focused($focusedField, equals: field)
            if let problem {
                Label(problem, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
            } else {
                Text(hint)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Helpers

    /// Which API formats the user may pick for this preset. OpenAI offers its two own
    /// dialects, Custom offers everything, other presets are fixed (row hidden).
    private var selectableFormats: [APIFormat]? {
        switch profile.presetID {
        case ProviderPreset.openAI.id: return [.openAIResponses, .openAIChatCompletions]
        case ProviderPreset.custom.id: return APIFormat.allCases
        default:                       return nil
        }
    }

    /// Keeps an OpenAI profile's endpoint in step with its API format, as long as the
    /// endpoint is still one of OpenAI's own two URLs (a proxy URL is left alone).
    private func swapOpenAIEndpoint(from oldFormat: APIFormat, to newFormat: APIFormat) {
        guard profile.presetID == ProviderPreset.openAI.id, oldFormat != newFormat else { return }
        let endpoint = profile.endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        let known = [ProviderPreset.openAIResponsesEndpoint, ProviderPreset.openAIChatEndpoint]
        guard endpoint.isEmpty || known.contains(endpoint) else { return }
        switch newFormat {
        case .openAIResponses:       profile.endpoint = ProviderPreset.openAIResponsesEndpoint
        case .openAIChatCompletions: profile.endpoint = ProviderPreset.openAIChatEndpoint
        case .anthropicMessages:     break
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .gridColumnAlignment(.trailing)
            .foregroundStyle(.secondary)
    }

    /// Switching provider refreshes whatever still carried the old preset's defaults, and
    /// leaves anything the user typed by hand alone.
    private func applyPreset(from oldID: String, to newID: String) {
        let old = ProviderPreset.preset(for: oldID)
        let new = ProviderPreset.preset(for: newID)
        guard old.id != new.id else { return }

        let endpoint = profile.endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        if endpoint.isEmpty || endpoint == old.endpoint {
            profile.endpoint = new.endpoint
        }
        let name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty || name == old.name {
            profile.name = new.name
        }
        if new.id != ProviderPreset.custom.id {
            profile.apiFormat = new.apiFormat
        }
        // Tier values are provider-specific; never carry one across providers.
        profile.serviceTier = ""
    }
}
