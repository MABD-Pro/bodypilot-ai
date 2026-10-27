import BodyPilotCore
import Testing
@testable import Training

@Test func eachExerciseBecomesABlockRepeatedPerSet() {
    let guided = WorkoutCatalog.bodyweightB.guided
    #expect(guided.title == "Full body B")
    #expect(guided.warmupSeconds == 300)
    #expect(guided.cooldownSeconds == 180)
    #expect(guided.blocks.count == WorkoutCatalog.bodyweightB.exercises.count)
    #expect(guided.blocks.map(\.iterations) == WorkoutCatalog.bodyweightB.exercises.map(\.sets))
}

@Test func repsStayOpenAndTimedSetsAreTimed() {
    let guided = WorkoutCatalog.bodyweightB.guided
    let squats = guided.blocks[0]
    #expect(squats.steps[0] == GuidedWorkout.Step(isWork: true, goal: .open, label: "Squats sumo · 15 rép."))
    #expect(squats.steps[1] == GuidedWorkout.Step(isWork: false, goal: .seconds(60), label: "Repos"))
    let plank = guided.blocks[4]
    #expect(plank.steps[0].goal == .seconds(25))
}

@Test func restDayHasNoGuidedWorkout() {
    let rest = TrainingDay(kind: .activeRest(title: "Marche active", minutes: 30), estimatedMinutes: 30)
    #expect(rest.guidedWorkout == nil)
}

@Test func adjustedWorkoutIsWhatGoesToTheWatch() {
    // Genou douloureux : la montre reçoit la séance déjà adaptée, pas la séance de base.
    let result = TrainingPlanner(calendar: utc).trainingDay(for: makeProfile(), on: day(2026, 10, 26), constraints: DayConstraints(kneePain: true))
    let labels = result.guidedWorkout?.blocks.compactMap { $0.steps.first?.label } ?? []
    #expect(!labels.isEmpty)
    #expect(!labels.contains { $0.hasPrefix("Squats") || $0.hasPrefix("Fentes") })
}
