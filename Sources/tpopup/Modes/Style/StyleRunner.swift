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
///   2. Show a floating status pill in the middle of the screen.
///   3. Send the clipboard text to OpenAI with the user's style prompt.
///   4. On success: write the corrected text to stdout and exit. The Quick Action
///      handles the replacement — no keystroke simulation, no Accessibility permission.
///   5. On failure: hide the pill and show a standard error alert.
@MainActor
final class StyleRunner: NSObject {
    private let statusWindow = StyleStatusWindow()
    private var task: Task<Void, Never>?

    func run() {
        debugLog("run() entered")

        // Pre-flight: settings filled in?
        let settings = SettingsStore.shared.style
        if let missing = settings.missingFields {
            let info: String
            if missing.count >= 3 {
                info = "Open the app to fill in your style correction settings."
            } else {
                info = "Open the app and set the \(joined(missing)) in the Style Correction tab."
            }
            ErrorPresenter.showAndQuit("Style correction settings are incomplete.", info: info)
        }

        // Pre-flight: clipboard has text?
        guard let source = Clipboard.readText() else {
            ErrorPresenter.showAndQuit(
                "Nothing to correct.",
                info: "Copy some text first, then trigger style correction again."
            )
        }

        debugLog("pre-flight passed; source.length=\(source.count) model=\(settings.model)")

        // Show the status pill on whichever screen is currently active.
        let screen = NSScreen.main ?? NSScreen.screens.first!
        statusWindow.show(onScreen: screen)

        // Fire the request.
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let corrected = try await OpenAIClient().complete(
                    text: source,
                    apiKey: settings.apiKey,
                    model: settings.model,
                    prompt: settings.prompt
                )
                self.debugLog("OpenAI request succeeded; chars=\(corrected.count)")
                self.finishSuccess(corrected: corrected)
            } catch {
                self.debugLog("OpenAI request failed: \(error.localizedDescription)")
                self.finishFailure(error.localizedDescription)
            }
        }
    }

    // MARK: - Completion

    private func finishSuccess(corrected: String) {
        statusWindow.hide()

        // The Quick Action captures whatever lands on our stdout and uses it to replace
        // the selected text via macOS Services. No terminator — the OpenAI prompt is
        // already configured to return clean text, and a trailing newline would show up
        // verbatim in the editor.
        FileHandle.standardOutput.write(Data(corrected.utf8))

        NSApp.terminate(nil)
        exit(0)
    }

    private func finishFailure(_ message: String) {
        statusWindow.hide()
        ErrorPresenter.showAndQuit("Style correction failed.", info: message)
    }

    // MARK: - Helpers

    private func joined(_ items: [String]) -> String {
        switch items.count {
        case 0:  return ""
        case 1:  return items[0]
        case 2:  return "\(items[0]) and \(items[1])"
        default:
            let head = items.dropLast().joined(separator: ", ")
            return "\(head), and \(items.last!)"
        }
    }

    /// Honors the `TPOPUP_DEBUG` env var so we can flip it on for diagnostics without
    /// shipping noise in release.
    private func debugLog(_ message: @autoclosure () -> String) {
        guard ProcessInfo.processInfo.environment["TPOPUP_DEBUG"] != nil else { return }
        NSLog("[tpopup] %@", message())
    }
}
