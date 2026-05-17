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
}

/// The text font for the source and translation content. Monospaced (SF Mono) per the
/// requested code-editor look. The controller must mirror this in
/// `NSFont.monospacedSystemFont(ofSize:weight:)` so its layout measurements match.
private let popupTextFont: Font = .system(size: 17, design: .monospaced)

struct TranslationPopupView: View {
    @ObservedObject var viewModel: TranslationViewModel
    @ObservedObject var layout: TranslationLayoutModel

    // Stable, view-lifetime identifiers so SpeechService can tell the source and
    // translation sections apart when toggling play/stop.
    @State private var sourceID = UUID()
    @State private var translationID = UUID()

    var body: some View {
        VStack(spacing: 0) {
            TranslationSection(
                text: viewModel.sourceText,
                showSpinner: false,
                isError: false,
                speechID: sourceID
            )
            .frame(height: layout.sourceSectionHeight)

            Rectangle()
                .fill(PopupPalette.divider)
                .frame(height: 1)

            TranslationSection(
                text: translationDisplayText,
                showSpinner: viewModel.isLoading,
                isError: viewModel.errorMessage != nil,
                speechID: translationID
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

private struct TranslationSection: View {
    let text: String
    let showSpinner: Bool
    let isError: Bool
    let speechID: UUID

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
                speakerButton
                copyButton
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
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
        .foregroundStyle(PopupPalette.iconForeground)
        .onHover { hovering = $0 }
    }
}
