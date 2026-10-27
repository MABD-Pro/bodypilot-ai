import Foundation

/// Demande de traitement adressée au routeur.
public struct AIRequest: Sendable {
    /// Fonctionnalité à l'origine de l'appel, pour mesurer le coût par fonctionnalité.
    public let feature: String
    /// Niveau minimal capable de traiter la demande.
    public let minimumTier: AITier

    public init(feature: String, minimumTier: AITier) {
        self.feature = feature
        self.minimumTier = minimumTier
    }
}

/// Consommation cloud courante sur la période du budget.
public struct AIUsageSnapshot: Sendable, Equatable {
    public var cloudCalls: Int
    public var cloudCost: Decimal

    public init(cloudCalls: Int = 0, cloudCost: Decimal = 0) {
        self.cloudCalls = cloudCalls
        self.cloudCost = cloudCost
    }
}

/// Limites de consommation cloud configurables (`nil` = pas de limite).
public struct AIBudget: Sendable, Equatable {
    public var maxCloudCalls: Int?
    public var maxCloudCost: Decimal?

    public init(maxCloudCalls: Int? = nil, maxCloudCost: Decimal? = nil) {
        self.maxCloudCalls = maxCloudCalls
        self.maxCloudCost = maxCloudCost
    }

    public func allowsCloudCall(given usage: AIUsageSnapshot) -> Bool {
        if let maxCloudCalls, usage.cloudCalls >= maxCloudCalls { return false }
        if let maxCloudCost, usage.cloudCost >= maxCloudCost { return false }
        return true
    }
}

public enum AIRoutingDecision: Sendable, Equatable {
    case route(AITier)
    case unavailable(Reason)

    public enum Reason: Sendable, Equatable {
        case noCapableTierAvailable
        case cloudBudgetExceeded
    }
}

/// Choisit le niveau de traitement le moins coûteux disponible pour une demande.
///
/// Ordre de priorité : déterministe local > IA locale > cloud économique > cloud avancé.
public struct AIRouter: Sendable {
    public var availableTiers: Set<AITier>
    public var budget: AIBudget

    public init(availableTiers: Set<AITier>, budget: AIBudget = AIBudget()) {
        self.availableTiers = availableTiers
        self.budget = budget
    }

    public func route(_ request: AIRequest, usage: AIUsageSnapshot) -> AIRoutingDecision {
        let candidates = AITier.allCases.filter {
            $0 >= request.minimumTier && availableTiers.contains($0)
        }
        guard let cheapest = candidates.first else {
            return .unavailable(.noCapableTierAvailable)
        }
        if cheapest.isCloud && !budget.allowsCloudCall(given: usage) {
            return .unavailable(.cloudBudgetExceeded)
        }
        return .route(cheapest)
    }
}
