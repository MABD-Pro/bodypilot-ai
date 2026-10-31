import BodyPilotCore
import Foundation

/// Pas d'une semaine (du lundi au dimanche selon le calendrier) : moyenne des jours mesurés.
public struct WeekSteps: Sendable, Equatable {
    /// Premier jour de la semaine.
    public var start: Date
    /// Moyenne des jours mesurés, aujourd'hui exclu (journée pas finie).
    public var average: Double
    /// Jours mesurés dans la moyenne.
    public var days: Int
    /// Semaine en cours : la moyenne peut encore bouger.
    public var isCurrent: Bool

    public init(start: Date, average: Double, days: Int, isCurrent: Bool) {
        self.start = start
        self.average = average
        self.days = days
        self.isCurrent = isCurrent
    }
}

/// Ce que montrent les pas sur un mois : moyennes, évolution et jours dans la zone visée.
public struct StepSummary: Sendable, Equatable {
    /// Moyenne des 7 jours précédents.
    public var average7: Double?
    /// Moyenne des 7 jours d'avant (8e au 14e jour) : base de l'évolution.
    public var previous7: Double?
    /// Moyenne des 30 jours précédents.
    public var average30: Double?
    /// Jours mesurés sur les 30 jours précédents.
    public var measuredDays30: Int
    /// Jours à au moins le bas de la zone visée (8 000 avant 60 ans, 6 000 ensuite) sur 30 jours.
    public var daysInZone30: Int
    /// Meilleur jour des 30 derniers, aujourd'hui compris.
    public var best: DailySteps?

    /// Évolution de la moyenne sur 7 jours par rapport aux 7 jours d'avant, en pas par jour.
    public var weeklyChange: Double? {
        guard let average7, let previous7 else { return nil }
        return average7 - previous7
    }
}

/// Historique des pas lus dans Santé, pour l'écran Historique et la rangée Pas de Progresser.
/// Un jour à zéro pas (téléphone resté à la maison, montre au chargeur) n'est jamais compté,
/// comme dans `StepActivity.average`.
public enum StepHistory {
    /// Jours lus dans Santé pour l'historique.
    public static let historyDays = 90
    /// Moins de jours mesurés dans une période : pas de moyenne.
    public static let minimumDays = 3

    /// Jours mesurés des `count` derniers jours, aujourd'hui compris, du plus ancien au plus récent.
    /// Plusieurs valeurs le même jour sont additionnées.
    public static func lastDays(_ days: [DailySteps], count: Int, through date: Date, calendar: Calendar) -> [DailySteps] {
        let today = calendar.startOfDay(for: date)
        guard let start = calendar.date(byAdding: .day, value: -(count - 1), to: today),
              let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return [] }
        let perDay = Dictionary(grouping: days.filter { $0.steps > 0 && $0.day >= start && $0.day < tomorrow }) { calendar.startOfDay(for: $0.day) }
            .mapValues { $0.reduce(0) { $0 + $1.steps } }
        return perDay.map { DailySteps(day: $0.key, steps: $0.value) }.sorted { $0.day < $1.day }
    }

    /// Moyenne des jours mesurés entre `daysAgo.lowerBound` et `daysAgo.upperBound` jours avant
    /// `date` (1 = hier). `nil` sous 3 jours mesurés.
    static func average(_ days: [DailySteps], daysAgo: ClosedRange<Int>, before date: Date, calendar: Calendar) -> (value: Double, days: Int)? {
        let today = calendar.startOfDay(for: date)
        guard let start = calendar.date(byAdding: .day, value: -daysAgo.upperBound, to: today),
              let end = calendar.date(byAdding: .day, value: -(daysAgo.lowerBound - 1), to: today) else { return nil }
        let counted = lastDays(days, count: historyDays * 2, through: date, calendar: calendar).filter { $0.day >= start && $0.day < end }
        guard counted.count >= minimumDays else { return nil }
        return (Double(counted.reduce(0) { $0 + $1.steps }) / Double(counted.count), counted.count)
    }

    public static func summary(_ days: [DailySteps], age: Int, on date: Date, calendar: Calendar) -> StepSummary {
        let zone = StepActivity.zone(age: age)
        let today = calendar.startOfDay(for: date)
        let start30 = calendar.date(byAdding: .day, value: -30, to: today) ?? today
        let past30 = lastDays(days, count: 31, through: date, calendar: calendar).filter { $0.day >= start30 && $0.day < today }
        return StepSummary(
            average7: average(days, daysAgo: 1...7, before: date, calendar: calendar)?.value,
            previous7: average(days, daysAgo: 8...14, before: date, calendar: calendar)?.value,
            average30: average(days, daysAgo: 1...30, before: date, calendar: calendar)?.value,
            measuredDays30: past30.count,
            daysInZone30: past30.filter { $0.steps >= zone.lowerBound }.count,
            best: lastDays(days, count: 30, through: date, calendar: calendar).max { $0.steps < $1.steps }
        )
    }

    /// Moyenne de chaque semaine, la plus récente d'abord. La semaine en cours ne compte pas
    /// aujourd'hui ; une semaine sans au moins 3 jours mesurés est omise.
    public static func weeks(_ days: [DailySteps], on date: Date, calendar: Calendar) -> [WeekSteps] {
        let today = calendar.startOfDay(for: date)
        let currentWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start
        let past = lastDays(days, count: historyDays * 2, through: date, calendar: calendar).filter { $0.day < today }
        let byWeek = Dictionary(grouping: past) { calendar.dateInterval(of: .weekOfYear, for: $0.day)?.start ?? $0.day }
        return byWeek.compactMap { start, days in
            guard days.count >= minimumDays else { return nil }
            return WeekSteps(start: start, average: Double(days.reduce(0) { $0 + $1.steps }) / Double(days.count), days: days.count, isCurrent: start == currentWeek)
        }
        .sorted { $0.start > $1.start }
    }
}
