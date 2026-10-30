import ActivityKit
import AppIntents
import BodyPilotCore
import Foundation

/// Séance en cours sur l'écran verrouillé et dans la Dynamic Island : exercice, série, repos.
struct WorkoutActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var progress: SessionProgress
    }

    var title: String
    var startedAt: Date
}

/// « Série faite » : série suivante et minuteur de repos. Exécuté dans le processus de l'app
/// (LiveActivityIntent), seul autorisé à mettre à jour l'activité.
struct CompleteSetIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Série faite"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        await WorkoutLiveActivity.completeSet()
        #endif
        return .result()
    }
}

/// Passe l'exercice en cours (machine prise, douleur).
struct SkipExerciseIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Exercice suivant"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        await WorkoutLiveActivity.skipExercise()
        #endif
        return .result()
    }
}

/// Fin de la séance : le suivi disparaît et la séance est cochée.
struct FinishWorkoutIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Terminer la séance"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        await WorkoutLiveActivity.finish(markDone: true)
        #endif
        return .result()
    }
}
