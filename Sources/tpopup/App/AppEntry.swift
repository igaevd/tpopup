import AppKit

@main
@MainActor
struct AppEntry {
    static func main() {
        let launchMode: AppDelegate.LaunchMode = {
            for arg in CommandLine.arguments.dropFirst() {
                guard arg.hasPrefix("-") else { continue }
                let flag = String(arg.dropFirst())
                if let mode = ModeRegistry.mode(forFlag: flag) {
                    return .run(mode)
                }
            }
            return .settings
        }()

        let app = NSApplication.shared
        let delegate = AppDelegate(launchMode: launchMode)
        app.delegate = delegate
        app.run()
    }
}
