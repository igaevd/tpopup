import SwiftUI

/// "Browse" popover for the Model ID field: fetches the provider's live model list every
/// time it opens, lets the user filter it, and fills the field on click. Nothing here is
/// persisted — only the model ID the user ends up with.
struct ModelBrowserPopover: View {
    let profile: ModelProfile
    let currentModelID: String
    let onSelect: (String) -> Void

    @State private var query = ""
    @State private var models: [String] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var fetchTask: Task<Void, Never>?
    @FocusState private var searchFocused: Bool

    private var filtered: [String] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return models }
        return models.filter { $0.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                TextField("Search", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .focused($searchFocused)
                Button {
                    load()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.borderless)
                .disabled(isLoading)
                .help("Fetch the list again")
            }
            .padding(10)

            Divider()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            footer
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .frame(width: 340, height: 380)
        .onAppear {
            searchFocused = true
            load()
        }
        .onDisappear {
            fetchTask?.cancel()
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            VStack(spacing: 10) {
                ProgressView()
                    .controlSize(.regular)
                Text("Loading models from \(profile.endpointHost ?? profile.endpoint)…")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        } else if let error {
            VStack(spacing: 10) {
                Image(systemName: "xmark.octagon.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.red)
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                    .frame(maxWidth: 280)
                Button("Try again") { load() }
                    .controlSize(.small)
            }
            .padding()
        } else if filtered.isEmpty {
            Text(models.isEmpty ? "The provider returned no models." : "No model matches “\(query)”.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding()
        } else {
            ScrollViewReader { proxy in
                List(filtered, id: \.self) { model in
                    Button {
                        onSelect(model)
                    } label: {
                        HStack(spacing: 8) {
                            Text(model)
                                .font(.system(size: 12, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: 0)
                            if model == currentModelID.trimmingCharacters(in: .whitespacesAndNewlines) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    .id(model)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .onAppear {
                    proxy.scrollTo(currentModelID.trimmingCharacters(in: .whitespacesAndNewlines), anchor: .center)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            if !isLoading, error == nil {
                Text(query.isEmpty ? "\(models.count) models" : "\(filtered.count) of \(models.count) models")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(profile.endpointHost ?? "")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }

    /// Honors the `TPOPUP_DEBUG` env var, like the runners.
    private func debugLog(_ message: @autoclosure () -> String) {
        guard ProcessInfo.processInfo.environment["TPOPUP_DEBUG"] != nil else { return }
        NSLog("[tpopup] %@", message())
    }

    private func load() {
        fetchTask?.cancel()
        isLoading = true
        error = nil
        let snapshot = profile
        fetchTask = Task { @MainActor in
            do {
                let list = try await ModelListFetcher.fetch(for: snapshot)
                guard !Task.isCancelled else { return }
                models = list
                debugLog("browse: \(list.count) models loaded")
            } catch {
                guard !Task.isCancelled else { return }
                self.error = error.localizedDescription
                debugLog("browse: failed: \(error.localizedDescription)")
            }
            isLoading = false
        }
    }
}
