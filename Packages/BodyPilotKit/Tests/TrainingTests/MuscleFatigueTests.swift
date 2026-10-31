import BodyPilotCore
import Foundation
import Testing
@testable import Training

private let today = day(2026, 10, 31)

private func lift(_ exercise: String, daysAgo: Int, effort: SetEffort? = nil) -> LiftEntry {
    LiftEntry(exercise: exercise, date: utc.date(byAdding: .day, value: -daysAgo, to: today)!, kg: 60, reps: 6, effort: effort)
}

@Test func firstMuscleOfTheGuideIsPrimary() throws {
    let squat = try #require(ExerciseMuscles.of("Squat à la barre"))
    #expect(squat.primary == [.quadriceps])
    #expect(squat.secondary == [.glutes, .core])
    let row = try #require(ExerciseMuscles.of("Rowing barre"))
    #expect(row.primary == [.back])
    #expect(row.secondary == [.arms])
}

@Test func legsAndWholeBodyListsAreRead() throws {
    #expect(try #require(ExerciseMuscles.of("Rameur")).primary == [.quadriceps, .hamstrings, .glutes])
    #expect(try #require(ExerciseMuscles.of("Burpees sautés en longueur")).primary == [.quadriceps, .hamstrings, .glutes])
    #expect(ExerciseMuscles.of("Exercice inconnu") == nil)
}

@Test func yesterdaySquatLeavesQuadsRecovering() {
    let map = MuscleFatigue.map(lifts: [lift("Squat à la barre", daysAgo: 1)], on: today, calendar: utc)
    #expect(map.state(.quadriceps) == .recovering)
    #expect(map.state(.glutes) == .fresh)
    #expect(map.state(.chest) == .fresh)
}

@Test func twoLegExercisesYesterdayLeaveQuadsFatigued() {
    let lifts = [lift("Squat à la barre", daysAgo: 1), lift("Fentes bulgares haltères", daysAgo: 1)]
    let map = MuscleFatigue.map(lifts: lifts, on: today, calendar: utc)
    #expect(map.state(.quadriceps) == .fatigued)
    #expect(map.groups(.fatigued) == [.quadriceps])
}

@Test func hardEffortWeighsMore() {
    let easy = MuscleFatigue.map(lifts: [lift("Développé couché", daysAgo: 1, effort: .easy)], on: today, calendar: utc)
    let hard = MuscleFatigue.map(lifts: [lift("Développé couché", daysAgo: 1, effort: .hard)], on: today, calendar: utc)
    #expect((hard.load[.chest] ?? 0) > (easy.load[.chest] ?? 0))
}

@Test func fatigueIsGoneAfterThreeDays() {
    let map = MuscleFatigue.map(lifts: [lift("Squat à la barre", daysAgo: 3), lift("Squat à la barre", daysAgo: 4)], on: today, calendar: utc)
    #expect(map.isEmpty)
}

@Test func fatiguedTargetsOfTodaysSession() {
    let lifts = [lift("Squat à la barre", daysAgo: 0), lift("Presse à cuisses", daysAgo: 1)]
    let map = MuscleFatigue.map(lifts: lifts, on: today, calendar: utc)
    let workout = Workout(title: "Test", warmupMinutes: 5, cooldownMinutes: 2, exercises: [
        WorkoutExercise(name: "Fentes bulgares haltères", sets: 3, volume: .reps(8), restSeconds: 90, priority: 1),
        WorkoutExercise(name: "Développé couché", sets: 3, volume: .reps(8), restSeconds: 90, priority: 1),
    ], intensityCue: "")
    #expect(MuscleFatigue.fatiguedTargets(of: workout, in: map) == [.quadriceps])
}
