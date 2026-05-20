import SwiftUI

enum StyleMode {
    static let appMode = AppMode(
        flag: "style",
        displayName: "Style Correction",
        icon: "wand.and.stars",
        makeSettingsTab: { AnyView(StyleSettingsView()) },
        run: {
            // The runner must outlive this closure: hand it to the app delegate so it
            // sticks around until the OpenAI response arrives and the corrected text is
            // written to stdout.
            let runner = StyleRunner()
            AppDelegate.shared?.retain(runner)
            runner.run()
        }
    )
}
