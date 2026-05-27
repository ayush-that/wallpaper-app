import AppKit
import SwiftUI

public struct PropertiesPanel: View {
    @ObservedObject public var vm: PropertiesViewModel

    public init(vm: PropertiesViewModel) {
        self.vm = vm
    }

    public var body: some View {
        if vm.controls.isEmpty {
            emptyState
        } else {
            Form {
                ForEach(vm.controls) { control in
                    row(for: control)
                }
            }
            .formStyle(.grouped)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("This wallpaper has no customizable properties.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding(24)
    }

    @ViewBuilder
    private func row(for control: PropertyControl) -> some View {
        switch control {
        case let .slider(name, label, _, min, max, step):
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                Slider(value: sliderBinding(name: name, fallback: min), in: min ... max, step: step)
                Text(String(format: "%.2f", sliderBinding(name: name, fallback: min).wrappedValue))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case let .color(name, label, _):
            ColorPicker(label, selection: colorBinding(name: name))
        case let .checkbox(name, label, _):
            Toggle(label, isOn: checkboxBinding(name: name))
        case let .dropdown(name, label, items, _):
            Picker(label, selection: dropdownBinding(name: name)) {
                ForEach(items.indices, id: \.self) { index in
                    Text(items[index]).tag(index)
                }
            }
        case let .folderDropdown(name, label, _, _, _):
            // v1: render as a text field. v2 will scan the folder.
            TextField(label, text: stringBinding(name: name))
        case let .textbox(name, label, _):
            TextField(label, text: stringBinding(name: name))
        case let .button(name, label, value):
            Button(label) { vm.set(.string(value), for: name) }
        case let .label(_, value):
            Text(value)
        }
    }

    // MARK: - Bindings

    private func sliderBinding(name: String, fallback: Double) -> Binding<Double> {
        Binding(
            get: {
                if case let .double(v) = vm.values[name] { return v }
                return fallback
            },
            set: { vm.set(.double($0), for: name) }
        )
    }

    private func checkboxBinding(name: String) -> Binding<Bool> {
        Binding(
            get: {
                if case let .bool(v) = vm.values[name] { return v }
                return false
            },
            set: { vm.set(.bool($0), for: name) }
        )
    }

    private func dropdownBinding(name: String) -> Binding<Int> {
        Binding(
            get: {
                if case let .int(v) = vm.values[name] { return v }
                return 0
            },
            set: { vm.set(.int($0), for: name) }
        )
    }

    private func stringBinding(name: String) -> Binding<String> {
        Binding(
            get: {
                if case let .string(v) = vm.values[name] { return v }
                if case let .color(v) = vm.values[name] { return v }
                return ""
            },
            set: { vm.set(.string($0), for: name) }
        )
    }

    private func colorBinding(name: String) -> Binding<Color> {
        Binding(
            get: {
                if case let .color(hex) = vm.values[name] {
                    return Self.color(fromHex: hex)
                }
                return .white
            },
            set: { color in
                vm.set(.color(Self.hex(fromColor: color)), for: name)
            }
        )
    }

    // MARK: - Color conversions

    private static func color(fromHex hex: String) -> Color {
        let cleaned = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        let value = UInt32(cleaned, radix: 16) ?? 0xFFFFFF
        return Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    private static func hex(fromColor color: Color) -> String {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .white
        let r = Int((ns.redComponent * 255).rounded())
        let g = Int((ns.greenComponent * 255).rounded())
        let b = Int((ns.blueComponent * 255).rounded())
        return String(format: "#%02x%02x%02x", r, g, b)
    }
}
