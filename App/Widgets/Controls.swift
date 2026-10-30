import AppIntents
import SwiftUI
import WidgetKit

/// Centre de contrôle et écran verrouillé : la séance du jour cochée sans ouvrir l'app.
struct WorkoutDoneControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.mabdpro.bodypilot.control.workoutDone") {
            ControlWidgetButton(action: MarkWorkoutDoneIntent()) {
                Label("Séance faite", systemImage: "checkmark.seal.fill")
            }
        }
        .displayName("Séance faite")
        .description("Coche la séance du jour dans BodyPilot.")
    }
}

/// Le prochain repas pris comme prévu, d'une touche.
struct MealTakenControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.mabdpro.bodypilot.control.mealTaken") {
            ControlWidgetButton(action: TakeMealIntent()) {
                Label("Repas pris", systemImage: "fork.knife")
            }
        }
        .displayName("Repas pris")
        .description("Note le prochain repas comme pris, comme prévu.")
    }
}
