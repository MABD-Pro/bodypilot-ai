import BodyPilotCore
import Foundation

/// Moment de la journée où la faim revient.
public enum HungerWindow: String, CaseIterable, Sendable {
    /// 6 h à 11 h : le petit-déjeuner ne tient pas.
    case morning
    /// 11 h à 14 h : avant le déjeuner, encore le petit-déjeuner.
    case beforeLunch
    /// 14 h à 19 h : le déjeuner ne tient pas jusqu'au dîner.
    case afternoon
    /// 19 h à 6 h : soirée et nuit, le dîner ne tient pas.
    case evening

    public init(hour: Int) {
        switch hour {
        case 6..<11: self = .morning
        case 11..<14: self = .beforeLunch
        case 14..<19: self = .afternoon
        default: self = .evening
        }
    }

    /// Le repas d'avant, celui qui doit mieux caler.
    public var mealBefore: MealSlot {
        switch self {
        case .morning, .beforeLunch: .breakfast
        case .afternoon: .lunch
        case .evening: .dinner
        }
    }

    public var label: String {
        switch self {
        case .morning: "le matin"
        case .beforeLunch: "avant le déjeuner"
        case .afternoon: "l'après-midi"
        case .evening: "le soir"
        }
    }
}

/// Faim qui revient au même moment de la journée : le repas d'avant est rendu plus rassasiant
/// (plus de protéines, voir `MealConstraints.fullerMeal`). Une faim isolée ne change rien.
public struct HungerPattern: Sendable, Equatable {
    public var window: HungerWindow
    /// Jours différents où la faim a été notée dans ce créneau, sur les 14 derniers.
    public var days: Int

    public var message: String {
        let meal = switch window.mealBefore {
        case .breakfast: "petit-déjeuner"
        case .lunch: "déjeuner"
        case .snack: "goûter"
        case .dinner: "dîner"
        }
        return "Faim \(window.label) \(days) jours sur \(HungerPatterns.windowDays) : ton \(meal) prend plus de protéines. Ajoute aussi des légumes ou des légumineuses, les fibres calent."
    }
}

public enum HungerPatterns {
    public static let windowDays = 14
    /// Jours différents nécessaires pour parler d'habitude (choix BodyPilot).
    public static let minimumDays = 3

    /// La faim (au moins « Faim », pas « Petite faim ») la plus fréquente par créneau, sur 14 jours.
    public static func pattern(_ notes: [HungerNote], on date: Date, calendar: Calendar) -> HungerPattern? {
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date
        guard let start = calendar.date(byAdding: .day, value: -windowDays, to: end) else { return nil }
        var days: [HungerWindow: Set<Date>] = [:]
        for note in notes where note.level.rawValue >= HungerLevel.hungry.rawValue && note.date >= start && note.date < end {
            let window = HungerWindow(hour: calendar.component(.hour, from: note.date))
            // La nuit après minuit compte pour la soirée de la veille.
            let hour = calendar.component(.hour, from: note.date)
            let day = calendar.startOfDay(for: window == .evening && hour < 6 ? note.date.addingTimeInterval(-6 * 3_600) : note.date)
            days[window, default: []].insert(day)
        }
        // À égalité, le créneau le plus tôt : caler le repas du matin aide toute la journée.
        let best = HungerWindow.allCases.compactMap { window in days[window].map { (window, $0.count) } }
            .filter { $0.1 >= minimumDays }
            .max { lhs, rhs in lhs.1 < rhs.1 }
        return best.map { HungerPattern(window: $0.0, days: $0.1) }
    }
}
