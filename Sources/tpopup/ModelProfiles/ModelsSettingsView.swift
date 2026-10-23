import SwiftUI

/// The Models tab: a list of configured models on the left, the selected one's editor on
/// the right. "+" offers provider presets; "−" removes the selection (and clears any mode
/// that used it).
struct ModelsSettingsView: View {
    @EnvironmentObject private var store: SettingsStore
    @State private var selectedID: UUID?

    var body: some View {
        HStack(spacing: 16) {
            sidebar
                .frame(width: 200)

            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(20)
        .onAppear {
            if selectedID == nil || !store.models.contains(where: { $0.id == selectedID }) {
                selectedID = store.models.first?.id
            }
        }
    }

    // MARK: - List

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: $selectedID) {
                ForEach(store.models) { profile in
                    ModelRow(profile: profile)
                        .tag(profile.id)
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .background(Color(nsColor: .textBackgroundColor))

            Divider()

            HStack(spacing: 0) {
                addMenu
                Divider().frame(height: 14)
                Button {
                    removeSelected()
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 26, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .disabled(selectedID == nil)
                .help("Remove the selected model")
                Spacer()
            }
            .frame(height: 24)
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }

    private var addMenu: some View {
        Menu {
            ForEach(ProviderPreset.all) { preset in
                Button(preset.name) { add(preset) }
            }
        } label: {
            Image(systemName: "plus")
                .frame(width: 26, height: 22)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Add a model")
    }

    private func add(_ preset: ProviderPreset) {
        let profile = store.addModel(from: preset)
        selectedID = profile.id
    }

    private func removeSelected() {
        guard let id = selectedID,
              let index = store.models.firstIndex(where: { $0.id == id }) else { return }
        store.removeModel(id: id)
        // Keep a neighbour selected so the editor doesn't blank out.
        let next = min(index, store.models.count - 1)
        selectedID = next >= 0 ? store.models[next].id : nil
    }

    // MARK: - Editor

    @ViewBuilder
    private var detail: some View {
        if let id = selectedID, store.models.contains(where: { $0.id == id }) {
            ModelProfileEditor(profile: binding(for: id))
                .id(id)     // fresh editor state (disclosure, focus) per profile
        } else {
            emptyState
        }
    }

    /// Binding into the store by id, so a deletion mid-render can't index out of range.
    private func binding(for id: UUID) -> Binding<ModelProfile> {
        Binding(
            get: {
                store.models.first { $0.id == id } ?? ModelProfile(preset: .custom)
            },
            set: { updated in
                if let index = store.models.firstIndex(where: { $0.id == id }) {
                    store.models[index] = updated
                }
            }
        )
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "cpu")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.tertiary)
            Text(store.models.isEmpty ? "No models yet" : "No model selected")
                .font(.system(size: 15, weight: .semibold))
            Text("Click + to add one. Each mode tab then picks a model from this list.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ModelRow: View {
    let profile: ModelProfile

    var body: some View {
        HStack(spacing: 8) {
            ProviderIconView(preset: profile.preset, size: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(profile.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(profile.modelID.isEmpty ? "no model ID" : profile.modelID)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if !profile.isComplete {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .help(profile.problems.joined(separator: ", "))
            }
        }
        .padding(.vertical, 3)
    }
}
