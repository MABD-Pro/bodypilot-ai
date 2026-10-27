import BodyPilotCore
import Foundation

/// Planificateur de repas par règles : modèles de repas tournants, portions ajustées aux besoins du jour.
public struct MealPlanner: NutritionPlanning {
    public var calculator: EnergyCalculator

    /// Part des calories par repas.
    static let shares: [MealSlot: Double] = [.breakfast: 0.25, .lunch: 0.35, .snack: 0.10, .dinner: 0.30]
    /// Les portions restent réalistes : jamais moins de la moitié ni plus du double du modèle.
    static let portionRange = 0.5...2.0

    public init(calculator: EnergyCalculator = EnergyCalculator()) {
        self.calculator = calculator
    }

    public func targets(for profile: UserProfile, currentWeightKg: Double, on date: Date) -> NutritionTargets {
        calculator.targets(for: profile, currentWeightKg: currentWeightKg, on: date)
    }

    public func mealPlan(for targets: NutritionTargets, on date: Date) -> DayMealPlan {
        let day = dayIndex(of: date)
        let meals = MealSlot.allCases.map { slot -> PlannedMeal in
            let options = MealTemplates.all.filter { $0.slot == slot }
            let template = options[day % options.count]
            let kcal = targets.macros.kcal * (Self.shares[slot] ?? 0)
            return portioned(template, targetKcal: kcal)
        }
        return DayMealPlan(meals: meals)
    }

    func portioned(_ template: MealTemplate, targetKcal: Double) -> PlannedMeal {
        let baseKcal = template.ingredients.reduce(0) { $0 + $1.food.per100g.kcal * $1.grams / 100 }
        let factor = min(max(targetKcal / baseKcal, Self.portionRange.lowerBound), Self.portionRange.upperBound)

        var items: [MealItem] = []
        var macros = Macros.zero
        for ingredient in template.ingredients {
            let (rounded, label) = quantity(of: ingredient.food, grams: ingredient.grams * factor)
            items.append(MealItem(name: ingredient.food.name, grams: rounded, quantityLabel: label))
            macros = macros + ingredient.food.per100g.scaled(by: rounded / 100)
        }
        return PlannedMeal(slot: template.slot, title: template.title, items: items, macros: macros)
    }

    private func quantity(of food: Food, grams: Double) -> (Double, String) {
        if let unit = food.unit {
            let count = max(1, Int((grams / unit.grams).rounded()))
            return (Double(count) * unit.grams, "\(count) \(count > 1 ? unit.plural : unit.singular)")
        }
        let rounded = max(5, (grams / 5).rounded() * 5)
        return (rounded, "\(Int(rounded)) g")
    }

    /// Jour stable dans le temps, pour faire tourner les repas sans état.
    private func dayIndex(of date: Date) -> Int {
        let start = calculator.calendar.startOfDay(for: date)
        return max(0, Int((start.timeIntervalSinceReferenceDate / 86_400).rounded()))
    }
}
