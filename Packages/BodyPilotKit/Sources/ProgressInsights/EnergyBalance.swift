import BodyPilotCore
import Foundation

/// Calories mangées un jour donné, quand les quatre repas sont notés.
public struct IntakeDay: Sendable, Equatable {
    public var day: Date
    public var kcal: Double

    public init(day: Date, kcal: Double) {
        self.day = day
        self.kcal = kcal
    }
}

/// Dépense réelle sur les 3 dernières semaines : apport moyen des jours complets, moins
/// l'énergie de la variation de poids (pente des pesées).
public enum EnergyBalance {
    public static let windowDays = 21
    /// Moins de jours complets : l'équation seule.
    public static let minimumDays = 10
    /// Énergie d'un kilo de poids perdu ou pris, en moyenne sur quelques semaines. Approximation :
    /// la composition de ce qui est perdu varie (Hall et al., 2011).
    public static let kcalPerKg = 7_700.0
    static let minimumWeighings = 6
    static let minimumSpanDays = 14.0

    /// `nil` sans assez de jours complets ou de pesées étalées sur au moins deux semaines.
    public static func measured(intakes: [IntakeDay], weights: [WeightEntry], on date: Date, calendar: Calendar = .current) -> MeasuredExpenditure? {
        let end = calendar.startOfDay(for: date)
        guard let start = calendar.date(byAdding: .day, value: -windowDays, to: end) else { return nil }
        let days = intakes.filter { $0.day >= start && $0.day < end && $0.kcal > 0 }
        guard days.count >= minimumDays else { return nil }
        let window = weights.filter { $0.date >= start && $0.date < end }
        guard window.count >= minimumWeighings, let slope = slopePerDay(window, from: start) else { return nil }
        let intake = days.map(\.kcal).reduce(0, +) / Double(days.count)
        return MeasuredExpenditure(kcal: intake - slope * kcalPerKg, days: days.count, weeklyChangeKg: slope * 7)
    }

    /// Pente des pesées (kg/jour) par moindres carrés.
    static func slopePerDay(_ weights: [WeightEntry], from start: Date) -> Double? {
        let points = weights.map { (x: $0.date.timeIntervalSince(start) / 86_400, y: $0.kg) }
        guard let first = points.map(\.x).min(), let last = points.map(\.x).max(), last - first >= minimumSpanDays else { return nil }
        let n = Double(points.count)
        let meanX = points.map(\.x).reduce(0, +) / n
        let meanY = points.map(\.y).reduce(0, +) / n
        let covariance = points.reduce(0) { $0 + ($1.x - meanX) * ($1.y - meanY) }
        let variance = points.reduce(0) { $0 + ($1.x - meanX) * ($1.x - meanX) }
        return variance > 0 ? covariance / variance : nil
    }
}
