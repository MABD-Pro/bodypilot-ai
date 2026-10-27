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
    progress: WeightTrendAnalyzer(calendar: utc)
)
private let monday = day(2026, 10, 26)

@Test func planAnswersTheThreeQuestions() {
    let plan = coach.plan(for: makeProfile(), weights: [], on: monday)
    #expect(plan.meals.meals.count == 4)
    if case .workout = plan.training.kind {} else { Issue.record("Lundi devrait être un jour de séance") }
    #expect(plan.progressMessage.contains("Pèse-toi"))
    #expect(!plan.headline.isEmpty)
}

@Test func shortOnTimeLimitsSessionToTwentyMinutes() {
    let plan = coach.plan(for: makeProfile(), weights: [], adjustments: [.shortOnTime], on: monday)
    #expect(plan.training.estimatedMinutes <= QuickAdjustment.shortOnTimeMinutes)
    #expect(plan.headline.contains("express"))
}

@Test func tiredKeepsNutritionUnchanged() {
    let normal = coach.plan(for: makeProfile(), weights: [], on: monday)
    let tired = coach.plan(for: makeProfile(), weights: [], adjustments: [.tired], on: monday)
    #expect(normal.targets == tired.targets)
    #expect(tired.training.estimatedMinutes < normal.training.estimatedMinutes)
}

@Test func missedWorkoutTurnsIntoWalk() {
    let plan = coach.plan(for: makeProfile(), weights: [], adjustments: [.missedWorkout], on: monday)
    if case .workout = plan.training.kind { Issue.record("Une séance ratée ne doit pas être reproposée le jour même") }
}

@Test func targetsFollowMeasuredTrendWeight() {
    let weights = (0..<14).map { WeightEntry(date: utc.date(byAdding: .day, value: -$0, to: monday)!, kg: 85) }
    let measured = coach.plan(for: makeProfile(weightKg: 90), weights: weights, on: monday)
    let declared = coach.plan(for: makeProfile(weightKg: 90), weights: [], on: monday)
    #expect(measured.targets.macros.kcal < declared.targets.macros.kcal)
}

@Test func quickAdjustmentsMapToConstraints() {
    let constraints = DayConstraints(today: [.shortOnTime, .tired], yesterday: [.missedWorkout])
    #expect(constraints == DayConstraints(availableMinutes: 20, lowEnergy: true, missedToday: false, missedYesterday: true))
}
