import AppKit
import SwiftUI

/// Describes a runnable mode of the app (Translation today; Grammar Correction etc. tomorrow).
///
/// Each mode owns:
///   • a command-line flag that selects it,
///   • its own settings tab inside the unified Settings window,
///   • its own launch flow (the popup window or whatever else makes sense).
struct AppMode {
    /// The bare flag (without the leading dash) that picks this mode at launch.
    /// Example: `"translate"` → user passes `-translate`.
    let flag: String

    /// Human-readable name, shown on the settings tab.
    let displayName: String

    /// SF Symbol used in the settings tab item.
    let icon: String

    /// Builds the settings tab UI for this mode.
    let makeSettingsTab: () -> AnyView

    /// Runs the mode's flow. Called once `applicationDidFinishLaunching` fires.
    /// The mode is responsible for terminating the app when done.
    let run: @MainActor () -> Void
}
