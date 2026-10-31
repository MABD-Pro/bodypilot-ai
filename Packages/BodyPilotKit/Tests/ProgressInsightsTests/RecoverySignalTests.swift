import Foundation
import Testing
@testable import ProgressInsights

private let today = day(2026, 10, 31)

/// 28 jours : `normal` les trois premières semaines, `recent` la dernière, avec un peu de bruit.
private func readings(normal: Double, recent: Double, days: Int = 28, skipping: Set<Int> = []) -> [DatedValue] {
    let noise = [2.0, -1.5, 0.5, -2.5, 1.5, 0.0, -0.5]
    return (0..<days).filter { !skipping.contains($0) }.map { daysAgo in
        DatedValue(date: utc.date(byAdding: .day, value: -daysAgo, to: today)!, value: (daysAgo < 7 ? recent : normal) + noise[daysAgo % noise.count])
    }
}

@Test func lowHrvAndHighRestingHeartRateMeanLowRecovery() throws {
    let status = try #require(RecoverySignal.status(hrv: readings(normal: 55, recent: 40), restingHeartRate: readings(normal: 55, recent: 62), on: today, calendar: utc))
    #expect(status.hrvLow)
    #expect(status.restingHigh)
    #expect(status.isLow)
}

@Test func oneSignalAloneIsNotEnough() throws {
    let status = try #require(RecoverySignal.status(hrv: readings(normal: 55, recent: 40), restingHeartRate: readings(normal: 55, recent: 55), on: today, calendar: utc))
    #expect(status.hrvLow)
    #expect(!status.restingHigh)
    #expect(!status.isLow)
}

@Test func usualWeekIsNormal() throws {
    let status = try #require(RecoverySignal.status(hrv: readings(normal: 55, recent: 55), restingHeartRate: readings(normal: 55, recent: 55), on: today, calendar: utc))
    #expect(!status.isLow)
}

@Test func tooFewReadingsAreIgnored() {
    // Deux mesures seulement sur les 7 derniers jours.
    let sparse = readings(normal: 55, recent: 40, skipping: [0, 1, 2, 3, 4])
    #expect(RecoverySignal.status(hrv: sparse, restingHeartRate: readings(normal: 55, recent: 62), on: today, calendar: utc) == nil)
    // Moins de 14 jours mesurés sur 28.
    let short = readings(normal: 55, recent: 40, days: 10)
    #expect(RecoverySignal.status(hrv: short, restingHeartRate: readings(normal: 55, recent: 62), on: today, calendar: utc) == nil)
}

@Test func severalReadingsInADayCountAsOne() {
    let base = readings(normal: 55, recent: 55, skipping: [0])
    // Dix mesures très basses le même jour ne pèsent pas plus qu'une journée.
    let burst = (0..<10).map { DatedValue(date: today.addingTimeInterval(Double($0) * 600), value: 20) }
    let shift = RecoverySignal.shift(of: (base + burst).map { DatedValue(date: $0.date, value: log($0.value)) }, on: today, calendar: utc)
    let single = RecoverySignal.shift(of: (base + [DatedValue(date: today, value: 20)]).map { DatedValue(date: $0.date, value: log($0.value)) }, on: today, calendar: utc)
    #expect(shift != nil)
    #expect(abs((shift ?? 0) - (single ?? 0)) < 0.01)
}
