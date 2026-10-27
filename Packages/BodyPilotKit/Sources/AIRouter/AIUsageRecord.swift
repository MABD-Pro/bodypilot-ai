import Foundation

/// Mesure d'un appel traité par le routeur : base des métriques
/// (appels, tokens, coût par fonctionnalité et par utilisateur, latence, erreurs).
public struct AIUsageRecord: Sendable, Equatable, Codable {
    public let feature: String
    public let tier: AITier
    public let inputTokens: Int
    public let outputTokens: Int
    public let cost: Decimal
    public let latency: Duration
    public let succeeded: Bool

    public init(
        feature: String,
        tier: AITier,
        inputTokens: Int = 0,
        outputTokens: Int = 0,
        cost: Decimal = 0,
        latency: Duration,
        succeeded: Bool
    ) {
        self.feature = feature
        self.tier = tier
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cost = cost
        self.latency = latency
        self.succeeded = succeeded
    }
}
