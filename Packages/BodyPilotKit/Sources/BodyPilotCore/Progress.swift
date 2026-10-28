import Foundation

public struct WeightEntry: Sendable, Equatable, Codable {
    public var date: Date
    public var kg: Double

    public init(date: Date, kg: Double) {
        self.date = date
        self.kg = kg
    }
}

/// Tour de taille, mesuré au niveau du nombril. En recomposition, il bouge quand le poids stagne.
public struct WaistEntry: Sendable, Equatable, Codable {
    public var date: Date
    public var cm: Double

    public init(date: Date, cm: Double) {
        self.date = date
        self.cm = cm
    }
}

/// Composition corporelle lue dans Santé (balance à impédance) : taux de gras et masse maigre.
/// Une mesure isolée est peu fiable ; seule la tendance sur plusieurs semaines compte.
public struct BodyCompositionEntry: Sendable, Equatable, Codable {
    public var date: Date
    public var fatPercent: Double?
    public var leanKg: Double?

    public init(date: Date, fatPercent: Double? = nil, leanKg: Double? = nil) {
        self.date = date
        self.fatPercent = fatPercent
        self.leanKg = leanKg
    }
}

/// Composition récente (moyenne de la dernière semaine de mesures) et variation sur 4 semaines.
public struct BodyCompositionChange: Sendable, Equatable {
    public var fatPercent: Double?
    /// Variation du taux de gras, en points ; `nil` sans deux semaines de recul.
    public var fatChangePoints: Double?
    public var leanKg: Double?
    public var leanChangeKg: Double?

    public init(fatPercent: Double?, fatChangePoints: Double?, leanKg: Double?, leanChangeKg: Double?) {
        self.fatPercent = fatPercent
        self.fatChangePoints = fatChangePoints
        self.leanKg = leanKg
        self.leanChangeKg = leanChangeKg
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
    /// Variation récente du tour de taille (cm), ou `nil` sans assez de mesures.
    func waistChange(of entries: [WaistEntry], on date: Date) -> Double?
    /// Taux de gras et masse maigre récents, et leur variation sur 4 semaines ; `nil` sans mesure.
    func compositionChange(of entries: [BodyCompositionEntry], on date: Date) -> BodyCompositionChange?
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
