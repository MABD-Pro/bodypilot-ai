import Foundation

public struct WeightEntry: Sendable, Equatable, Codable {
    public var date: Date
    public var kg: Double

    public init(date: Date, kg: Double) {
        self.date = date
        self.kg = kg
    }
}

public struct TrendPoint: Sendable, Equatable {
    public var date: Date
    public var measuredKg: Double
    /// Poids lissé, qui gomme les variations d'eau d'un jour à l'autre.
    public var trendKg: Double

    public init(date: Date, measuredKg: Double, trendKg: Double) {
        self.date = date
        self.measuredKg = measuredKg
        self.trendKg = trendKg
    }
}

public enum ProgressStatus: Sendable, Equatable {
    case notEnoughData
    case onTrack
    /// Perte ou prise trop rapide : risque pour la masse musculaire ou la santé.
    case tooFast
    case stalled
    case wrongDirection
}

public struct WeightTrend: Sendable, Equatable {
    public var points: [TrendPoint]
    public var currentTrendKg: Double?
    /// Variation hebdomadaire de la tendance, en kg (négatif = perte).
    public var weeklyChangeKg: Double?
    public var status: ProgressStatus
    public var estimatedTargetDate: Date?

    public init(
        points: [TrendPoint],
        currentTrendKg: Double?,
        weeklyChangeKg: Double?,
        status: ProgressStatus,
        estimatedTargetDate: Date?
    ) {
        self.points = points
        self.currentTrendKg = currentTrendKg
        self.weeklyChangeKg = weeklyChangeKg
        self.status = status
        self.estimatedTargetDate = estimatedTargetDate
    }
}

public protocol ProgressAnalyzing: Sendable {
    func trend(of entries: [WeightEntry], for profile: UserProfile, on date: Date) -> WeightTrend
}

/// Pesée lue dans une source externe (Santé, balance connectée).
public struct WeightSample: Sendable, Equatable, Codable {
    /// Identifiant stable côté source, pour ne jamais importer deux fois la même mesure.
    public var id: String
    public var date: Date
    public var kg: Double

    public init(id: String, date: Date, kg: Double) {
        self.id = id
        self.date = date
        self.kg = kg
    }
}
