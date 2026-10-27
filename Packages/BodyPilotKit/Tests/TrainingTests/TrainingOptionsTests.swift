import BodyPilotCore
import Foundation
import Testing
@testable import Training

private let planner = TrainingPlanner(calendar: utc)
// 26/10/2026 est un lundi.
private let monday = day(2026, 10, 26)
private let sunday = day(2026, 10, 25)

private func options(_ constraints: DayConstraints = DayConstraints(), equipment: Equipment = .bodyweight) -> TrainingOptions {
    planner.options(for: makeProfile(equipment: equipment), on: monday, constraints: constraints)
}

private func daysBefore(_ count: Int) -> Set<Date> {
    Set((1...count).compactMap { utc.date(byAdding: .day, value: -$0, to: utc.startOfDay(for: monday)) })
}

@Test func strengthDaysOfferThreeActivitiesAndRest() {
    let result = options()
    #expect(result.options.map(\.choice) == [.strength, .conditioning, .light, .rest])
    #expect(result.recommended == .strength)
    #expect(result.reason.contains("Première séance de force"))
    #expect(result.option(.rest)?.day.kind == .rest)
    #expect(result.option(.light)?.day.estimatedMinutes == 30)
}

@Test func strengthIsNotOfferedWithinFortyEightHours() {
    let result = options(DayConstraints(lastStrengthDay: sunday))
    #expect(result.options.map(\.choice) == [.conditioning, .light, .rest])
    #expect(result.recommended == .conditioning)
}

@Test func theChosenOptionIsTheDay() throws {
    let rest = planner.trainingDay(for: makeProfile(), on: monday, constraints: DayConstraints(choice: .rest))
    #expect(rest.kind == .rest)
    let walk = planner.trainingDay(for: makeProfile(), on: monday, constraints: DayConstraints(choice: .light))
    #expect(walk.kind == .activeRest(title: "Marche tranquille", minutes: 30))
    // Un choix qui n'est plus proposé (force il y a moins de 48 h) laisse place à la recommandation.
    let fallback = planner.trainingDay(for: makeProfile(), on: monday, constraints: DayConstraints(lastStrengthDay: sunday, choice: .strength))
    guard case .workout(let workout) = fallback.kind else { Issue.record("Cardio attendu"); return }
    #expect(!workout.hasStrength)
}

@Test func sixActiveDaysInARowRecommendRest() {
    #expect(options(DayConstraints(activeDays: daysBefore(6))).recommended == .rest)
    #expect(options(DayConstraints(activeDays: daysBefore(5))).recommended == .strength)
    // Un jour sans activité casse la série.
    let broken = daysBefore(7).subtracting([utc.date(byAdding: .day, value: -3, to: utc.startOfDay(for: monday))!])
    #expect(options(DayConstraints(activeDays: broken)).recommended == .strength)
}

@Test func shortSleepAvoidsHeavyStrength() {
    let short = options(DayConstraints(sleepHours: 5.5))
    #expect(short.recommended == .conditioning)
    #expect(short.reason.contains("5 h 30"))
    #expect(options(DayConstraints(sleepHours: 7)).recommended == .strength)
    #expect(options(DayConstraints(lastStrengthDay: sunday, sleepHours: 5)).recommended == .light)
    // Fatigue et nuit courte ensemble : repos.
    #expect(options(DayConstraints(lowEnergy: true, sleepHours: 5)).recommended == .rest)
    // La fatigue seule allège la séance sans l'annuler.
    #expect(options(DayConstraints(lowEnergy: true)).recommended == .strength)
}

@Test func sorenessRecommendsModerateCardio() {
    let result = options(DayConstraints(sore: true))
    #expect(result.recommended == .conditioning)
    #expect(result.option(.strength) != nil)
}

@Test func anIntenseClassYesterdayCountsInRecovery() {
    let yesterday = utc.date(byAdding: .hour, value: -14, to: monday)!
    let hiit = ActivitySample(id: "1", kind: .intervals, start: yesterday, minutes: 55)
    let result = options(DayConstraints(lastStrengthDay: sunday, recentActivities: [hiit]))
    #expect(result.recommended == .light)
    #expect(result.reason.contains("55 min"))
    // Une marche n'est pas une séance intense.
    let walk = ActivitySample(id: "2", kind: .walking, start: yesterday, minutes: 90)
    #expect(options(DayConstraints(lastStrengthDay: sunday, recentActivities: [walk])).recommended == .conditioning)
}

@Test func aMissedSessionIsNeverDoubled() {
    let result = options(DayConstraints(missedToday: true))
    #expect(result.recommended == .light)
    #expect(result.reason.contains("ratée"))
}
