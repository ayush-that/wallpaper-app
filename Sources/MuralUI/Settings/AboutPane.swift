import SwiftUI

public struct AboutPane: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.fill.on.rectangle.fill")
                .resizable()
                .frame(width: 56, height: 56)
                .foregroundStyle(.tint)
            Text("Mural").font(.title)
            Text("Version \(Self.shortVersion)")
                .foregroundStyle(.secondary)
            Link("GitHub", destination: Self.repositoryURL)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private static var shortVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "?"
    }

    private static var repositoryURL: URL {
        // swiftlint:disable:next force_unwrapping
        URL(string: "https://github.com/ayush-that/wallpaper-app")!
    }
}
