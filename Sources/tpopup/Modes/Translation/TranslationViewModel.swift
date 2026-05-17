import Foundation

@MainActor
final class TranslationViewModel: ObservableObject {
    @Published var sourceText: String = ""
    @Published var translation: String = ""
    @Published var errorMessage: String? = nil
    @Published var isLoading: Bool = false

    func start(with sourceText: String) {
        self.sourceText = sourceText
        self.translation = ""
        self.errorMessage = nil
        self.isLoading = true
    }

    func finish(translation: String) {
        self.translation = translation
        self.errorMessage = nil
        self.isLoading = false
    }

    func fail(_ message: String) {
        self.translation = ""
        self.errorMessage = message
        self.isLoading = false
    }
}
