import SwiftUI

public struct PlaylistEditor: View {
    @State private var draft: Playlist
    private let availableWallpapers: [Wallpaper]
    private let onSave: (Playlist) -> Void
    private let onCancel: () -> Void

    public init(
        initial: Playlist,
        availableWallpapers: [Wallpaper],
        onSave: @escaping (Playlist) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _draft = State(initialValue: initial)
        self.availableWallpapers = availableWallpapers
        self.onSave = onSave
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                TextField("Name", text: $draft.name)

                Picker("Strategy", selection: strategyTag) {
                    Text("Interval").tag("interval")
                    Text("Shuffle").tag("shuffle")
                    Text("On idle").tag("idle")
                    Text("Time of day").tag("time")
                }

                if let interval = currentIntervalSeconds {
                    Stepper(
                        "Every \(humanize(interval))",
                        value: intervalBinding,
                        in: 30 ... 86400,
                        step: 30
                    )
                }

                Section("Wallpapers (\(draft.wallpaperIDs.count) selected)") {
                    if availableWallpapers.isEmpty {
                        Text("Import some wallpapers first.").foregroundStyle(.secondary)
                    } else {
                        ForEach(availableWallpapers) { wallpaper in
                            Toggle(
                                wallpaper.title.isEmpty ? "(untitled)" : wallpaper.title,
                                isOn: bindingForInclusion(of: wallpaper.id)
                            )
                        }
                    }
                }

                Toggle("Enabled", isOn: $draft.enabled)
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { onSave(draft) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(16)
        }
        .frame(width: 560, height: 480)
    }

    private var strategyTag: Binding<String> {
        Binding(
            get: {
                switch draft.strategy {
                case .interval: "interval"
                case .shuffle: "shuffle"
                case .onIdle: "idle"
                case .timeOfDay: "time"
                }
            },
            set: { tag in
                switch tag {
                case "interval": draft.strategy = .interval(seconds: 600)
                case "shuffle": draft.strategy = .shuffle(seconds: 600)
                case "idle": draft.strategy = .onIdle(seconds: 300)
                default: draft.strategy = .timeOfDay(slots: [])
                }
            }
        )
    }

    private var currentIntervalSeconds: TimeInterval? {
        switch draft.strategy {
        case let .interval(seconds), let .shuffle(seconds), let .onIdle(seconds):
            seconds
        case .timeOfDay:
            nil
        }
    }

    private var intervalBinding: Binding<TimeInterval> {
        Binding(
            get: { currentIntervalSeconds ?? 600 },
            set: { seconds in
                switch draft.strategy {
                case .interval: draft.strategy = .interval(seconds: seconds)
                case .shuffle: draft.strategy = .shuffle(seconds: seconds)
                case .onIdle: draft.strategy = .onIdle(seconds: seconds)
                case .timeOfDay: break
                }
            }
        )
    }

    private func bindingForInclusion(of wallpaperID: UUID) -> Binding<Bool> {
        Binding(
            get: { draft.wallpaperIDs.contains(wallpaperID) },
            set: { included in
                if included {
                    if !draft.wallpaperIDs.contains(wallpaperID) {
                        draft.wallpaperIDs.append(wallpaperID)
                    }
                } else {
                    draft.wallpaperIDs.removeAll { $0 == wallpaperID }
                }
            }
        )
    }

    private func humanize(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        if s < 60 { return "\(s)s" }
        if s < 3600 { return "\(s / 60) min" }
        return "\(s / 3600)h"
    }
}
