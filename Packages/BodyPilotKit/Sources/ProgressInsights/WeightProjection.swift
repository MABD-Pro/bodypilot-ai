import BodyPilotCore
import Foundation

/// « Et si ? » : un changement simulé, ajouté au rythme mesuré.
public struct ProjectionScenario: Sendable, Hashable {
    /// Calories par jour en plus (positif) ou en moins (négatif).
    public var kcalPerDay: Int
    /// Pas par jour en plus de l'habitude.
    public var extraSteps: Int

    public init(kcalPerDay: Int = 0, extraSteps: Int = 0) {
        self.kcalPerDay = kcalPerDay
        self.extraSteps = extraSteps
    }

    public static let none = ProjectionScenario()
    public var isNone: Bool { self == .none }

    /// Bornes des réglages : au-delà de 500 kcal de moins par jour, le coach ne suit plus
    /// (protéines et récupération), et 6 000 pas en plus, c'est déjà une heure de marche.
    public static let kcalRange = -500...300
    public static let kcalStep = 50
    public static let stepsRange = 0...6_000
    public static let stepsStep = 1_000
}

/// Quand l'objectif de poids sera atteint, en fourchette plutôt qu'en date unique : la pente
/// des pesées est incertaine (eau, sel, cycle) et une date précise donnerait une fausse certitude.
public struct WeightProjection: Sendable, Equatable {
    public var targetKg: Double
    /// Rythme retenu, en kg par semaine (négatif = perte), du plus rapide au plus lent.
    public var fastWeeklyKg: Double
    public var slowWeeklyKg: Double
    /// Au rythme le plus rapide de la fourchette.
    public var earliest: Date
    /// Au rythme le plus lent ; `nil` si, à ce rythme, l'objectif n'est pas atteint en 2 ans.
    public var latest: Date?
}

public enum WeightProjector {
    /// Au-delà, la projection n'a plus de sens.
    static let horizonWeeks = 104.0
    /// Marge minimale autour de la pente : ±25 % (choix BodyPilot, l'adhésion varie d'une
    /// semaine à l'autre même quand les pesées sont régulières).
    static let minimumMarginRatio = 0.25
    static let minimumMarginKg = 0.1
    /// Coût net de la marche : environ 0,5 kcal par kg et par km, soit ~0,0004 kcal par kg et
    /// par pas (environ 1 300 pas au km). Ordre de grandeur, la foulée varie.
    static let kcalPerStepPerKg = 0.0004
    /// Une partie du déficit simulé est compensée (faim, mouvements spontanés) : on n'en
    /// compte que 80 % (choix BodyPilot, prudent ; Hall et al., 2011, sur l'adaptation).
    static let scenarioEfficiency = 0.8

    /// - Parameters:
    ///   - entries: pesées (une par jour suffit, les autres sont ignorées).
    ///   - trend: tendance déjà calculée (poids lissé et pente).
    /// - Returns: `nil` sans objectif, sans tendance, ou si le rythme mesuré éloigne de l'objectif.
    public static func project(
        entries: [WeightEntry],
        trend: WeightTrend,
        targetKg: Double?,
        scenario: ProjectionScenario = .none,
        on date: Date,
        calendar: Calendar = .current
    ) -> WeightProjection? {
        guard let target = targetKg, let current = trend.currentTrendKg, let measured = trend.weeklyChangeKg else { return nil }
        let gap = target - current
        guard abs(gap) >= 0.5 else { return nil }
        let weekly = measured + scenarioWeeklyKg(scenario, weightKg: current)
        let margin = max(slopeStandardError(entries, on: date, calendar: calendar) ?? 0, abs(weekly) * minimumMarginRatio, minimumMarginKg)
        // Dans le sens de l'objectif : la plus grande vitesse d'abord.
        let direction: Double = gap < 0 ? -1 : 1
        let fast = weekly + direction * margin
        let slow = weekly - direction * margin
        func arrival(_ rate: Double) -> Date? {
            guard rate * direction > 0 else { return nil }
            let weeks = gap / rate
            guard weeks <= horizonWeeks else { return nil }
            return calendar.date(byAdding: .day, value: Int((weeks * 7).rounded(.up)), to: date)
        }
        // Le rythme central doit déjà aller vers l'objectif.
        guard weekly * direction > 0, let earliest = arrival(fast) else { return nil }
        return WeightProjection(targetKg: target, fastWeeklyKg: fast, slowWeeklyKg: slow, earliest: earliest, latest: arrival(slow))
    }

    /// Effet d'un scénario sur le rythme, en kg par semaine.
    public static func scenarioWeeklyKg(_ scenario: ProjectionScenario, weightKg: Double) -> Double {
        let kcal = Double(scenario.kcalPerDay) - Double(scenario.extraSteps) * kcalPerStepPerKg * weightKg
        return kcal * 7 / EnergyBalance.kcalPerKg * scenarioEfficiency
    }

    /// Erreur type de la pente (kg par semaine) sur la fenêtre de la tendance.
    static func slopeStandardError(_ entries: [WeightEntry], on date: Date, calendar: Calendar) -> Double? {
        let start = calendar.date(byAdding: .day, value: -WeightTrendAnalyzer.rateWindowDays, to: date) ?? date
        var byDay: [Date: Double] = [:]
        for entry in entries.sorted(by: { $0.date < $1.date }) where entry.date >= start && entry.date <= date {
            byDay[calendar.startOfDay(for: entry.date)] = entry.kg
        }
        let points = byDay.sorted { $0.key < $1.key }
        guard points.count >= 4, let first = points.first?.key else { return nil }
        let xs = points.map { $0.key.timeIntervalSince(first) / 86_400 }
        let ys = points.map(\.value)
        let n = Double(points.count)
        let meanX = xs.reduce(0, +) / n
        let meanY = ys.reduce(0, +) / n
        let sxx = xs.reduce(0) { $0 + ($1 - meanX) * ($1 - meanX) }
        guard sxx > 0 else { return nil }
        let slope = zip(xs, ys).reduce(0) { $0 + ($1.0 - meanX) * ($1.1 - meanY) } / sxx
        let residuals = zip(xs, ys).reduce(0) { sum, point in
            let fitted = meanY + slope * (point.0 - meanX)
            return sum + (point.1 - fitted) * (point.1 - fitted)
        }
        return (residuals / (n - 2) / sxx).squareRoot() * 7
    }
}

extension WeightProjection {
    /// « entre mars et mai 2027 », « en mars 2027 », « à partir de mars 2027 ».
    public func rangeText(locale: Locale = Locale(identifier: "fr_FR"), calendar: Calendar = .current) -> String {
        let monthYear = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).month(.wide).year()
        let month = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).month(.wide)
        guard let latest else { return "pas avant \(earliest.formatted(monthYear))" }
        let sameMonth = calendar.isDate(earliest, equalTo: latest, toGranularity: .month)
        if sameMonth { return "en \(earliest.formatted(monthYear))" }
        let sameYear = calendar.isDate(earliest, equalTo: latest, toGranularity: .year)
        return "entre \(earliest.formatted(sameYear ? month : monthYear)) et \(latest.formatted(monthYear))"
    }
}
