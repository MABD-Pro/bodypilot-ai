import BodyPilotCore
import Foundation
import Testing
@testable import Training

private func lift(_ name: String) -> WorkoutExercise {
    WorkoutExercise(name: name, sets: 3, volume: .reps(5), restSeconds: 150, priority: 1)
}

@Test func strengthWarmupMobilisesTheDaysMovesThenRampsToTheFirstLift() throws {
    let workout = Workout(
        title: "Full body A", warmupMinutes: 6, cooldownMinutes: 5,
        exercises: [lift("Squat à la barre"), lift("Développé couché"), lift("Rowing barre")],
        intensityCue: ""
    )
    let plan = WarmupPlanner.warmup(for: workout, atGym: true, firstLift: ("Squat à la barre", 80))
    #expect(plan.blocks.map(\.title) == ["Faire monter le pouls", "Mobiliser", "Monter en charge : Squat à la barre"])
    // Deux mouvements par famille, quatre au plus, dans l'ordre de la séance : squat puis développé.
    let mobility = try #require(plan.blocks.first { $0.title == "Mobiliser" })
    #expect(mobility.steps.count == 4)
    #expect(mobility.steps.first?.title == "Squat au poids du corps, lent")
    // Barre à vide, puis 40, 55 et 67,5 kg : jamais au-dessus de la charge de travail.
    let ramp = try #require(plan.blocks.last).steps
    #expect(ramp.map(\.title) == ["Barre à vide", "40 kg", "55 kg", "67,5 kg"])
    #expect(ramp.map(\.detail) == ["10 rép.", "5 rép.", "3 rép.", "1 rép."])
    #expect(plan.notes.contains { $0.contains("étirements longs") })
}

@Test func lightLoadsSkipTheEmptyBarAndRepeatedSteps() {
    let ramp = WarmupPlanner.ramp(for: "Développé militaire", workingKg: 30)
    // 50 et 70 % de 30 kg tombent sur la barre seule (20 kg) : un seul palier à 20 kg, puis 25 kg.
    #expect(ramp.map(\.title) == ["20 kg", "25 kg"])
}

@Test func cardioWarmupBuildsUpWithStridesBeforeIntervals() {
    let workout = Workout(
        title: "Cardio", warmupMinutes: 6, cooldownMinutes: 4,
        exercises: [WorkoutExercise(name: "Rameur fractionné", sets: 6, volume: .seconds(60), restSeconds: 90, priority: 4)],
        intensityCue: ""
    )
    let plan = WarmupPlanner.warmup(for: workout, atGym: false)
    #expect(plan.blocks.first?.steps.first?.detail == "4 min")
    #expect(plan.blocks.first?.steps.first?.title.contains("Marche rapide") == true)
    #expect(plan.blocks.last?.steps.first?.detail == "2 × 20 s")
}

@Test func cooldownStretchesTheMusclesWorked() {
    let workout = Workout(
        title: "Full body B", warmupMinutes: 6, cooldownMinutes: 5,
        exercises: [lift("Soulevé de terre"), lift("Développé militaire")],
        intensityCue: ""
    )
    let plan = WarmupPlanner.cooldown(for: workout, atGym: true)
    #expect(plan.blocks.last?.steps.map(\.title) == ["Étirement des ischio-jambiers", "Étirement des pectoraux contre un mur"])
}
