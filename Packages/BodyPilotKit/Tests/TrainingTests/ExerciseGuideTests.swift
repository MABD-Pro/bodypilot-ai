import BodyPilotCore
import Testing
@testable import Training

@Test func everyStrengthExerciseOfTheCatalogHasAGuide() {
    let workouts = WorkoutCatalog.sessions(for: .gym) + WorkoutCatalog.sessions(for: .bodyweight)
    let names = workouts.flatMap(\.exercises)
        .filter { if case .reps = $0.volume { true } else { false } }
        .flatMap { [$0.name] + $0.alternatives + [$0.kneeFriendlyAlternative].compactMap { $0 } }
    let missing = Set(names).filter { ExerciseGuide.guide(for: $0) == nil }
    #expect(missing.isEmpty, "Sans fiche : \(missing.sorted())")
}

@Test func startingLoadIsCautiousAndRounded() throws {
    let squat = try #require(ExerciseGuide.guide(for: "Squat à la barre"))
    // 80 kg × 0,6 = 48 → arrondi vers le bas au disque : 47,5 kg.
    #expect(squat.startingLoad(bodyweightKg: 80, sex: .male) == 47.5)
    // Sous 30 kg, pas d'1 kg : 60 × 0,4 = 24 kg.
    #expect(squat.startingLoad(bodyweightKg: 60, sex: .female) == 24)
    let lunge = try #require(ExerciseGuide.guide(for: "Fentes bulgares haltères"))
    #expect(lunge.perDumbbell)
    #expect(lunge.startingLoad(bodyweightKg: 80, sex: .male) == 8)
    // Au poids du corps, pas de charge d'essai.
    #expect(ExerciseGuide.guide(for: "Pompes")?.startingLoad(bodyweightKg: 80, sex: .male) == nil)
}
