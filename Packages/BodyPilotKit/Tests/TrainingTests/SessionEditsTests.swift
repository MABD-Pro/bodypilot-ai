import BodyPilotCore
import Testing
@testable import Training

private let base = Workout(
    title: "Full body A", warmupMinutes: 5, cooldownMinutes: 0,
    exercises: [
        WorkoutExercise(name: "Squat à la barre", sets: 4, volume: .reps(6), restSeconds: 180, priority: 1),
        WorkoutExercise(name: "Rowing barre", sets: 3, volume: .reps(8), restSeconds: 120, priority: 2),
        WorkoutExercise(name: "Rameur fractionné", sets: 6, volume: .seconds(120), restSeconds: 60, priority: 4),
    ],
    intensityCue: ""
)

@Test func editsChangeVolumeRemoveAndAdd() {
    let edits = SessionEdits(
        removed: ["Rowing barre"],
        volumes: ["Squat à la barre": .init(sets: 5, reps: 5), "Rameur fractionné": .init(sets: 4, seconds: 90)],
        added: ["Hip thrust", "SkiErg"]
    )
    let edited = edits.apply(to: base)
    #expect(edited.exercises.map(\.name) == ["Squat à la barre", "Rameur fractionné", "Hip thrust", "SkiErg"])
    #expect(edited.exercises[0].sets == 5 && edited.exercises[0].volume == .reps(5))
    #expect(edited.exercises[1].sets == 4 && edited.exercises[1].volume == .seconds(90))
    #expect(edited.exercises[2].volume == .reps(10))
    #expect(edited.exercises[3].volume == .seconds(60) && edited.exercises[3].priority == 4)
    #expect(edited.estimatedMinutes != base.estimatedMinutes)
}

@Test func waveKeepsItsSetsAndOnlyBackoffChanges() {
    var squat = base.exercises[0]
    squat.wave = StrengthCycle.wave(for: CycleWeek(program: .crossfit, number: 1))
    squat.backoffSets = 5
    var workout = base
    workout.exercises[0] = squat
    let edited = SessionEdits(volumes: ["Squat à la barre": .init(sets: 5, reps: 3)]).apply(to: workout)
    #expect(edited.exercises[0].wave == squat.wave)
    #expect(edited.exercises[0].backoffSets == 2)
    #expect(edited.exercises[0].sets == squat.sets)
}

@Test func addableExercisesHaveAGuideAndAddingTwiceIsIgnored() {
    #expect(SessionEdits.addableExercises.contains("SkiErg"))
    #expect(SessionEdits.addableExercises.allSatisfy { ExerciseGuide.guide(for: $0) != nil })
    let edited = SessionEdits(added: ["Squat à la barre"]).apply(to: base)
    #expect(edited.exercises.count == base.exercises.count)
}
