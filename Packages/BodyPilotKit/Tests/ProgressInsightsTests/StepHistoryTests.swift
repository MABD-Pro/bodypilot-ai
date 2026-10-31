import BodyPilotCore
import Foundation
import Testing
@testable import ProgressInsights

/// Samedi.
private let today = day(2026, 10, 31)

private func steps(_ counts: [Int]) -> [DailySteps] {
    // counts[0] = aujourd'hui, counts[1] = hier…
    counts.enumerated().map { daysAgo, count in
        DailySteps(day: utc.startOfDay(for: utc.date(byAdding: .day, value: -daysAgo, to: today)!), steps: count)
    }
}

@Test func lastDaysKeepsMeasuredDaysInOrder() {
    let days = StepHistory.lastDays(steps([3_000, 0, 7_000, 8_000, 9_000]), count: 4, through: today, calendar: utc)
    // Aujourd'hui compris, le jour à zéro écarté, le 5e jour hors fenêtre.
    #expect(days.map(\.steps) == [8_000, 7_000, 3_000])
}

@Test func summaryAveragesExcludeTodayAndEmptyDays() throws {
    // Aujourd'hui 2 000 (pas fini), puis 7 jours à 6 000 dont un à zéro, puis 7 jours à 5 000.
    let counts: [Int] = [2_000] + [6_000, 6_000, 0, 6_000, 6_000, 6_000, 6_000] + Array(repeating: 5_000, count: 7)
    let summary = StepHistory.summary(steps(counts), age: 35, on: today, calendar: utc)
    #expect(summary.average7 == 6_000)
    #expect(summary.previous7 == 5_000)
    #expect(summary.weeklyChange == 1_000)
    #expect(summary.measuredDays30 == 13)
    let expected30: Double = (6_000 * 6 + 5_000 * 7) / 13
    let average30 = try #require(summary.average30)
    #expect(abs(average30 - expected30) < 0.01)
}

@Test func daysInZoneDependOnAge() {
    let counts: [Int] = [0] + [9_000, 7_000, 6_500, 8_000, 5_000]
    #expect(StepHistory.summary(steps(counts), age: 35, on: today, calendar: utc).daysInZone30 == 2)
    #expect(StepHistory.summary(steps(counts), age: 65, on: today, calendar: utc).daysInZone30 == 4)
}

@Test func bestDayIncludesToday() {
    let summary = StepHistory.summary(steps([12_000, 9_000, 8_000]), age: 35, on: today, calendar: utc)
    #expect(summary.best?.steps == 12_000)
}

@Test func tooFewDaysGiveNoAverage() {
    let summary = StepHistory.summary(steps([4_000, 6_000, 7_000]), age: 35, on: today, calendar: utc)
    #expect(summary.average7 == nil)
    #expect(summary.weeklyChange == nil)
}

@Test func weeksAreMondayToSundayMostRecentFirst() {
    // Samedi 31 : semaine en cours du lundi 26 au vendredi 30 (5 jours), aujourd'hui exclu.
    let counts: [Int] = [1_000] + Array(repeating: 6_000, count: 5) + Array(repeating: 8_000, count: 7) + [4_000, 4_000]
    let weeks = StepHistory.weeks(steps(counts), on: today, calendar: utc)
    #expect(weeks.count == 2)
    #expect(weeks[0].isCurrent)
    #expect(weeks[0].start == day(2026, 10, 26).addingTimeInterval(-8 * 3_600))
    #expect(weeks[0].average == 6_000)
    #expect(weeks[0].days == 5)
    #expect(!weeks[1].isCurrent)
    #expect(weeks[1].average == 8_000)
    // La semaine du 12 octobre n'a que 2 jours mesurés : omise.
}

@Test func sameDayValuesAreAdded() {
    let morning = utc.date(byAdding: .hour, value: -2, to: today)!
    let days = StepHistory.lastDays([DailySteps(day: today, steps: 3_000), DailySteps(day: morning, steps: 1_000)], count: 1, through: today, calendar: utc)
    #expect(days.map(\.steps) == [4_000])
}
