import Foundation

/// Une mesure datée lue dans Santé (VFC en ms, pouls au repos en battements par minute).
public struct DatedValue: Sendable, Equatable, Codable {
    public var date: Date
    public var value: Double

    public init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }
}

/// Récupération de la semaine d'après la VFC et le pouls au repos, comparés à la normale de la
/// personne. Volontairement prudent (voir la revue « VFC et pouls au repos ») : seule une moyenne
/// sur 7 jours compte, jamais la mesure du jour (Plews 2014) ; la zone normale est la moyenne
/// ± 0,5 écart-type des 28 derniers jours (Javaloyes 2019) ; la VFC est comparée en logarithme.
public struct RecoveryStatus: Sendable, Equatable {
    /// VFC moyenne des 7 derniers jours sous la zone normale.
    public var hrvLow: Bool
    /// Pouls au repos moyen des 7 derniers jours au-dessus de la zone normale.
    public var restingHigh: Bool

    public init(hrvLow: Bool, restingHigh: Bool) {
        self.hrvLow = hrvLow
        self.restingHigh = restingHigh
    }

    /// Les deux signaux ensemble : le seul cas où le coach adoucit le cardio.
    public var isLow: Bool { hrvLow && restingHigh }
}

public enum RecoverySignal {
    public static let baselineDays = 28
    public static let recentDays = 7
    /// Jours mesurés nécessaires sur les 7 derniers jours (Plews 2014 : au moins 3 par semaine).
    public static let minimumRecentDays = 3
    /// Jours mesurés nécessaires sur 28 jours pour connaître la normale.
    public static let minimumBaselineDays = 14
    /// Largeur de la zone normale, en écarts-types autour de la moyenne.
    public static let normalRangeSD = 0.5

    /// `nil` : pas assez de mesures pour l'un des deux signaux, le coach n'en tient pas compte.
    public static func status(hrv: [DatedValue], restingHeartRate: [DatedValue], on date: Date, calendar: Calendar = .current) -> RecoveryStatus? {
        guard let hrvShift = shift(of: hrv.filter { $0.value > 0 }.map { DatedValue(date: $0.date, value: log($0.value)) }, on: date, calendar: calendar),
              let restingShift = shift(of: restingHeartRate.filter { $0.value > 0 }, on: date, calendar: calendar) else { return nil }
        return RecoveryStatus(hrvLow: hrvShift < -normalRangeSD, restingHigh: restingShift > normalRangeSD)
    }

    /// Écart de la moyenne des 7 derniers jours à la moyenne des 28 jours, en écarts-types.
    /// Plusieurs mesures le même jour comptent pour une : leur moyenne.
    static func shift(of values: [DatedValue], on date: Date, calendar: Calendar) -> Double? {
        let today = calendar.startOfDay(for: date)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
              let baselineStart = calendar.date(byAdding: .day, value: -(baselineDays - 1), to: today),
              let recentStart = calendar.date(byAdding: .day, value: -(recentDays - 1), to: today) else { return nil }
        let perDay = Dictionary(grouping: values.filter { $0.date >= baselineStart && $0.date < tomorrow }) { calendar.startOfDay(for: $0.date) }
            .mapValues { $0.reduce(0) { $0 + $1.value } / Double($0.count) }
        let recent = perDay.filter { $0.key >= recentStart }.map(\.value)
        let baseline = Array(perDay.values)
        guard baseline.count >= minimumBaselineDays, recent.count >= minimumRecentDays else { return nil }
        let mean = baseline.reduce(0, +) / Double(baseline.count)
        let variance = baseline.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(baseline.count - 1)
        let sd = variance.squareRoot()
        guard sd > 0 else { return 0 }
        return (recent.reduce(0, +) / Double(recent.count) - mean) / sd
    }
}
