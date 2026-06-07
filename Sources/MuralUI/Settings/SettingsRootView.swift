import SwiftUI

public struct SettingsRootView: View {
    @ObservedObject public var settings: ObservableSettings
    @ObservedObject public var updateManager: UpdateManager

    public init(settings: ObservableSettings, updateManager: UpdateManager) {
        self.settings = settings
        self.updateManager = updateManager
    }

    public var body: some View {
        TabView {
            GeneralPane(settings: settings, updateManager: updateManager)
                .tabItem { Label("General", systemImage: "gear") }
            AboutPane()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 520, height: 360)
    }
}
