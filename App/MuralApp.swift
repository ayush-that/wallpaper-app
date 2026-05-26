import SwiftUI

@main
struct MuralApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            Text("Mural")
                .padding()
                .frame(width: 480, height: 320)
        }
    }
}
