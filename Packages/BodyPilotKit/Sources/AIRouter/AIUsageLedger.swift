import Foundation

/// Où le routeur range ses mesures. L'app fournit un registre enregistré sur l'iPhone,
/// les tests un registre en mémoire.
public protocol AIUsageRecording: Sendable {
    func record(_ record: AIUsageRecord) async
    /// Consommation cloud depuis `start`, pour le budget.
    func snapshot(since start: Date) async -> AIUsageSnapshot
}

/// Métriques d'une fonctionnalité : appels, échecs, niveau utilisé, latence et coût.
public struct AIFeatureSummary: Sendable, Equatable {
    public let feature: String
    public let calls: Int
    public let failures: Int
    public let callsByTier: [AITier: Int]
    public let averageLatency: Duration
    public let inputTokens: Int
    public let outputTokens: Int
    public let cost: Decimal
}

/// Registre des derniers appels (500 au plus) : base des métriques et du budget cloud.
public actor AIUsageLedger: AIUsageRecording {
    public static let capacity = 500

    public private(set) var records: [AIUsageRecord]
    private let persist: (@Sendable ([AIUsageRecord]) -> Void)?

    /// `persist` reçoit le registre après chaque appel, pour le garder entre deux lancements.
    public init(records: [AIUsageRecord] = [], persist: (@Sendable ([AIUsageRecord]) -> Void)? = nil) {
        self.records = Array(records.suffix(Self.capacity))
        self.persist = persist
    }

    public func record(_ record: AIUsageRecord) {
        records.append(record)
        if records.count > Self.capacity { records.removeFirst(records.count - Self.capacity) }
        persist?(records)
    }

    public func snapshot(since start: Date) -> AIUsageSnapshot {
        let cloud = records.filter { $0.tier.isCloud && $0.date >= start }
        return AIUsageSnapshot(cloudCalls: cloud.count, cloudCost: cloud.reduce(0) { $0 + $1.cost })
    }

    /// Une ligne par fonctionnalité, par ordre alphabétique.
    public func summaries() -> [AIFeatureSummary] {
        Dictionary(grouping: records, by: \.feature).map { feature, records in
            AIFeatureSummary(
                feature: feature,
                calls: records.count,
                failures: records.filter { !$0.succeeded }.count,
                callsByTier: Dictionary(grouping: records, by: \.tier).mapValues(\.count),
                averageLatency: records.reduce(.zero) { $0 + $1.latency } / records.count,
                inputTokens: records.reduce(0) { $0 + $1.inputTokens },
                outputTokens: records.reduce(0) { $0 + $1.outputTokens },
                cost: records.reduce(0) { $0 + $1.cost }
            )
        }
        .sorted { $0.feature < $1.feature }
    }
}

public extension AIRouter {
    /// Route la demande puis, si elle tombe sur `tier`, exécute `work` en mesurant l'appel
    /// (niveau, latence, réussite). `nil` si le routeur choisit un autre niveau ou si `work` échoue.
    /// Le budget cloud se compte sur le mois en cours.
    func run<Output>(
        _ request: AIRequest,
        on tier: AITier,
        recorder: (any AIUsageRecording)?,
        now: Date = .now,
        calendar: Calendar = .current,
        isolation: isolated (any Actor)? = #isolation,
        _ work: () async throws -> Output
    ) async -> Output? {
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let usage = await recorder?.snapshot(since: monthStart) ?? AIUsageSnapshot()
        guard case .route(let chosen) = route(request, usage: usage), chosen == tier else { return nil }
        let clock = ContinuousClock()
        let start = clock.now
        let output = try? await work()
        await recorder?.record(AIUsageRecord(
            feature: request.feature, tier: chosen, latency: clock.now - start, succeeded: output != nil
        ))
        return output
    }
}
