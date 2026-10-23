import SwiftUI

/// Multi-line text box styled like the app's other inputs: rounded, bordered, dark
/// text background. Used for prompts and the JSON "extras" fields.
struct BoxedTextEditor: View {
    @Binding var text: String
    var font: Font = .system(size: 12)
    var minHeight: CGFloat = 120
    var maxHeight: CGFloat? = nil

    var body: some View {
        TextEditor(text: $text)
            .font(font)
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
            .frame(minHeight: minHeight, maxHeight: maxHeight)
    }
}

/// The rounded "card" background shared by the provider header and the model picker.
struct SettingsCard: ViewModifier {
    func body(content: Content) -> some View {
        content
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
}

extension View {
    func settingsCard() -> some View { modifier(SettingsCard()) }
}
