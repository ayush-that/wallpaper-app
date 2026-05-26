import Foundation

/// Codable manifest for the `.pkg` archive's `project.json`. Field names match
/// the on-disk wire format; renaming would break compat with existing bundles.
public struct PkgProject: Decodable, Sendable {
    public let type: String
    public let title: String?
    public let file: String
}
