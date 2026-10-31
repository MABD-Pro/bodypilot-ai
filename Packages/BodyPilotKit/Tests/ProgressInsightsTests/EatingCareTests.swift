import BodyPilotCore
import Foundation
import Testing
@testable import ProgressInsights

private let today = day(2026, 10, 30)
private let flat = WeightTrend(points: [], currentTrendKg: 80, weeklyChangeKg: -0.4, status: .onTrack, estimatedTargetDate: nil)

private func daysAgo(_ count: Int) -> Date { utc.date(byAdding: .day, value: -count, to: today)! }

private func signals(
    days: [EatingCareDay] = [],
    trend: WeightTrend = flat,
    weighIns: [Date] = [],
    distress: [Date] = [],
    purging: [Date] = []
) -> Set<EatingCareSignal> {
    EatingCare.signals(days: days, targetKcal: 2_000, floorKcal: 1_500, trend: trend, manualWeighIns: weighIns, distressDays: distress, purgingDays: purging, on: today, calendar: utc)
}

@Test func nothingToSayOnOrdinaryDays() {
    let days = (0..<14).map { EatingCareDay(day: daysAgo($0), completeKcal: 1_900, skippedMeals: $0 == 3 ? 1 : 0) }
    #expect(signals(days: days, weighIns: [daysAgo(1), daysAgo(8)]).isEmpty)
}

@Test func repeatedRestrictionIsNoticed() {
    // Sous 70 % de 2 000 = 1 400, et le plancher est 1 500 : 1 450 compte comme restriction.
    let days = (0..<5).map { EatingCareDay(day: daysAgo($0 * 2), completeKcal: 1_450) }
    #expect(signals(days: days) == [.restriction])
    // Quatre jours seulement, ou hors des 14 jours : rien.
    #expect(signals(days: Array(days.prefix(4))).isEmpty)
    #expect(signals(days: (0..<5).map { EatingCareDay(day: daysAgo(15 + $0), completeKcal: 1_000) }).isEmpty)
}

@Test func skippedMealsAddUp() {
    let days = (0..<3).map { EatingCareDay(day: daysAgo($0), skippedMeals: 2) }
    #expect(signals(days: days) == [.skippedMeals])
}

@Test func rapidLossAndFrequentWeighing() {
    let fast = WeightTrend(points: [], currentTrendKg: 80, weeklyChangeKg: -0.9, status: .tooFast, estimatedTargetDate: nil)
    #expect(signals(trend: fast) == [.rapidLoss])
    let weighIns = (0..<3).flatMap { offset in (0..<3).map { utc.date(byAdding: .hour, value: $0 * 3, to: daysAgo(offset))! } }
    #expect(signals(weighIns: weighIns) == [.frequentWeighing])
}

@Test func wordsCountOnlyOnSeveralDaysExceptPurging() {
    #expect(signals(distress: [daysAgo(1)]).isEmpty)
    #expect(signals(distress: [daysAgo(1), daysAgo(4)]) == [.distressWords])
    #expect(signals(purging: [daysAgo(2)]) == [.purging])
}

@Test func mentionsAreRecognised() {
    #expect(EatingCare.mention(in: "Je me suis fait vomir après le dîner") == .purging)
    #expect(EatingCare.mention(in: "Je culpabilise d'avoir mangé ce gâteau") == .distress)
    #expect(EatingCare.mention(in: "Demain je vais compenser") == .distress)
    #expect(EatingCare.mention(in: "Séance faite, pizza ce soir") == nil)
}

@Test func purgingChangesTheOpening() {
    #expect(EatingCareText.paragraphs(for: [.purging]).first == EatingCareText.purgingOpening)
    #expect(EatingCareText.paragraphs(for: [.restriction]).first == EatingCareText.opening)
}

@Test func aDeficitPauseKeepsTheBalance() {
    var profile = makeProfile()
    profile.deficitPauseUntil = utc.date(byAdding: .day, value: 28, to: today)
    #expect(profile.isOnDeficitPause(on: today))
    #expect(BodyPhase.resolve(for: profile, currentWeightKg: 90, waistCm: nil, fatPercent: nil, on: today, calendar: utc) == .maintenance)
}
