import Foundation

/// Pas d'une journée, lus dans Santé (iPhone ou Apple Watch).
public struct DailySteps: Sendable, Equatable {
    public var day: Date
    public var steps: Int

    public init(day: Date, steps: Int) {
        self.day = day
        self.steps = steps
    }
}

/// Les pas mesurés remplacent le niveau d'activité déclaré, et donnent un objectif qui monte
/// doucement vers la zone où la mortalité cesse de baisser (Paluch et al., 2022 : 8 000 à
/// 10 000 pas avant 60 ans, 6 000 à 8 000 ensuite).
public enum StepActivity {
    /// Moyenne sur les 14 jours précédents, aujourd'hui exclu (journée pas finie).
    public static let windowDays = 14
    /// Moins de jours mesurés : le niveau déclaré reste.
    public static let minimumDays = 7
    /// Hausse de l'objectif au-dessus de la moyenne récente (choix BodyPilot).
    public static let stepIncrease = 1_000

    /// Moyenne des jours mesurés avant ce jour. Un jour sans aucun pas (iPhone resté à la maison,
    /// montre au chargeur) est écarté. `nil` sous 7 jours mesurés.
    public static func average(_ days: [DailySteps], before date: Date, calendar: Calendar) -> Double? {
        let end = calendar.startOfDay(for: date)
        guard let start = calendar.date(byAdding: .day, value: -windowDays, to: end) else { return nil }
        let counted = days.filter { $0.steps > 0 && $0.day >= start && $0.day < end }
        guard counted.count >= minimumDays else { return nil }
        return Double(counted.map(\.steps).reduce(0, +)) / Double(counted.count)
    }

    /// Zone visée selon l'âge.
    public static func zone(age: Int) -> ClosedRange<Int> {
        age >= 60 ? 6_000...8_000 : 8_000...10_000
    }

    /// Objectif du jour : la moyenne récente + 1 000, arrondi aux 500 du dessus, sans dépasser le
    /// haut de la zone ; sans moyenne, le bas de la zone.
    public static func goal(averageSteps: Double?, age: Int) -> Int {
        let zone = zone(age: age)
        guard let averageSteps else { return zone.lowerBound }
        let raised = Int(((averageSteps + Double(stepIncrease)) / 500).rounded(.up)) * 500
        return min(raised, zone.upperBound)
    }
}

extension ActivityLevel {
    /// Niveau correspondant à une moyenne de pas, d'après les paliers de Tudor-Locke et Bassett
    /// (2004) : moins de 5 000 sédentaire, 5 000 à 7 499 peu actif, 7 500 à 9 999 assez actif,
    /// 10 000 et plus actif.
    public init(averageSteps: Double) {
        switch averageSteps {
        case ..<5_000: self = .sedentary
        case ..<7_500: self = .light
        case ..<10_000: self = .moderate
        default: self = .active
        }
    }
}
