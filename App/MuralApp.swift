import SwiftUI

@main
struct MuralApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsRoot(appDelegate: appDelegate)
        }
    }
}

/// Bridges AppDelegate's `ObservableSettings?` into the SwiftUI scene.
/// When AppDelegate hasn't fully initialised yet (rare — only during the
/// very first frame), shows a placeholder.
private struct SettingsRoot: View {
    let appDelegate: AppDelegate
    var body: some View {
        if let settings = appDelegate.observableSettings {
            SettingsRootView(settings: settings)
        } else {
            Text("Loading settings…").padding()
        }
    }
}
