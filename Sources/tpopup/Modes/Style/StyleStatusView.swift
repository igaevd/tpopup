import SwiftUI

/// The pill-shaped status indicator shown while style correction is in flight.
///
/// Visual language matches the translation popup — same dark background, same border
/// stroke — so the two modes feel like they belong to the same app.
struct StyleStatusView: View {
    /// Width is fixed so the controller can position the window without measuring text.
    static let size = CGSize(width: 240, height: 52)

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
                .tint(Color.white.opacity(0.65))

            Text("Style correction")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.85))
        }
        .padding(.horizontal, 20)
        .frame(width: Self.size.width, height: Self.size.height)
        .background(
            RoundedRectangle(cornerRadius: Self.size.height / 2, style: .continuous)
                .fill(Color(white: 0.118))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Self.size.height / 2, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        )
    }
}
