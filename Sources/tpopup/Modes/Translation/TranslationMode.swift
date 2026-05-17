import SwiftUI

enum TranslationMode {
    static let appMode = AppMode(
        flag: "translate",
        displayName: "Translation",
        icon: "character.bubble",
        makeSettingsTab: { AnyView(TranslationSettingsView()) },
        run: {
            // The controller must outlive this closure: hand it to the app delegate.
            let controller = TranslationPopupController()
            AppDelegate.shared?.retain(controller)
            controller.run()
        }
    )
}
