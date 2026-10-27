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
