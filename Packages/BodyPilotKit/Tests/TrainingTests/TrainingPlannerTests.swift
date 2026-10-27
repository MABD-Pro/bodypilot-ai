import BodyPilotCore
import Testing
@testable import Training

private let planner = TrainingPlanner(calendar: utc)
// 26/10/2026 est un lundi.
private let monday = day(2026, 10, 26)
private let tuesday = day(2026, 10, 27)

private func workout(_ day: TrainingDay) -> Workout? {
    if case .workout(let workout) = day.kind { return workout }
    return nil
}

@Test func threeDaysPerWeekAreSpreadOut() {
    #expect(TrainingPlanner.trainingWeekdays(daysPerWeek: 3) == [2, 4, 6])
    #expect(TrainingPlanner.trainingWeekdays(daysPerWeek: 9).count == 6)
}

@Test func trainingDayHasWorkoutWithinPreferredDuration() {
    let result = planner.trainingDay(for: makeProfile(), on: monday, constraints: DayConstraints())
    #expect(workout(result) != nil)
    #expect(result.estimatedMinutes <= 45)
}

@Test func restDayProposesActiveRecovery() {
    let result = planner.trainingDay(for: makeProfile(), on: tuesday, constraints: DayConstraints())
    #expect(result.kind == .activeRest(title: "Marche active", minutes: 30))
}

@Test func twentyMinutesKeepsEssentialExercises() throws {
    let result = planner.trainingDay(for: makeProfile(), on: monday, constraints: DayConstraints(availableMinutes: 20))
    let session = try #require(workout(result))
    #expect(result.estimatedMinutes <= 20)
    #expect(session.exercises.count >= 3)
    #expect(session.exercises.filter { $0.priority == 1 }.count == 2)
}

@Test func gymSessionFitsInTwentyMinutes() {
    let profile = makeProfile(equipment: .gym)
    let result = planner.trainingDay(for: profile, on: monday, constraints: DayConstraints(availableMinutes: 20))
    #expect(result.estimatedMinutes <= 20)
}

@Test func tooLittleTimeBecomesAWalk() {
    let result = planner.trainingDay(for: makeProfile(), on: monday, constraints: DayConstraints(availableMinutes: 8))
    #expect(workout(result) == nil)
}

@Test func tiredRemovesImpactAndReducesVolume() throws {
    let normal = try #require(workout(planner.trainingDay(for: makeProfile(), on: monday, constraints: DayConstraints())))
    let tired = try #require(workout(planner.trainingDay(for: makeProfile(), on: monday, constraints: DayConstraints(lowEnergy: true))))
    #expect(!tired.exercises.contains { $0.isHighImpact })
    #expect(tired.exercises.allSatisfy { $0.sets >= 2 })
    #expect(tired.exercises.map(\.sets).reduce(0, +) < normal.exercises.map(\.sets).reduce(0, +))
}

@Test func missedWorkoutIsNeverDoubled() {
    let missed = planner.trainingDay(for: makeProfile(), on: monday, constraints: DayConstraints(missedToday: true))
    #expect(workout(missed) == nil)
    // Mercredi est un jour d'entraînement : une seule séance, même après un raté lundi… et mardi.
    let wednesday = day(2026, 10, 28)
    let next = planner.trainingDay(for: makeProfile(), on: wednesday, constraints: DayConstraints(missedYesterday: true))
    #expect(workout(next) != nil)
}

@Test func missedWorkoutIsCaughtUpOnFollowingRestDay() throws {
    let result = planner.trainingDay(for: makeProfile(), on: tuesday, constraints: DayConstraints(missedYesterday: true))
    let caughtUp = try #require(workout(result))
    #expect(caughtUp.title == planner.scheduledWorkout(for: makeProfile(), on: monday).title)
}

@Test func sessionsAlternateDuringTheWeek() {
    let wednesday = day(2026, 10, 28)
    let first = planner.scheduledWorkout(for: makeProfile(), on: monday)
    let second = planner.scheduledWorkout(for: makeProfile(), on: wednesday)
    #expect(first.title != second.title)
}
