import SwiftUI

public struct SettingsRootView: View {
    @ObservedObject public var settings: ObservableSettings

    public init(settings: ObservableSettings) {
        self.settings = settings
    }

    public var body: some View {
        TabView {
            GeneralPane(settings: settings)
                .tabItem { Label("General", systemImage: "gear") }
            AboutPane()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 520, height: 360)
    }
}
