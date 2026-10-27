import Foundation

/// Identifiant stable d'une entité locale (profil, repas, séance…).
///
/// Généré sur l'appareil : la donnée locale est la source opérationnelle,
/// le serveur ne fait que synchroniser.
public struct EntityID: Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: UUID

    public init(_ rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }

    public init(from decoder: any Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(UUID.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var description: String { rawValue.uuidString }
}
