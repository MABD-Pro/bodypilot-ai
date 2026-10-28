import BodyPilotCore
import Foundation
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

@Test func everyGuidedExerciseHasADemonstration() {
    // Toutes les fiches ont une vidéo choisie, sauf le rowing à la porte (aucune vidéo correcte trouvée).
    let withoutVideo = Set(ExerciseGuide.catalog.keys).filter { !ExerciseDemonstration.hasChosenVideo(for: $0) }
    #expect(withoutVideo == ["Rowing serviette à la porte"])
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
