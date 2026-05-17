import SwiftUI

enum GrammarMode {
    static let appMode = AppMode(
        flag: "grammar",
        displayName: "Grammar Correction",
        icon: "text.badge.checkmark",
        makeSettingsTab: { AnyView(GrammarSettingsView()) },
        run: {
            // The runner must outlive this closure: hand it to the app delegate so it
            // sticks around until the OpenAI response arrives and the ⌘V is posted.
            let runner = GrammarRunner()
            AppDelegate.shared?.retain(runner)
            runner.run()
        }
    )
}
