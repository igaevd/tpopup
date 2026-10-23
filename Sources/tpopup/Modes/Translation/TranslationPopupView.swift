import SwiftUI

/// Dark-mode palette for the translation popup. All colors are fixed (don't follow the
/// system appearance) so the popup looks identical regardless of macOS theme.
private enum PopupPalette {
    static let background    = Color(white: 0.118)             // ~#1E1E1E, VS Code-ish
    static let text          = Color(white: 0.86)              // ~#DBDBDB, slight off-white
    static let secondaryText = Color.white.opacity(0.55)
    static let border        = Color.white.opacity(0.18)
    static let divider       = Color.white.opacity(0.10)
    static let iconForeground = Color.white.opacity(0.65)
    static let iconHover      = Color.white.opacity(0.10)
    static let accent         = Color(red: 0.42, green: 0.70, blue: 1.0)   // soft blue, dark-friendly
}

/// The text font for the source and translation content. Monospaced (SF Mono) per the
/// requested code-editor look. The controller must mirror this in
/// `NSFont.monospacedSystemFont(ofSize:weight:)` so its layout measurements match.
private let popupTextFont: Font = .system(size: 17, design: .monospaced)

struct TranslationPopupView: View {
    @ObservedObject var viewModel: TranslationViewModel
    @ObservedObject var layout: TranslationLayoutModel
    /// Sends the (possibly edited) source text for translation again.
    let onRetranslate: () -> Void
    /// Moves the translation into the source section and translates it back.
    let onSwap: () -> Void

    // Stable, view-lifetime identifiers so SpeechService can tell the source and
    // translation sections apart when toggling play/stop.
    @State private var sourceID = UUID()
    @State private var translationID = UUID()

    var body: some View {
        VStack(spacing: 0) {
            // The source is editable so the user can try variations; the retranslate
            // button (also ⌘↩) sends the edited text. Looks identical until clicked into.
            TranslationSection(
                text: viewModel.sourceText,
                editableText: $viewModel.sourceText,
                showSpinner: false,
                isError: false,
                speechID: sourceID,
                retranslate: SourceRetranslate(
                    isDirty: viewModel.sourceText != viewModel.translatedSourceText,
                    isEnabled: !viewModel.isLoading
                        && !viewModel.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    action: onRetranslate
                ),
                swap: nil
            )
            .frame(height: layout.sourceSectionHeight)

            Rectangle()
                .fill(PopupPalette.divider)
                .frame(height: 1)

            // The translation can be sent back the other way: it becomes the source and
            // a new request goes out, so the prompt flips the language direction.
            TranslationSection(
                text: translationDisplayText,
                editableText: nil,
                showSpinner: viewModel.isLoading,
                isError: viewModel.errorMessage != nil,
                speechID: translationID,
                retranslate: nil,
                swap: SwapAction(
                    isEnabled: !viewModel.isLoading
                        && viewModel.errorMessage == nil
                        && !viewModel.translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    action: onSwap
                )
            )
            .frame(height: layout.translationSectionHeight)
        }
        .frame(width: layout.popupWidth)
        .background(PopupPalette.background)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(PopupPalette.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var translationDisplayText: String {
        if let error = viewModel.errorMessage { return error }
        return viewModel.translation
    }
}

/// State for the source section's retranslate control.
private struct SourceRetranslate {
    /// Source differs from what the current translation was made from.
    let isDirty: Bool
    let isEnabled: Bool
    let action: () -> Void
}

/// State for the translation section's "send back the other way" control.
private struct SwapAction {
    let isEnabled: Bool
    let action: () -> Void
}

private struct TranslationSection: View {
    let text: String
    /// Non-nil makes the content an editor instead of a label.
    let editableText: Binding<String>?
    let showSpinner: Bool
    let isError: Bool
    let speechID: UUID
    let retranslate: SourceRetranslate?
    let swap: SwapAction?

    @ObservedObject private var speech = SpeechService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Content area — fills available height; scrolls when text doesn't fit.
            if showSpinner {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(PopupPalette.secondaryText)
                    Text("Translating…")
                        .font(.system(size: 13))
                        .foregroundStyle(PopupPalette.secondaryText)
                }
                .padding(.top, 2)
                Spacer(minLength: 0)
            } else if let editableText {
                // Same font, colour and insets as the label below, on a transparent
                // background with no border — only the caret gives it away.
                TextEditor(text: editableText)
                    .font(popupTextFont)
                    .foregroundStyle(PopupPalette.text)
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.never)
                    // Cancel NSTextView's built-in insets so the text sits exactly where
                    // the read-only label below sits.
                    .padding(.horizontal, -7)
                    .padding(.vertical, 2)
                    .focusEffectDisabled()
            } else {
                ScrollView(.vertical) {
                    Text(text)
                        .font(popupTextFont)
                        .foregroundStyle(isError ? Color(nsColor: .systemRed) : PopupPalette.text)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 2)
                }
                .scrollContentBackground(.hidden)
            }

            HStack(spacing: 6) {
                Spacer()
                if let retranslate {
                    retranslateButton(retranslate)
                }
                if let swap {
                    swapButton(swap)
                }
                speakerButton
                copyButton
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    /// Icon-only "translate again". Tinted when the source was edited since the last
    /// translation, so it is obvious the translation below is stale.
    private func retranslateButton(_ state: SourceRetranslate) -> some View {
        IconButton(systemName: "arrow.triangle.2.circlepath",
                   tint: state.isDirty ? PopupPalette.accent : nil,
                   action: state.action)
            .disabled(!state.isEnabled)
            .keyboardShortcut(.return, modifiers: .command)
            .help("Translate the text above again (⌘↩)")
    }

    /// Icon-only "translate this back": the translation becomes the source.
    private func swapButton(_ state: SwapAction) -> some View {
        IconButton(systemName: "arrow.up.arrow.down", action: state.action)
            .disabled(!state.isEnabled)
            .keyboardShortcut(.return, modifiers: [.command, .shift])
            .help("Move the translation up and translate it back (⇧⌘↩)")
    }

    @ViewBuilder
    private var speakerButton: some View {
        let speakingThis = speech.isSpeaking(id: speechID)
        IconButton(systemName: speakingThis ? "stop.fill" : "speaker.wave.2") {
            if speakingThis {
                speech.stop()
            } else {
                speech.speak(text, id: speechID)
            }
        }
        .disabled(text.isEmpty || isError)
    }

    @ViewBuilder
    private var copyButton: some View {
        IconButton(systemName: "doc.on.doc") {
            Clipboard.write(text)
        }
        .disabled(text.isEmpty || isError)
    }
}

private struct IconButton: View {
    let systemName: String
    var tint: Color? = nil
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(hovering ? PopupPalette.iconHover : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)              // no auto-focus, no blue ring
        .focusEffectDisabled()
        .foregroundStyle(tint ?? PopupPalette.iconForeground)
        .onHover { hovering = $0 }
    }
}
