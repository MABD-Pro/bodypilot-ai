/// Niveaux de traitement, du moins coûteux au plus coûteux.
///
/// Le routeur choisit toujours le niveau le plus bas capable de traiter la demande.
public enum AITier: Int, CaseIterable, Comparable, Sendable, Codable {
    /// Calcul déterministe local (calories, tendances, règles de sécurité).
    case deterministic = 0
    /// Modèle embarqué (Apple Foundation Models sur appareils compatibles).
    case onDevice = 1
    /// Modèle cloud économique.
    case cloudEconomy = 2
    /// Modèle cloud avancé, uniquement si nécessaire.
    case cloudAdvanced = 3

    public var isCloud: Bool { self >= .cloudEconomy }

    public static func < (lhs: AITier, rhs: AITier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
