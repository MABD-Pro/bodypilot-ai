import BodyPilotCore
import Testing
@testable import Training

@Test func eachExerciseBecomesABlockRepeatedPerSet() {
    let guided = WorkoutCatalog.bodyweightB.guided
    #expect(guided.title == "Full body B")
    #expect(guided.warmupSeconds == 300)
    #expect(guided.cooldownSeconds == 120)
    #expect(guided.blocks.count == WorkoutCatalog.bodyweightB.exercises.count)
    #expect(guided.blocks.map(\.iterations) == WorkoutCatalog.bodyweightB.exercises.map(\.sets))
}

@Test func repsStayOpenAndTimedSetsAreTimed() {
    let guided = WorkoutCatalog.bodyweightB.guided
    let squats = guided.blocks[0]
    #expect(squats.steps[0] == GuidedWorkout.Step(isWork: true, goal: .open, label: "Squats tempo lent · 12 rép."))
    #expect(squats.steps[1] == GuidedWorkout.Step(isWork: false, goal: .seconds(90), label: "Repos"))
    let plank = guided.blocks[3]
    #expect(plank.steps[0].goal == .seconds(30))
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

@Test func waveGoesToTheWatchSetBySetThenFirstSetLast() {
    var squat = WorkoutExercise(name: "Squat à la barre", sets: 3, volume: .reps(1), restSeconds: 180, priority: 1)
    squat.wave = StrengthCycle.wave(for: CycleWeek(program: .crossfit, number: 3))
    squat.backoffSets = 5
    let guided = Workout(title: "Full body A", warmupMinutes: 5, cooldownMinutes: 0, exercises: [squat], intensityCue: "").guided
    #expect(guided.blocks.compactMap { $0.steps.first?.label } == [
        "Squat à la barre · 5 rép.", "Squat à la barre · 3 rép.", "Squat à la barre · 1+ rép.", "Squat à la barre · 5 rép.",
    ])
    #expect(guided.blocks.map(\.iterations) == [1, 1, 1, 5])
    #expect(guided.blocks[3].steps[1].goal == .seconds(90))
    #expect(guided.hasStrength)
}

@Test func cardioOnlySessionIsNotStrength() {
    let cardio = Workout(title: "Cardio et marche inclinée", warmupMinutes: 5, cooldownMinutes: 5, exercises: [
        WorkoutExercise(name: "Vélo", sets: 1, volume: .seconds(1800), restSeconds: 0, priority: 4),
    ], intensityCue: "")
    #expect(!cardio.guided.hasStrength)
}
