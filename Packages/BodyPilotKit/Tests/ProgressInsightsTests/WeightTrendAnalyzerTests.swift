import BodyPilotCore
import Foundation
import Testing
@testable import ProgressInsights

private let analyzer = WeightTrendAnalyzer(calendar: utc)
private let today = day(2026, 10, 27)

private func entries(days: Int, start: Double, perDay: Double, noise: [Double] = [0]) -> [WeightEntry] {
    (0..<days).map { index in
        let date = utc.date(byAdding: .day, value: index - days + 1, to: today)!
        return WeightEntry(date: date, kg: start + perDay * Double(index) + noise[index % noise.count])
    }
}

@Test func noEntriesMeansNotEnoughData() {
    let trend = analyzer.trend(of: [], for: makeProfile(), on: today)
    #expect(trend.status == .notEnoughData)
    #expect(trend.currentTrendKg == nil)
}

@Test func lessThanAWeekIsNotATrend() {
    let trend = analyzer.trend(of: entries(days: 5, start: 90, perDay: -0.1), for: makeProfile(), on: today)
    #expect(trend.status == .notEnoughData)
    #expect(trend.currentTrendKg != nil)
}

@Test func steadyLossIsOnTrackDespiteNoise() throws {
    // −0,1 kg/jour soit −0,7 kg/semaine, avec ±0,6 kg de bruit (eau, sel).
    let trend = analyzer.trend(of: entries(days: 21, start: 90, perDay: -0.1, noise: [0.6, -0.4, 0.2, -0.6, 0.3]), for: makeProfile(), on: today)
    #expect(trend.status == .onTrack)
    let weekly = try #require(trend.weeklyChangeKg)
    #expect(abs(weekly + 0.7) < 0.15)
    #expect(trend.estimatedTargetDate != nil)
}

@Test func lossAboveOnePercentPerWeekIsTooFast() {
    let trend = analyzer.trend(of: entries(days: 14, start: 90, perDay: -0.2), for: makeProfile(), on: today)
    #expect(trend.status == .tooFast)
}

@Test func flatWeightIsStalled() {
    let trend = analyzer.trend(of: entries(days: 14, start: 90, perDay: 0, noise: [0.3, -0.3]), for: makeProfile(), on: today)
    #expect(trend.status == .stalled)
}

@Test func gainWhileLosingFatIsWrongDirection() {
    let trend = analyzer.trend(of: entries(days: 14, start: 90, perDay: 0.08), for: makeProfile(), on: today)
    #expect(trend.status == .wrongDirection)
}

@Test func keepsLastMeasureOfEachDay() {
    let morning = WeightEntry(date: day(2026, 10, 27), kg: 90)
    let evening = WeightEntry(date: day(2026, 10, 27).addingTimeInterval(10 * 3600), kg: 91.2)
    let trend = analyzer.trend(of: [evening, morning], for: makeProfile(), on: day(2026, 10, 28))
    #expect(trend.points.count == 1)
    #expect(trend.points.first?.measuredKg == 91.2)
}

@Test func ignoresFutureEntries() {
    let future = WeightEntry(date: day(2026, 11, 5), kg: 70)
    let trend = analyzer.trend(of: entries(days: 3, start: 90, perDay: 0) + [future], for: makeProfile(), on: today)
    #expect(trend.points.allSatisfy { $0.measuredKg == 90 })
}

@Test func bodyCompositionComparesFirstAndLastWeekAverages() throws {
    // Gras de 30 à 29 % et masse maigre de 80 à 80,5 kg sur 4 semaines, avec une mesure bruitée.
    let entries = (0..<28).map { index in
        BodyCompositionEntry(
            date: utc.date(byAdding: .day, value: index - 27, to: today)!,
            fatPercent: 30 - Double(index) / 27 + (index == 27 ? 1.5 : 0),
            leanKg: 80 + 0.5 * Double(index) / 27
        )
    }
    let change = try #require(analyzer.compositionChange(of: entries, on: today))
    // Le pic du dernier jour est lissé par la moyenne de la semaine.
    #expect(try #require(change.fatChangePoints) < -0.5)
    #expect(try #require(change.leanChangeKg) > 0.3)
}

@Test func bodyCompositionNeedsTwoWeeksForATrend() throws {
    let entries = (0..<10).map { index in
        BodyCompositionEntry(date: utc.date(byAdding: .day, value: index - 9, to: today)!, fatPercent: 30)
    }
    let change = try #require(analyzer.compositionChange(of: entries, on: today))
    #expect(change.fatPercent == 30)
    #expect(change.fatChangePoints == nil)
    #expect(analyzer.compositionChange(of: [], on: today) == nil)
}
