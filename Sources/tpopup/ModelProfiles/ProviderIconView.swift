import SwiftUI

/// Provider mark on a dark rounded tile. OpenAI gets its blossom; everyone else an
/// SF Symbol from the preset. `nil` draws a neutral chip for "no model chosen".
struct ProviderIconView: View {
    let preset: ProviderPreset?
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(white: 0.18), Color(white: 0.06)],
                    startPoint: .top, endPoint: .bottom
                ))

            if preset?.id == ProviderPreset.openAI.id,
               let nsImage = OpenAIBrand.blossomImage() {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.white)
                    .frame(width: size * 0.6, height: size * 0.6)
            } else {
                Image(systemName: preset?.symbol ?? "cpu")
                    .font(.system(size: size * 0.42, weight: .medium))
                    .foregroundStyle(preset == nil ? Color.white.opacity(0.45) : Color.white)
            }
        }
        .frame(width: size, height: size)
    }
}
