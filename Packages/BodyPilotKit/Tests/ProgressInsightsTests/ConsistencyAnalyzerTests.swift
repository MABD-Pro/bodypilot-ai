import Foundation
import Testing
@testable import ProgressInsights

private let analyzer = ConsistencyAnalyzer(calendar: utc)
// 26/10/2026 est un lundi ; 28/10 un mercredi.
private let wednesday = day(2026, 10, 28)

private func weeksBack(_ weeks: Int, weekdays: [Int] = [0, 2, 4]) -> [Date] {
    weekdays.compactMap { offset in
        utc.date(byAdding: .day, value: offset - 7 * weeks, to: day(2026, 10, 26))
    }
}

@Test func noHistoryInvitesToCheckTheSession() {
    let result = analyzer.consistency(completedDays: [], plannedPerWeek: 3, on: wednesday)
    #expect(result.done == 0 && result.streakWeeks == 0)
    #expect(result.message.contains("Coche"))
}

@Test func countsOnlyThisWeekAndNotTheFuture() {
    let days = [day(2026, 10, 26), day(2026, 10, 30), day(2026, 10, 23)]
    let result = analyzer.consistency(completedDays: days, plannedPerWeek: 3, on: wednesday)
    #expect(result.done == 1)
    #expect(result.planned == 3)
}

@Test func streakCountsFullPastWeeks() {
    let days = weeksBack(1) + weeksBack(2) + [day(2026, 10, 26)]
    let result = analyzer.consistency(completedDays: days, plannedPerWeek: 3, on: wednesday)
    #expect(result.done == 1)
    #expect(result.streakWeeks == 2)
    #expect(result.message == "Encore 2 séances pour boucler la semaine et prolonger ta série de 2 semaines.")
}

@Test func incompleteWeekBreaksTheStreak() {
    let days = weeksBack(1) + weeksBack(2, weekdays: [0]) + weeksBack(3)
    let result = analyzer.consistency(completedDays: days, plannedPerWeek: 3, on: wednesday)
    #expect(result.streakWeeks == 1)
}

@Test func completedWeekJoinsTheStreak() {
    let days = weeksBack(1) + [day(2026, 10, 26), day(2026, 10, 27), day(2026, 10, 28)]
    let result = analyzer.consistency(completedDays: days, plannedPerWeek: 3, on: wednesday)
    #expect(result.done == 3)
    #expect(result.streakWeeks == 2)
    #expect(result.message.hasPrefix("Semaine bouclée, 2 semaines d'affilée"))
}

@Test func sameDayCountsOnce() {
    let days = [day(2026, 10, 26), day(2026, 10, 26).addingTimeInterval(3600)]
    let result = analyzer.consistency(completedDays: days, plannedPerWeek: 2, on: wednesday)
    #expect(result.done == 1)
    #expect(result.message == "Encore 1 séance pour boucler la semaine.")
}
