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

    public func targets(for profile: UserProfile, currentWeightKg: Double, exerciseKcalPerDay: Double, on date: Date) -> NutritionTargets {
        calculator.targets(for: profile, currentWeightKg: currentWeightKg, exerciseKcalPerDay: exerciseKcalPerDay, on: date)
    }

    /// Pas faim : on vise 85 % des calories, sans descendre sous le plancher de sécurité.
    static let lowAppetiteRatio = 0.85

    public func mealPlan(for targets: NutritionTargets, profile: UserProfile, on date: Date, constraints: MealConstraints) -> DayMealPlan {
        var shares = Self.shares
        var notes: [String] = []
        var dayKcal = targets.macros.kcal

        if constraints.lowAppetite {
            dayKcal = max(dayKcal * Self.lowAppetiteRatio, min(dayKcal, SafetyLimits.minimumKcal(for: profile.sex)))
            notes.append("Pas faim : portions plus petites et riches en protéines. Mange ce qui passe, sans te forcer : une journée plus légère ne change rien à ta progression.")
        }

        if let restaurant = constraints.eatingOut {
            // Un repas au restaurant est souvent plus copieux : il récupère le budget de la collation.
            if restaurant != .snack {
                shares[restaurant, default: 0] += shares[.snack] ?? 0
                shares[.snack] = 0
            }
            notes.append("Restaurant : la collation est supprimée pour laisser de la marge. Pas de calcul au restaurant, juste les repères.")
        }

        // Repas déjà pris : ce qui a été mangé compte, le reste de la journée s'ajuste.
        // Les repas sont repris dans l'ordre de la journée : chacun compte sur la portion
        // affichée au moment où il a été mangé, déjà ajustée par les repas pris avant lui.
        let baseKcal = shares.mapValues { dayKcal * $0 }
        var shownKcal = baseKcal
        var eatenKcal = 0.0
        var counted: Set<MealSlot> = []
        var remainingScale = 1.0
        var wanted = 1.0
        for (position, slot) in MealSlot.allCases.enumerated() {
            guard constraints.described[slot] != nil || constraints.eaten[slot] != nil else { continue }
            // Un repas plus tôt dans la journée, non noté, a sans doute été mangé comme prévu :
            // on le fige à sa portion affichée, seuls les repas suivants compensent.
            for earlier in MealSlot.allCases.prefix(position) where !counted.contains(earlier) {
                let shown = (baseKcal[earlier] ?? 0) * remainingScale
                shownKcal[earlier] = shown
                eatenKcal += shown
                counted.insert(earlier)
            }
            if let described = constraints.described[slot] {
                // Repas décrit : on compte ce qui a vraiment été mangé, quel que soit le plan.
                eatenKcal += described.macros.kcal
            } else if let intake = constraints.eaten[slot], let base = baseKcal[slot] {
                shownKcal[slot] = base * remainingScale
                eatenKcal += base * remainingScale * intake.factor
            } else {
                continue
            }
            counted.insert(slot)
            let remainingBase = baseKcal.filter { !counted.contains($0.key) }.values.reduce(0, +)
            guard remainingBase > 0 else { remainingScale = 1; break }
            wanted = (dayKcal - eatenKcal) / remainingBase
            // Écart négligeable (repas pris comme prévu) : on ne touche à rien.
            remainingScale = abs(wanted - 1) > 0.02
                ? min(max(wanted, Self.remainingScaleRange.lowerBound), Self.remainingScaleRange.upperBound)
                : 1
        }
        if remainingScale != 1, let note = Self.intakeNote(wanted: wanted, applied: remainingScale) { notes.append(note) }

        return plannedMeals(day: dayIndex(of: date), baseKcal: baseKcal, shownKcal: shownKcal, fixed: counted, scale: remainingScale, targets: targets, constraints: constraints, notes: notes)
    }

    private func plannedMeals(
        day: Int,
        baseKcal: [MealSlot: Double],
        shownKcal: [MealSlot: Double],
        fixed: Set<MealSlot>,
        scale remainingScale: Double,
        targets: NutritionTargets,
        constraints: MealConstraints,
        notes: [String]
    ) -> DayMealPlan {
        let dayKcal = baseKcal.values.reduce(0, +)
        let meals = MealSlot.allCases.compactMap { slot -> PlannedMeal? in
            if let described = constraints.described[slot] {
                return PlannedMeal(
                    slot: slot,
                    title: described.title,
                    items: described.foods.map { MealItem(name: $0.name, grams: $0.grams, quantityLabel: $0.quantityLabel) },
                    macros: described.macros,
                    described: described
                )
            }
            let base = baseKcal[slot] ?? 0
            guard base > 0 else { return nil }
            let intake = constraints.eaten[slot]
            let kcal = fixed.contains(slot) ? shownKcal[slot] ?? base : base * remainingScale
            var meal: PlannedMeal
            if slot == constraints.eatingOut {
                meal = restaurantMeal(slot: slot, kcal: kcal, proteinG: targets.macros.proteinG * base / max(dayKcal, 1))
            } else {
                let options = MealTemplates.all.filter { $0.slot == slot }
                var template = options[day % options.count]
                if constraints.lowAppetite, slot == .snack {
                    // Collation dense et facile à avaler.
                    template = MealTemplates.snacks[1]
                }
                meal = portioned(template, targetKcal: kcal)
            }
            if let intake {
                meal.macros = meal.macros.scaled(by: intake.factor)
                meal.intake = intake
            }
            return meal
        }
        return DayMealPlan(meals: meals, notes: notes)
    }

    /// Les repas restants bougent dans des limites raisonnables : on ne saute pas un repas
    /// pour compenser un excès, et on ne double pas le dîner après un déjeuner sauté.
    static let remainingScaleRange = 0.6...1.4

    static func intakeNote(wanted: Double, applied: Double) -> String? {
        if wanted < 0.95 {
            return applied > wanted
                ? "Repas copieux : la suite est allégée sans être sautée. Une journée au-dessus ne change pas ta tendance."
                : "Repas copieux : les repas suivants sont un peu plus légers pour garder l'équilibre de la journée."
        }
        if wanted > 1.05 {
            return applied < wanted
                ? "Repas léger ou sauté : un peu plus aux repas suivants, sans tout rattraper. Les protéines d'abord."
                : "Repas léger : les repas suivants sont un peu plus copieux pour couvrir tes besoins."
        }
        return nil
    }

    /// Repères simples pour commander, plutôt que des grammes impossibles à vérifier.
    func restaurantMeal(slot: MealSlot, kcal: Double, proteinG: Double) -> PlannedMeal {
        let guidance = [
            ("Une protéine en plat principal", "poisson, volaille, viande grillée"),
            ("Légumes ou salade", "à volonté"),
            ("Féculents ou pain", "une portion, la taille du poing"),
            ("Sauce, dessert ou alcool", "un seul des trois"),
        ]
        return PlannedMeal(
            slot: slot,
            title: "Au restaurant",
            items: guidance.map { MealItem(name: $0.0, grams: 0, quantityLabel: $0.1) },
            macros: Macros(kcal: kcal, proteinG: proteinG, carbsG: 0, fatG: 0),
            isEatingOut: true
        )
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
