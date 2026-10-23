import AppKit
import Foundation

/// Drives the style-correction flow.
///
/// The Quick Action that triggers this:
///   • copies the selected text to the clipboard (`cat | pbcopy`),
///   • invokes the tpopup binary directly so the shell can capture its stdout,
///   • has "Output replaces selected text" checked, so the script's stdout is spliced
///     back into the editor by macOS Services.
///
/// All this runner does is:
///   1. Pre-flight: settings filled in, clipboard holds text.
///   2. Slide a small status island down from the top of the screen.
///   3. Send the clipboard text to the configured model with the user's style prompt.
///   4. On success: write the corrected text to stdout and exit. The Quick Action
///      handles the replacement — no keystroke simulation, no Accessibility permission.
///   5. On failure: hide the pill and show a standard error alert.
@MainActor
final class StyleRunner: NSObject {
    private let island = StatusIslandWindow()
    private var task: Task<Void, Never>?

    func run() {
        debugLog("run() entered")

        // Pre-flight: a model is chosen, complete, and there is a prompt?
        let store = SettingsStore.shared
        let settings = store.style
        if let problem = settings.problem(models: store.models, tabName: "Style Correction") {
            ErrorPresenter.showAndQuit("Style correction settings are incomplete.", info: problem)
        }
        // `problem` is nil only when the profile resolves, so this cannot fail.
        guard let profile = settings.profile(in: store.models) else {
            ErrorPresenter.showAndQuit("Style correction settings are incomplete.",
                                       info: "Open the app and choose a model in the Style Correction tab.")
        }

        // Pre-flight: clipboard has text?
        guard let source = Clipboard.readText() else {
            ErrorPresenter.showAndQuit(
                "Nothing to correct.",
                info: "Copy some text first, then trigger style correction again."
            )
        }

        debugLog("pre-flight passed; source.length=\(source.count) model=\(profile.preset.name)/\(profile.modelID)")

        // Slide the "refining" island down from the top of the screen under the mouse.
        island.show(label: "refining")

        // Fire the request.
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let corrected = try await LLMClient().complete(
                    text: source,
                    prompt: settings.prompt,
                    profile: profile
                )
                self.debugLog("request succeeded; chars=\(corrected.count)")
                self.finishSuccess(corrected: corrected)
            } catch {
                self.debugLog("request failed: \(error.localizedDescription)")
                self.finishFailure(error.localizedDescription)
            }
        }
    }

    // MARK: - Completion

    private func finishSuccess(corrected: String) {
        // The Quick Action captures whatever lands on our stdout and uses it to replace
        // the selected text via macOS Services. No terminator — the prompt is
        // already configured to return clean text, and a trailing newline would show up
        // verbatim in the editor. Closing stdout hands the text over immediately, so the
        // island's slide-out never delays the replacement.
        FileHandle.standardOutput.write(Data(corrected.utf8))
        FileHandle.standardOutput.closeFile()

        island.hide {
            NSApp.terminate(nil)
            exit(0)
        }
    }

    private func finishFailure(_ message: String) {
        island.hide()
        ErrorPresenter.showAndQuit("Style correction failed.", info: message)
    }

    // MARK: - Helpers

    /// Honors the `TPOPUP_DEBUG` env var so we can flip it on for diagnostics without
    /// shipping noise in release.
    private func debugLog(_ message: @autoclosure () -> String) {
        guard ProcessInfo.processInfo.environment["TPOPUP_DEBUG"] != nil else { return }
        NSLog("[tpopup] %@", message())
    }
}
