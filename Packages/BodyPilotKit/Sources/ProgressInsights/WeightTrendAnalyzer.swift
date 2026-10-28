import BodyPilotCore
import Foundation

/// Tendance du poids, calculée localement.
///
/// Le poids du jour varie de ±1 kg selon l'eau et le sel : on lisse par moyenne mobile exponentielle,
/// puis on estime la vitesse par régression linéaire sur les dernières semaines.
/// Module nommé ProgressInsights pour ne pas entrer en conflit avec `Foundation.Progress`.
public struct WeightTrendAnalyzer: ProgressAnalyzing {
    public var calendar: Calendar

    /// Poids de la dernière mesure dans la moyenne lissée.
    static let smoothing = 0.25
    /// Fenêtre de calcul de la vitesse.
    static let rateWindowDays = 21
    /// Il faut au moins une semaine de recul et 3 mesures pour parler de tendance.
    static let minimumSpanDays = 7
    static let minimumEntries = 3
    /// Points renvoyés pour le graphique.
    static let chartDays = 30

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func trend(of entries: [WeightEntry], for profile: UserProfile, on date: Date) -> WeightTrend {
        let daily = lastEntryPerDay(entries.filter { $0.date <= date })
        guard let first = daily.first else {
            return WeightTrend(points: [], currentTrendKg: nil, weeklyChangeKg: nil, status: .notEnoughData, estimatedTargetDate: nil)
        }

        var points: [TrendPoint] = []
        var smoothed = first.kg
        for entry in daily {
            smoothed += Self.smoothing * (entry.kg - smoothed)
            points.append(TrendPoint(date: entry.date, measuredKg: entry.kg, trendKg: smoothed))
        }

        let chartStart = calendar.date(byAdding: .day, value: -Self.chartDays, to: date) ?? date
        let rateStart = calendar.date(byAdding: .day, value: -Self.rateWindowDays, to: date) ?? date
        let recent = daily.filter { $0.date >= rateStart }
        let weekly = weeklySlope(of: recent)
        let status = weekly.map { classify(weeklyChange: $0, weightKg: smoothed, goal: profile.goal) } ?? .notEnoughData

        return WeightTrend(
            points: points.filter { $0.date >= chartStart },
            currentTrendKg: smoothed,
            weeklyChangeKg: weekly,
            status: status,
            estimatedTargetDate: weekly.flatMap {
                targetDate(from: smoothed, target: profile.targetWeightKg, weeklyChange: $0, status: status, today: date)
            }
        )
    }

    /// Vitesse attendue selon l'objectif, en part du poids par semaine.
    func classify(weeklyChange: Double, weightKg: Double, goal: Goal) -> ProgressStatus {
        let ratio = weeklyChange / weightKg
        switch goal {
        case .loseFat, .recomposition:
            if ratio < -0.01 { return .tooFast }
            if ratio <= -0.001 { return .onTrack }
            if ratio < 0.002 { return .stalled }
            return .wrongDirection
        case .buildMuscle:
            if ratio > 0.005 { return .tooFast }
            if ratio >= 0.0005 { return .onTrack }
            if ratio > -0.002 { return .stalled }
            return .wrongDirection
        case .maintain:
            return abs(ratio) <= 0.003 ? .onTrack : .wrongDirection
        }
    }

    /// Variation du tour de taille sur les 4 dernières semaines (cm), si deux mesures sont
    /// espacées d'au moins 10 jours. Négatif = la taille baisse.
    public func waistChange(of entries: [WaistEntry], on date: Date) -> Double? {
        let start = calendar.date(byAdding: .day, value: -28, to: date) ?? date
        let recent = entries.filter { $0.date >= start && $0.date <= date }.sorted { $0.date < $1.date }
        guard let first = recent.first, let last = recent.last,
              last.date.timeIntervalSince(first.date) >= 10 * 86_400
        else { return nil }
        return last.cm - first.cm
    }

    /// Moyenne de la première et de la dernière semaine de mesures sur 4 semaines : une mesure
    /// d'impédance varie avec l'hydratation, la moyenne en gomme une partie.
    public func compositionChange(of entries: [BodyCompositionEntry], on date: Date) -> BodyCompositionChange? {
        let start = calendar.date(byAdding: .day, value: -28, to: date) ?? date
        let recent = entries.filter { $0.date >= start && $0.date <= date }.sorted { $0.date < $1.date }
        guard let first = recent.first, let last = recent.last else { return nil }
        let week: TimeInterval = 7 * 86_400
        let opening = recent.filter { $0.date.timeIntervalSince(first.date) < week }
        let closing = recent.filter { last.date.timeIntervalSince($0.date) < week }
        let spansTwoWeeks = last.date.timeIntervalSince(first.date) >= 14 * 86_400

        func mean(_ list: [BodyCompositionEntry], _ value: KeyPath<BodyCompositionEntry, Double?>) -> Double? {
            let values = list.compactMap { $0[keyPath: value] }
            return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
        }
        func change(_ value: KeyPath<BodyCompositionEntry, Double?>) -> Double? {
            guard spansTwoWeeks, let now = mean(closing, value), let then = mean(opening, value) else { return nil }
            return now - then
        }
        let fat = mean(closing, \.fatPercent)
        let lean = mean(closing, \.leanKg)
        guard fat != nil || lean != nil else { return nil }
        return BodyCompositionChange(fatPercent: fat, fatChangePoints: change(\.fatPercent), leanKg: lean, leanChangeKg: change(\.leanKg))
    }

    /// Pente de la régression linéaire, en kg par semaine.
    func weeklySlope(of entries: [WeightEntry]) -> Double? {
        guard entries.count >= Self.minimumEntries,
              let first = entries.first, let last = entries.last,
              last.date.timeIntervalSince(first.date) >= Double(Self.minimumSpanDays) * 86_400 - 3_600
        else { return nil }

        let xs = entries.map { $0.date.timeIntervalSince(first.date) / 86_400 }
        let ys = entries.map(\.kg)
        let n = Double(entries.count)
        let meanX = xs.reduce(0, +) / n
        let meanY = ys.reduce(0, +) / n
        var covariance = 0.0
        var variance = 0.0
        for (x, y) in zip(xs, ys) {
            covariance += (x - meanX) * (y - meanY)
            variance += (x - meanX) * (x - meanX)
        }
        guard variance > 0 else { return nil }
        return covariance / variance * 7
    }

    private func targetDate(from current: Double, target: Double?, weeklyChange: Double, status: ProgressStatus, today: Date) -> Date? {
        guard let target, status == .onTrack || status == .tooFast, weeklyChange != 0 else { return nil }
        let weeks = (target - current) / weeklyChange
        guard weeks > 0, weeks < 104 else { return nil }
        return calendar.date(byAdding: .day, value: Int((weeks * 7).rounded()), to: today)
    }

    private func lastEntryPerDay(_ entries: [WeightEntry]) -> [WeightEntry] {
        var byDay: [Date: WeightEntry] = [:]
        for entry in entries.sorted(by: { $0.date < $1.date }) {
            byDay[calendar.startOfDay(for: entry.date)] = entry
        }
        return byDay.values.sorted { $0.date < $1.date }
    }
}
