import BodyPilotCore
import Foundation

/// Repas que l'utilisateur mange souvent au même moment de la journée : le coach les propose
/// à la place de ses modèles, portions ajustées au jour (`MealPlanner.habitMeal`).
public enum HabitMeals {
    /// Fenêtre observée : quatre semaines, aujourd'hui exclu.
    public static let windowDays = 28
    /// Jours différents où le même repas a été décrit à ce moment de la journée.
    public static let minimumDays = 3

    /// Pour chaque moment de la journée, le repas le plus fréquent (au moins 3 jours sur 4 semaines),
    /// tel qu'il a été décrit la dernière fois. À égalité, le plus récent.
    public static func usual(
        history: [(day: Date, meals: [MealSlot: DescribedMeal])],
        today: Date, calendar: Calendar = .current
    ) -> [MealSlot: DescribedMeal] {
        let start = calendar.startOfDay(for: today)
        guard let since = calendar.date(byAdding: .day, value: -windowDays, to: start) else { return [:] }
        let recent = history.filter { $0.day >= since && $0.day < start }.sorted { $0.day > $1.day }
        var result: [MealSlot: DescribedMeal] = [:]
        for slot in MealSlot.allCases {
            // Même repas : mêmes aliments, quelles que soient les quantités ou la phrase.
            var days: [String: Set<Date>] = [:]
            var latest: [String: (day: Date, meal: DescribedMeal)] = [:]
            for entry in recent {
                guard let meal = entry.meals[slot], !meal.foods.isEmpty else { continue }
                let key = signature(of: meal)
                days[key, default: []].insert(calendar.startOfDay(for: entry.day))
                if latest[key] == nil { latest[key] = (entry.day, meal) }
            }
            let best = days.filter { $0.value.count >= minimumDays }
                .max { lhs, rhs in
                    lhs.value.count != rhs.value.count
                        ? lhs.value.count < rhs.value.count
                        : (latest[lhs.key]?.day ?? .distantPast) < (latest[rhs.key]?.day ?? .distantPast)
                }
            if let best, let meal = latest[best.key]?.meal { result[slot] = meal }
        }
        return result
    }

    static func signature(of meal: DescribedMeal) -> String {
        Set(meal.foods.map { $0.name.lowercased() }).sorted().joined(separator: "|")
    }
}

/// Portions que l'utilisateur prend d'habitude, apprises de ses repas décrits : « des pâtes »
/// sans quantité prend sa portion habituelle au lieu d'une question.
public enum UsualPortions {
    /// Fenêtre observée : deux mois.
    public static let windowDays = 60
    /// Fois où l'aliment a été noté avec une quantité connue ou confirmée.
    public static let minimumCount = 2

    /// Par nom d'aliment, la portion médiane (l'aliment tel qu'il a été noté ce jour-là).
    public static func learn(
        history: [(day: Date, meals: [MealSlot: DescribedMeal])],
        today: Date, calendar: Calendar = .current
    ) -> [String: DescribedFood] {
        let start = calendar.startOfDay(for: today)
        guard let since = calendar.date(byAdding: .day, value: -windowDays, to: start) else { return [:] }
        var byName: [String: [DescribedFood]] = [:]
        for entry in history where entry.day >= since {
            for meal in entry.meals.values {
                // Une quantité devinée et jamais confirmée n'apprend rien.
                for food in meal.foods where !food.needsPortion && food.grams > 0 {
                    byName[food.name, default: []].append(food)
                }
            }
        }
        return byName.filter { $0.value.count >= minimumCount }.mapValues { foods in
            let sorted = foods.sorted { $0.grams < $1.grams }
            return sorted[(sorted.count - 1) / 2]
        }
    }

    /// Les aliments sans quantité prennent la portion habituelle, sans question à poser.
    public static func apply(_ usual: [String: DescribedFood], to parse: MealParse) -> MealParse {
        guard !usual.isEmpty else { return parse }
        var parse = parse
        parse.foods = parse.foods.map { food in
            guard food.needsPortion, food.grams > 0, let habit = usual[food.name] else { return food }
            let label = "Ta portion habituelle, environ \(Int((habit.grams / 5).rounded() * 5))\u{00A0}g"
            return food.resized(by: habit.grams / food.grams, label: label)
        }
        return parse
    }
}
