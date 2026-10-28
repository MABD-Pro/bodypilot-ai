import Foundation
import Testing
@testable import ProgressInsights

/// Règles de 5 jours qui commencent à chaque date donnée.
private func flowDays(starting starts: [Date]) -> [Date] {
    starts.flatMap { start in (0..<5).map { utc.date(byAdding: .day, value: $0, to: start)! } }
}

@Test func periodStartsAreTheFirstFlowDays() {
    let starts = [day(2026, 8, 3), day(2026, 8, 31), day(2026, 9, 28)]
    let found = MenstrualCycle.starts(fromFlowDays: flowDays(starting: starts).shuffled(), calendar: utc)
    #expect(found == starts.map { utc.startOfDay(for: $0) })
}

@Test func firstDaysOfPeriodRetainWater() {
    let starts = [day(2026, 10, 24)]
    #expect(MenstrualCycle.retainsWater(periodStarts: starts, on: day(2026, 10, 27), calendar: utc))
    #expect(!MenstrualCycle.retainsWater(periodStarts: starts, on: day(2026, 11, 3), calendar: utc))
}

@Test func daysBeforeTheExpectedPeriodRetainWater() {
    // Cycles de 28 jours : prochaines règles attendues le 26 octobre.
    let starts = [day(2026, 8, 3), day(2026, 8, 31), day(2026, 9, 28)]
    #expect(MenstrualCycle.retainsWater(periodStarts: starts, on: day(2026, 10, 23), calendar: utc))
    #expect(!MenstrualCycle.retainsWater(periodStarts: starts, on: day(2026, 10, 12), calendar: utc))
}

@Test func noCycleDataChangesNothing() {
    #expect(!MenstrualCycle.retainsWater(periodStarts: [], on: day(2026, 10, 27), calendar: utc))
}
