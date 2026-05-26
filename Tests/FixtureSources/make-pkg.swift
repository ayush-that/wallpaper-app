import Foundation

let entries: [(String, Data)] = [
    ("project.json", #"{"type":"video","title":"Sample","file":"clip.mp4"}"#.data(using: .utf8)!),
    ("clip.mp4", Data(repeating: 0xAB, count: 64))
]

let magic = "PKGV0001".data(using: .ascii)!

func u32(_ value: UInt32) -> Data {
    var littleEndian = value.littleEndian
    return Data(bytes: &littleEndian, count: 4)
}

// Build data block first to compute offsets.
var dataBlock = Data()
var offsets: [(UInt32, UInt32)] = []
for (_, payload) in entries {
    offsets.append((UInt32(dataBlock.count), UInt32(payload.count)))
    dataBlock.append(payload)
}

/// Header = magic + entry_count + table entries.
var header = Data()
header.append(u32(UInt32(entries.count)))
for (i, (name, _)) in entries.enumerated() {
    let nameBytes = name.data(using: .utf8)!
    header.append(u32(UInt32(nameBytes.count)))
    header.append(nameBytes)
    header.append(u32(offsets[i].0))
    header.append(u32(offsets[i].1))
}

let pkg = magic + header + dataBlock
let outURL = URL(fileURLWithPath: "Tests/Fixtures/sample.pkg")
try pkg.write(to: outURL)
print("Wrote \(pkg.count) bytes to \(outURL.path)")
