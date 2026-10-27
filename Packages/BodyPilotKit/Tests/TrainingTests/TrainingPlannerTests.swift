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

@Test func kneePainRemovesEveryKneeLoadingExercise() throws {
    for equipment in Equipment.allCases {
        for date in [monday, day(2026, 10, 28)] {
            let result = planner.trainingDay(for: makeProfile(equipment: equipment), on: date, constraints: DayConstraints(kneePain: true))
            let session = try #require(workout(result))
            #expect(!session.exercises.contains { $0.loadsKnee || $0.isHighImpact })
            #expect(session.exercises.count >= 3)
            #expect(result.notes.contains { $0.contains("professionnel de santé") })
        }
    }
}

@Test func kneePainOnRestDayProposesGentleMobility() {
    let result = planner.trainingDay(for: makeProfile(), on: tuesday, constraints: DayConstraints(kneePain: true))
    #expect(result.kind == .activeRest(title: "Mobilité douce", minutes: 15))
}

@Test func travelingUsesBodyweightWithinThirtyMinutes() throws {
    let result = planner.trainingDay(for: makeProfile(sessionMinutes: 60, equipment: .gym), on: monday, constraints: DayConstraints(traveling: true))
    let session = try #require(workout(result))
    #expect(result.estimatedMinutes <= TrainingPlanner.travelMaxMinutes)
    let bodyweightNames = Set(WorkoutCatalog.sessions(for: .bodyweight).flatMap { $0.exercises.map(\.name) })
    #expect(session.exercises.allSatisfy { bodyweightNames.contains($0.name) })
}

@Test func swapCyclesThroughAlternativesThenBackToOriginal() throws {
    let base = try #require(workout(planner.trainingDay(for: makeProfile(), on: monday, constraints: DayConstraints())))
    let first = try #require(base.exercises.first)
    #expect(first.alternatives.count >= 2)

    func name(afterSwaps count: Int) throws -> String {
        let result = planner.trainingDay(for: makeProfile(), on: monday, constraints: DayConstraints(exerciseSwaps: [first.key: count]))
        return try #require(workout(result)?.exercises.first).name
    }
    #expect(try name(afterSwaps: 1) == first.alternatives[0])
    #expect(try name(afterSwaps: 2) == first.alternatives[1])
    #expect(try name(afterSwaps: first.alternatives.count + 1) == first.name)
}

@Test func swapKeepsVolumeAndKey() throws {
    let base = try #require(workout(planner.trainingDay(for: makeProfile(), on: monday, constraints: DayConstraints())))
    let target = base.exercises[1]
    let swapped = try #require(workout(planner.trainingDay(for: makeProfile(), on: monday, constraints: DayConstraints(exerciseSwaps: [target.key: 1]))))
    let exercise = swapped.exercises[1]
    #expect(exercise.name != target.name)
    #expect(exercise.key == target.key)
    #expect(exercise.sets == target.sets && exercise.volume == target.volume && exercise.restSeconds == target.restSeconds)
    #expect(Array(swapped.exercises.dropFirst(2)) == Array(base.exercises.dropFirst(2)))
}

@Test func kneePainOverridesASwapThatLoadsTheKnee() throws {
    let base = try #require(workout(planner.trainingDay(for: makeProfile(), on: monday, constraints: DayConstraints())))
    let squat = try #require(base.exercises.first { $0.loadsKnee })
    let constraints = DayConstraints(kneePain: true, exerciseSwaps: [squat.key: 1])
    let session = try #require(workout(planner.trainingDay(for: makeProfile(), on: monday, constraints: constraints)))
    let protected = try #require(session.exercises.first { $0.key == squat.key })
    #expect(protected.name == squat.kneeFriendlyAlternative)
    #expect(protected.alternatives.isEmpty)
}

@Test func everyCatalogExerciseHasDistinctAlternatives() {
    let all = WorkoutCatalog.sessions(for: .bodyweight) + WorkoutCatalog.sessions(for: .gym)
    for exercise in all.flatMap(\.exercises) {
        #expect(!exercise.alternatives.isEmpty, "\(exercise.name) sans variante")
        #expect(!exercise.alternatives.contains(exercise.name))
        #expect(Set(exercise.alternatives).count == exercise.alternatives.count)
    }
}
