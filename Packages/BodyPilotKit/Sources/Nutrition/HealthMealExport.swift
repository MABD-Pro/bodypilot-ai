import BodyPilotCore
import Foundation

/// Repas mangé tel qu'il part dans Santé : une entrée par repas et par jour.
public struct HealthMealEntry: Sendable, Equatable {
    /// Stable pour un repas d'un jour donné : une modification remplace l'entrée au lieu d'en ajouter une.
    public var id: String
    public var slot: MealSlot
    public var title: String
    public var date: Date
    public var macros: Macros

    /// Résumé comparé à celui du dernier envoi : rien n'est réécrit tant qu'il ne change pas.
    /// L'heure n'en fait pas partie : elle glisse pour un repas noté en avance.
    public var fingerprint: String {
        [title, "\(Int(macros.kcal.rounded()))", "\(Int(macros.proteinG.rounded()))",
         "\(Int(macros.carbsG.rounded()))", "\(Int(macros.fatG.rounded()))"].joined(separator: "|")
    }
}

/// Ce que Santé doit contenir pour les repas d'un jour : les repas mangés, avec leurs vraies macros.
///
/// Un repas sauté, pas encore pris ou annulé n'a pas d'entrée : l'app supprime alors celle
/// envoyée plus tôt, pour ne jamais compter deux fois ni garder un repas retiré.
public struct HealthMealExport: Sendable {
    public var calendar: Calendar

    /// Heure habituelle de chaque repas : Santé range les aliments par heure.
    static let usualTime: [MealSlot: (hour: Int, minute: Int)] = [
        .breakfast: (8, 0), .lunch: (12, 30), .snack: (16, 30), .dinner: (20, 0),
    ]

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func id(for slot: MealSlot, on day: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        let date = [parts.year ?? 0, parts.month ?? 0, parts.day ?? 0].map { $0 < 10 ? "0\($0)" : "\($0)" }.joined(separator: "-")
        return "bodypilot-\(date)-\(slot.rawValue)"
    }

    /// Les repas mangés du jour. Les autres repas (`id(for:on:)`) sont à retirer de Santé.
    public func entries(for plan: DayMealPlan, on day: Date, now: Date) -> [HealthMealEntry] {
        plan.meals.compactMap { meal in
            guard meal.isEaten, meal.macros.kcal >= 1 else { return nil }
            let time = Self.usualTime[meal.slot] ?? (12, 0)
            let usual = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: day) ?? day
            // Un repas noté en avance (dîner pris à 18 h) ne part pas dans le futur.
            return HealthMealEntry(id: id(for: meal.slot, on: day), slot: meal.slot, title: meal.title, date: min(usual, now), macros: meal.macros)
        }
    }
}
