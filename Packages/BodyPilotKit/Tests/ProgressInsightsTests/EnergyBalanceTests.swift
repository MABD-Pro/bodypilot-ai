import BodyPilotCore
import Foundation
import Testing
@testable import ProgressInsights

private let today = day(2026, 10, 28)

private func past(_ daysAgo: Int) -> Date { utc.date(byAdding: .day, value: -daysAgo, to: today)! }

@Test func expenditureIsIntakeMinusStoredEnergy() throws {
    // 2 000 kcal par jour et −0,1 kg par jour : 2 000 + 0,1 × 7 700 = 2 770 kcal.
    let intakes = (1...21).map { IntakeDay(day: past($0), kcal: 2_000) }
    let weights = (1...21).map { WeightEntry(date: past($0), kg: 88 + 0.1 * Double($0)) }
    let measured = try #require(EnergyBalance.measured(intakes: intakes, weights: weights, on: today, calendar: utc))
    #expect(abs(measured.kcal - 2_770) < 1)
    #expect(measured.days == 21)
    #expect(abs(measured.weeklyChangeKg + 0.7) < 0.01)
}

@Test func tooFewCompleteDaysGiveNoMeasure() {
    let intakes = (1...9).map { IntakeDay(day: past($0), kcal: 2_000) }
    let weights = (1...21).map { WeightEntry(date: past($0), kg: 88) }
    #expect(EnergyBalance.measured(intakes: intakes, weights: weights, on: today, calendar: utc) == nil)
}

@Test func weighingsMustSpanTwoWeeks() {
    let intakes = (1...21).map { IntakeDay(day: past($0), kcal: 2_000) }
    let weights = (1...10).map { WeightEntry(date: past($0), kg: 88) }
    #expect(EnergyBalance.measured(intakes: intakes, weights: weights, on: today, calendar: utc) == nil)
}
