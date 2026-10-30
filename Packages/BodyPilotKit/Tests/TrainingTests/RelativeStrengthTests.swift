import BodyPilotCore
import Foundation
import Testing
@testable import Training

private let today = day(2026, 10, 30)

private func daysAgo(_ count: Int) -> Date {
    utc.date(byAdding: .day, value: -count, to: today)!
}

private func lift(_ kg: Double?, _ reps: Int, daysAgo count: Int, _ exercise: String = "Squat à la barre") -> LiftEntry {
    LiftEntry(exercise: exercise, date: daysAgo(count), kg: kg, reps: reps)
}

@Test func bodyweightMultipleUsesTwoDecimals() {
    #expect(RelativeStrength.bodyweightMultiple(oneRepMax: 100, bodyweightKg: 80) == "1,25 × ton poids")
    #expect(RelativeStrength.bodyweightMultiple(oneRepMax: 100, bodyweightKg: 0) == nil)
}

@Test func sameLoadsWithLessBodyweightIsAGain() {
    let history = [lift(100, 5, daysAgo: 40), lift(100, 5, daysAgo: 5)]
    let weights = [WeightEntry(date: daysAgo(40), kg: 100), WeightEntry(date: daysAgo(5), kg: 95)]
    let result = RelativeStrength.compute(history: history, weights: weights, on: today, calendar: utc)
    #expect(result?.exercises == 1)
    #expect(abs((result?.ratioChangePercent ?? 0) - (100.0 / 95 - 1) * 100) < 0.001)
    #expect(result?.strengthChangePercent == 0)
    #expect(result?.message.contains("sans perdre de force") == true)
}

@Test func bestSetOfEachPeriodIsCompared() {
    let history = [
        lift(80, 5, daysAgo: 50), lift(90, 5, daysAgo: 35),
        lift(85, 5, daysAgo: 20), lift(95, 5, daysAgo: 3),
        lift(60, 8, daysAgo: 45, "Développé couché"), lift(60, 8, daysAgo: 10, "Développé couché"),
    ]
    let weights = [WeightEntry(date: daysAgo(40), kg: 80), WeightEntry(date: daysAgo(10), kg: 80)]
    let result = RelativeStrength.compute(history: history, weights: weights, on: today, calendar: utc)
    #expect(result?.exercises == 2)
    // Squat : 95 contre 90 (+5,6 %) ; développé couché : stable. Moyenne ≈ +2,8 %.
    #expect(abs((result?.strengthChangePercent ?? 0) - (95.0 / 90 - 1) * 50) < 0.001)
    #expect(result?.weightChangePercent == 0)
}

@Test func noComparisonWithoutBothPeriods() {
    let weights = [WeightEntry(date: daysAgo(40), kg: 80), WeightEntry(date: daysAgo(10), kg: 80)]
    // Exercice noté seulement récemment.
    #expect(RelativeStrength.compute(history: [lift(90, 5, daysAgo: 3)], weights: weights, on: today, calendar: utc) == nil)
    // Poids du corps seulement : pas de charge à comparer.
    #expect(RelativeStrength.compute(history: [lift(nil, 20, daysAgo: 40), lift(nil, 25, daysAgo: 3)], weights: weights, on: today, calendar: utc) == nil)
    // Pas de pesée dans la période précédente.
    let history = [lift(90, 5, daysAgo: 40), lift(90, 5, daysAgo: 3)]
    #expect(RelativeStrength.compute(history: history, weights: [WeightEntry(date: daysAgo(3), kg: 80)], on: today, calendar: utc) == nil)
}

@Test func smallChangesReadAsStable() {
    #expect(RelativeStrength.message(ratio: 1.5, strength: 1, weight: -0.5).hasPrefix("Force par kilo stable"))
    #expect(RelativeStrength.message(ratio: -4, strength: -4, weight: 0).contains("protéines"))
    #expect(RelativeStrength.signedPercent(-3.4) == "−3 %")
}
