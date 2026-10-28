import BodyPilotCore
import Foundation
import Testing
@testable import Training

@Test func everyStrengthExerciseOfTheCatalogHasAGuide() {
    let cycle = (1...3).flatMap { WorkoutCatalog.cycleSessions(phase: $0) }
    let technique = (1...3).map { CycleConditioning.technique(for: CycleWeek(program: .crossfit, number: 4 * $0 - 3)) }
    let workouts = WorkoutCatalog.sessions(for: .gym) + WorkoutCatalog.sessions(for: .bodyweight) + cycle
    let names = (workouts.flatMap(\.exercises) + technique)
        .filter { if case .reps = $0.volume { true } else { false } }
        .flatMap { [$0.name] + $0.alternatives + [$0.kneeFriendlyAlternative].compactMap { $0 } }
    let missing = Set(names).filter { ExerciseGuide.guide(for: $0) == nil }
    #expect(missing.isEmpty, "Sans fiche : \(missing.sorted())")
}

@Test func startingLoadIsCautiousAndRounded() throws {
    let squat = try #require(ExerciseGuide.guide(for: "Squat à la barre"))
    // 80 kg × 0,6 = 48 → arrondi vers le bas au disque : 47,5 kg.
    #expect(squat.startingLoad(bodyweightKg: 80, sex: .male) == 47.5)
    // À la barre, toujours de 2,5 en 2,5 kg : 60 × 0,4 = 24 → 22,5 kg ; 84 × 0,35 = 29,4 → 27,5 kg.
    #expect(squat.startingLoad(bodyweightKg: 60, sex: .female) == 22.5)
    #expect(ExerciseGuide.guide(for: "Push press")?.startingLoad(bodyweightKg: 84, sex: .male) == 27.5)
    let lunge = try #require(ExerciseGuide.guide(for: "Fentes bulgares haltères"))
    #expect(lunge.perDumbbell)
    #expect(lunge.startingLoad(bodyweightKg: 80, sex: .male) == 8)
    // Au poids du corps, pas de charge d'essai.
    #expect(ExerciseGuide.guide(for: "Pompes")?.startingLoad(bodyweightKg: 80, sex: .male) == nil)
}

@Test func everyGuidedExerciseHasADemonstration() {
    // Toutes les fiches ont une vidéo choisie, sauf le rowing à la porte (aucune vidéo correcte trouvée).
    let withoutVideo = Set(ExerciseGuide.catalog.keys).filter { !ExerciseDemonstration.hasChosenVideo(for: $0) }
    #expect(withoutVideo == ["Rowing serviette à la porte", "Élévations latérales haltères", "Curl haltères", "Extension triceps à la poulie", "Mollets debout à la machine", "Pompes diamant", "Pompes pike", "Mollets sur une marche", "Équilibre sur une jambe"])
    #expect(Set(ExerciseDemonstration.videos.keys).isSubset(of: ExerciseGuide.catalog.keys))
}

@Test func demonstrationLinksToTheVideoOrToASearch() {
    #expect(ExerciseDemonstration.url(for: "Squat à la barre").absoluteString == "https://www.youtube.com/watch?v=K5HuVGYcp50")
    let search = ExerciseDemonstration.url(for: "Rowing serviette à la porte")
    #expect(search.host() == "www.youtube.com")
    #expect(search.path() == "/results")
    #expect(URLComponents(url: search, resolvingAgainstBaseURL: false)?.queryItems?.first?.value == "Rowing serviette à la porte technique")
}

@Test func chosenVideoPlaysEmbeddedWithoutTrackingCookies() {
    #expect(ExerciseDemonstration.embedURL(for: "Squat à la barre")?.absoluteString == "https://www.youtube-nocookie.com/embed/K5HuVGYcp50?playsinline=1&rel=0")
    #expect(ExerciseDemonstration.embedURL(for: "Rowing serviette à la porte") == nil)
}

@Test func everyHyroxStationHasAGuideWhateverTheDistance() {
    let stations = HyroxCycle.technique(sets: 3).map(\.name) + ["Marche du fermier (100 m)", "Rameur (250 m)"]
    let missing = stations.filter { ExerciseGuide.guide(for: $0) == nil }
    #expect(missing.isEmpty, "Sans fiche : \(missing)")
    #expect(ExerciseGuide.baseName("SkiErg (250 m)") == "SkiErg")
    #expect(ExerciseGuide.baseName("Wall ball") == "Wall ball")
}
