import Foundation

/// Heights for the two sections of the translation popup, driven by the controller and
/// observed by the SwiftUI view. The controller recomputes these every time the source
/// or translation text changes; the view re-renders with the new frame heights and the
/// surrounding NSWindow gets resized in lockstep.
@MainActor
final class TranslationLayoutModel: ObservableObject {
    @Published var popupWidth: CGFloat = 600
    @Published var sourceSectionHeight: CGFloat = 120
    @Published var translationSectionHeight: CGFloat = 120
}
