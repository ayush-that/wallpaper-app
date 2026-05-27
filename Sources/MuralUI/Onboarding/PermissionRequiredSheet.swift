import AppKit
import SwiftUI

public struct PermissionRequiredSheet: View {
    public let service: TCCStatus.Service
    public let onDismiss: () -> Void

    public init(service: TCCStatus.Service, onDismiss: @escaping () -> Void) {
        self.service = service
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .resizable()
                .frame(width: 44, height: 44)
                .foregroundStyle(.tint)
            Text("Mural needs **\(serviceTitle)** access")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            Text(detail)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                Button("Not Now") { onDismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Open System Settings") {
                    TCCStatus.openSystemSettings(for: service)
                    onDismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(width: 400)
        .padding(28)
    }

    private var serviceTitle: String {
        switch service {
        case .screenRecording: "Screen Recording"
        case .automation: "Automation"
        case .accessibility: "Accessibility"
        case .microphone: "Microphone"
        }
    }

    private var detail: String {
        switch service {
        case .screenRecording:
            "Mural reads system audio through Screen Recording (Apple's only API path for desktop audio). No screen content is recorded — only the audio stream is consumed for audio-reactive wallpapers."
        case .automation:
            "Mural detects which app is in the foreground so wallpapers can pause when needed."
        case .accessibility:
            "Mural forwards mouse and keyboard events to interactive wallpapers."
        case .microphone:
            "Mural reads microphone input for audio-reactive wallpapers."
        }
    }
}
