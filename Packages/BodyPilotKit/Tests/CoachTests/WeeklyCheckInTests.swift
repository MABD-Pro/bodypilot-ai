import BodyPilotCore
import Foundation
import Nutrition
import ProgressInsights
import Testing
import Training
@testable import Coach

private let coach = DailyCoach(
    nutrition: MealPlanner(calculator: EnergyCalculator(calendar: utc)),
    training: TrainingPlanner(calendar: utc),
    progress: WeightTrendAnalyzer(calendar: utc),
    calendar: utc
)
private let today = day(2026, 10, 27)

/// Une pesée par jour sur `days` jours, se terminant aujourd'hui.
private func weights(days: Int = 28, start: Double, perDay: Double) -> [WeightEntry] {
    (0..<days).map { index in
        WeightEntry(date: utc.date(byAdding: .day, value: index - days + 1, to: today)!, kg: start + perDay * Double(index))
    }
}

@Test func steadyLossNeedsNoChange() {
    // −0,7 kg/semaine sur 90 kg : dans la cible.
    #expect(coach.weeklyCheckIn(for: makeProfile(), weights: weights(start: 92, perDay: -0.1), on: today) == nil)
}

@Test func fastLossSuggestsEatingMore() throws {
    // −1,4 kg/semaine : plus de 1 % du poids.
    let suggestion = try #require(coach.weeklyCheckIn(for: makeProfile(), weights: weights(start: 94, perDay: -0.2), on: today))
    #expect(suggestion.deltaKcal == 150)
    #expect(suggestion.message.contains("+150 kcal"))
}

@Test func persistentStallSuggestsEatingLess() throws {
    let suggestion = try #require(coach.weeklyCheckIn(for: makeProfile(), weights: weights(start: 88, perDay: 0), on: today))
    #expect(suggestion.deltaKcal == -150)
    #expect(suggestion.message.contains("deux semaines"))
}

@Test func cumulativeAdjustmentIsCapped() {
    var profile = makeProfile()
    profile.calorieAdjustmentKcal = -450
    #expect(coach.weeklyCheckIn(for: profile, weights: weights(start: 88, perDay: 0), on: today) == nil)
}

@Test func noSuggestionBelowTheSafetyFloor() {
    // Petite femme sédentaire déjà au plancher de 1 200 kcal : baisser n'aurait aucun effet.
    let small = UserProfile(
        sex: .female, birthDate: day(1991, 1, 1), heightCm: 155, startWeightKg: 52,
        activity: .sedentary, goal: .loseFat, trainingDaysPerWeek: 2, sessionMinutes: 30, equipment: .bodyweight
    )
    #expect(coach.weeklyCheckIn(for: small, weights: weights(start: 52, perDay: 0), on: today) == nil)
}

@Test func notEnoughDataMeansNoCheckIn() {
    #expect(coach.weeklyCheckIn(for: makeProfile(), weights: weights(days: 4, start: 90, perDay: -0.3), on: today) == nil)
}

private func recompositionProfile() -> UserProfile {
    var profile = makeProfile()
    profile.goal = .recomposition
    return profile
}

@Test func recompositionStallWithShrinkingWaistNeedsNoChange() {
    let waists = [
        WaistEntry(date: utc.date(byAdding: .day, value: -21, to: today)!, cm: 96),
        WaistEntry(date: today, cm: 94),
    ]
    let flat = weights(start: 88, perDay: 0)
    #expect(coach.weeklyCheckIn(for: recompositionProfile(), weights: flat, waists: waists, on: today) == nil)

    let plan = coach.plan(for: recompositionProfile(), weights: flat, waists: waists, on: today)
    #expect(plan.waistChangeCm == -2)
    #expect(plan.progressMessage.contains("recomposition"))
}

@Test func recompositionStallWithoutWaistAsksToMeasure() throws {
    let suggestion = try #require(coach.weeklyCheckIn(for: recompositionProfile(), weights: weights(start: 88, perDay: 0), on: today))
    #expect(suggestion.deltaKcal == -150)
    #expect(suggestion.message.contains("tour de taille"))
}

@Test func waterRetentionAroundPeriodHoldsBackACut() throws {
    let flat = weights(start: 88, perDay: 0)
    #expect(coach.weeklyCheckIn(for: makeProfile(), weights: flat, retainsWater: true, on: today) == nil)
    // Perte trop rapide : manger plus reste proposé, même pendant les règles.
    let fast = try #require(coach.weeklyCheckIn(for: makeProfile(), weights: weights(start: 94, perDay: -0.2), retainsWater: true, on: today))
    #expect(fast.deltaKcal == 150)
}

@Test func proposedTargetIncludesSessions() throws {
    let flat = weights(start: 88, perDay: 0)
    let without = try #require(coach.weeklyCheckIn(for: makeProfile(), weights: flat, on: today))
    let with = try #require(coach.weeklyCheckIn(for: makeProfile(), weights: flat, exerciseKcalPerDay: 300, on: today))
    #expect(with.newTargetKcal > without.newTargetKcal)
}

/// Taux de gras d'une balance sur 4 semaines, d'une valeur à l'autre.
private func compositions(from start: Double, to end: Double) -> [BodyCompositionEntry] {
    (0..<28).map { index in
        BodyCompositionEntry(date: utc.date(byAdding: .day, value: index - 27, to: today)!, fatPercent: start + (end - start) * Double(index) / 27)
    }
}

@Test func recompositionStallWithFallingBodyFatNeedsNoChange() {
    let flat = weights(start: 88, perDay: 0)
    let falling = compositions(from: 30, to: 29)
    #expect(coach.weeklyCheckIn(for: recompositionProfile(), weights: flat, compositions: falling, on: today) == nil)
    let plan = coach.plan(for: recompositionProfile(), weights: flat, compositions: falling, on: today)
    #expect(plan.progressMessage.contains("taux de gras"))
    #expect(plan.composition?.fatChangePoints ?? 0 < -0.5)
}

@Test func recompositionStallWithFlatBodyFatStillSuggestsACut() throws {
    let suggestion = try #require(coach.weeklyCheckIn(for: recompositionProfile(), weights: weights(start: 88, perDay: 0), compositions: compositions(from: 30, to: 29.9), on: today))
    #expect(suggestion.deltaKcal == -150)
}

@Test func noDecreaseWithEatingDisorderHistory() {
    var profile = makeProfile()
    profile.screening = HealthScreening(answeredAt: today, situations: [.eatingDisorder])
    #expect(coach.weeklyCheckIn(for: profile, weights: weights(start: 88, perDay: 0), on: today) == nil)
}

@Test func leanProfileGetsASmallSurplus() {
    var profile = makeProfile(weightKg: 64, targetWeightKg: 70)
    profile.goal = .recomposition
    let plan = coach.plan(for: profile, weights: weights(start: 64, perDay: 0), on: today)
    #expect(plan.phase == .leanGain)
    #expect(plan.targets.macros.kcal > plan.targets.maintenanceKcal)
    #expect(plan.targets.rationale.contains("légère prise"))
}

@Test func stalledLeanGainSuggestsEatingMore() throws {
    var profile = makeProfile(weightKg: 64, targetWeightKg: 70)
    profile.goal = .recomposition
    let suggestion = try #require(coach.weeklyCheckIn(for: profile, weights: weights(start: 64, perDay: 0), on: today))
    #expect(suggestion.deltaKcal == 150)
}

@Test func noCheckInDuringAMaintenanceWeek() {
    var profile = makeProfile()
    let flat = weights(start: 88, perDay: 0)
    #expect(coach.weeklyCheckIn(for: profile, weights: flat, on: today) != nil)
    profile.maintenanceWeekUntil = utc.date(byAdding: .day, value: 3, to: today)
    #expect(coach.weeklyCheckIn(for: profile, weights: flat, on: today) == nil)
}
