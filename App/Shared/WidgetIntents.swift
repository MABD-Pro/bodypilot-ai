import AppIntents
import Foundation
import WidgetKit

/// Repas pris comme prévu, d'une touche depuis un widget ou le Centre de contrôle.
/// Sans repas précisé : le prochain repas pas encore pris.
struct TakeMealIntent: AppIntent {
    static let title: LocalizedStringResource = "Repas pris"
    static let description: IntentDescription? = IntentDescription("Note le prochain repas comme pris, comme prévu.")
    static let isDiscoverable = false

    @Parameter(title: "Repas")
    var slot: String?

    init() {}

    init(slot: String) {
        self.slot = slot
    }

    func perform() async throws -> some IntentResult {
        let snapshot = SharedStore.snapshot
        guard let snapshot, snapshot.isCurrent(),
              let meal = slot.flatMap({ slot in snapshot.meals.first { $0.slot == slot } }) ?? snapshot.nextMeal
        else { return .result() }
        SharedStore.record(.mealTaken(slot: meal.slot, day: snapshot.day))
        WidgetBridgeReload.all()
        return .result()
    }
}

/// Séance du jour cochée depuis un widget ou le Centre de contrôle.
struct MarkWorkoutDoneIntent: AppIntent {
    static let title: LocalizedStringResource = "Séance faite"
    static let description: IntentDescription? = IntentDescription("Coche la séance du jour.")
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        guard let snapshot = SharedStore.snapshot, snapshot.isCurrent(), snapshot.workoutTitle != nil else { return .result() }
        SharedStore.record(.workoutDone(day: snapshot.day))
        WidgetBridgeReload.all()
        return .result()
    }
}

enum WidgetBridgeReload {
    static let todayKind = "TodayWidget"

    static func all() {
        WidgetCenter.shared.reloadAllTimelines()
        ControlCenter.shared.reloadAllControls()
    }
}
