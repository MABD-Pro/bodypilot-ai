import Foundation

/// Résumé du jour que l'app écrit pour les widgets et le Centre de contrôle.
///
/// Partagé avec l'extension par le groupe d'apps : l'extension n'ouvre pas la base SwiftData,
/// elle lit ce résumé et dépose les actions faites d'une touche, que l'app applique ensuite.
struct TodaySnapshot: Codable, Equatable, Sendable {
    struct Meal: Codable, Equatable, Sendable, Identifiable {
        /// `MealSlot.rawValue`.
        var slot: String
        var name: String
        var symbol: String
        var kcal: Int
        var eaten: Bool
        var id: String { slot }
    }

    var day: Date
    /// Séance du jour ; `nil` un jour de repos.
    var workoutTitle: String?
    /// « Full body A · 45 min », « Marche tranquille · 30 min », « Repos ».
    var trainingLine: String
    var trainingSymbol: String
    var workoutDone: Bool
    var kcalTarget: Int
    var kcalEaten: Int
    var proteinTarget: Int
    var proteinEaten: Int
    var meals: [Meal]

    var nextMeal: Meal? { meals.first { !$0.eaten } }
    var kcalLeft: Int { max(0, kcalTarget - kcalEaten) }

    func isCurrent(now: Date = .now, calendar: Calendar = .current) -> Bool {
        calendar.isDate(day, inSameDayAs: now)
    }
}

/// Action faite depuis un widget ou le Centre de contrôle, appliquée par l'app à son ouverture.
enum WidgetAction: Codable, Equatable, Sendable {
    case mealTaken(slot: String, day: Date)
    case workoutDone(day: Date)
}

/// Stockage partagé entre l'app et l'extension (groupe d'apps).
enum SharedStore {
    static let appGroup = "group.com.mabdpro.bodypilot"
    private static let snapshotKey = "todaySnapshot"
    private static let actionsKey = "pendingWidgetActions"

    private static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    static var snapshot: TodaySnapshot? {
        guard let data = defaults?.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(TodaySnapshot.self, from: data)
    }

    /// Vrai si le résumé a changé (les widgets ne sont rechargés qu'à ce moment-là).
    @discardableResult
    static func save(_ snapshot: TodaySnapshot) -> Bool {
        guard snapshot != self.snapshot, let data = try? JSONEncoder().encode(snapshot) else { return false }
        defaults?.set(data, forKey: snapshotKey)
        return true
    }

    static var pendingActions: [WidgetAction] {
        guard let data = defaults?.data(forKey: actionsKey) else { return [] }
        return (try? JSONDecoder().decode([WidgetAction].self, from: data)) ?? []
    }

    /// Dépose l'action et met le résumé à jour tout de suite : le widget montre le repas coché
    /// sans attendre l'ouverture de l'app.
    static func record(_ action: WidgetAction) {
        let actions = pendingActions + [action]
        if let data = try? JSONEncoder().encode(actions) { defaults?.set(data, forKey: actionsKey) }
        guard var snapshot else { return }
        switch action {
        case .mealTaken(let slot, _):
            guard let index = snapshot.meals.firstIndex(where: { $0.slot == slot }), !snapshot.meals[index].eaten else { return }
            snapshot.meals[index].eaten = true
            snapshot.kcalEaten += snapshot.meals[index].kcal
        case .workoutDone:
            snapshot.workoutDone = true
        }
        save(snapshot)
    }

    /// Les actions en attente, retirées de la file : l'app les applique une seule fois.
    static func takePendingActions() -> [WidgetAction] {
        let actions = pendingActions
        defaults?.removeObject(forKey: actionsKey)
        return actions
    }
}
