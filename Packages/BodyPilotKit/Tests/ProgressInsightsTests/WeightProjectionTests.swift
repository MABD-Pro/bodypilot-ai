import BodyPilotCore
import Foundation
import Testing
@testable import ProgressInsights

private let today = day(2026, 10, 30)

/// Une pesée par jour sur 3 semaines, à `weekly` kg par semaine, avec un bruit de ±`noise` kg.
private func weighIns(from kg: Double, weekly: Double, noise: Double = 0) -> [WeightEntry] {
    (0...21).map { index in
        let date = utc.date(byAdding: .day, value: index - 21, to: today)!
        let wobble = index.isMultiple(of: 2) ? noise : -noise
        return WeightEntry(date: date, kg: kg + weekly * Double(index) / 7 + wobble)
    }
}

private func trend(current: Double, weekly: Double) -> WeightTrend {
    WeightTrend(points: [], currentTrendKg: current, weeklyChangeKg: weekly, status: .onTrack, estimatedTargetDate: nil)
}

@Test func projectionGivesARangeAroundTheMeasuredPace() throws {
    // 90 kg, −0,5 kg par semaine, objectif 85 kg : 10 semaines au rythme central.
    let projection = try #require(WeightProjector.project(entries: weighIns(from: 91.5, weekly: -0.5), trend: trend(current: 90, weekly: -0.5), targetKg: 85, on: today, calendar: utc))
    // Marge minimale de ±25 % : 8 semaines au plus vite, 13,3 au plus lent.
    #expect(abs(projection.fastWeeklyKg - -0.625) < 0.001)
    #expect(abs(projection.slowWeeklyKg - -0.375) < 0.001)
    #expect(projection.earliest == day(2026, 12, 25))
    #expect(projection.latest == day(2027, 2, 1))
    #expect(projection.rangeText(calendar: utc) == "entre décembre 2026 et février 2027")
}

@Test func noisyWeighInsWidenTheRange() throws {
    let calm = try #require(WeightProjector.project(entries: weighIns(from: 91.5, weekly: -0.5), trend: trend(current: 90, weekly: -0.5), targetKg: 85, on: today, calendar: utc))
    let noisy = try #require(WeightProjector.project(entries: weighIns(from: 91.5, weekly: -0.5, noise: 1.2), trend: trend(current: 90, weekly: -0.5), targetKg: 85, on: today, calendar: utc))
    #expect(noisy.slowWeeklyKg > calm.slowWeeklyKg)
    #expect(noisy.earliest < calm.earliest)
}

@Test func noProjectionAwayFromTheTarget() {
    // Le poids monte, l'objectif est plus bas : pas de date.
    #expect(WeightProjector.project(entries: [], trend: trend(current: 90, weekly: 0.3), targetKg: 85, on: today, calendar: utc) == nil)
    // Objectif déjà atteint, ou pas d'objectif.
    #expect(WeightProjector.project(entries: [], trend: trend(current: 85.2, weekly: -0.3), targetKg: 85, on: today, calendar: utc) == nil)
    #expect(WeightProjector.project(entries: [], trend: trend(current: 90, weekly: -0.3), targetKg: nil, on: today, calendar: utc) == nil)
}

@Test func aSlowEndBeyondTwoYearsHasNoLatestDate() throws {
    // −0,1 kg par semaine : marge minimale de 0,1 kg, le rythme lent est nul.
    let projection = try #require(WeightProjector.project(entries: [], trend: trend(current: 90, weekly: -0.1), targetKg: 85, on: today, calendar: utc))
    #expect(projection.latest == nil)
    #expect(projection.rangeText(calendar: utc).hasPrefix("pas avant"))
}

@Test func whatIfMovesTheRange() throws {
    let base = try #require(WeightProjector.project(entries: [], trend: trend(current: 90, weekly: -0.3), targetKg: 85, on: today, calendar: utc))
    let scenario = ProjectionScenario(kcalPerDay: -200, extraSteps: 2_000)
    // 200 kcal + 2 000 pas × 0,0004 × 90 = 272 kcal par jour, comptés à 80 % : −0,198 kg par semaine.
    #expect(abs(WeightProjector.scenarioWeeklyKg(scenario, weightKg: 90) - -0.1978) < 0.001)
    let faster = try #require(WeightProjector.project(entries: [], trend: trend(current: 90, weekly: -0.3), targetKg: 85, scenario: scenario, on: today, calendar: utc))
    #expect(faster.earliest < base.earliest)
    // Manger plus au point d'inverser le rythme : plus de date.
    #expect(WeightProjector.project(entries: [], trend: trend(current: 90, weekly: -0.2), targetKg: 85, scenario: ProjectionScenario(kcalPerDay: 300), on: today, calendar: utc) == nil)
}
