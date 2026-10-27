import Foundation

public struct Macros: Sendable, Equatable, Codable {
    public var kcal: Double
    public var proteinG: Double
    public var carbsG: Double
    public var fatG: Double

    public init(kcal: Double, proteinG: Double, carbsG: Double, fatG: Double) {
        self.kcal = kcal
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
    }

    public static let zero = Macros(kcal: 0, proteinG: 0, carbsG: 0, fatG: 0)

    public static func + (lhs: Macros, rhs: Macros) -> Macros {
        Macros(
            kcal: lhs.kcal + rhs.kcal,
            proteinG: lhs.proteinG + rhs.proteinG,
            carbsG: lhs.carbsG + rhs.carbsG,
            fatG: lhs.fatG + rhs.fatG
        )
    }

    public func scaled(by factor: Double) -> Macros {
        Macros(kcal: kcal * factor, proteinG: proteinG * factor, carbsG: carbsG * factor, fatG: fatG * factor)
    }
}

/// Besoins du jour, calculés de façon déterministe et explicables.
public struct NutritionTargets: Sendable, Equatable {
    public var macros: Macros
    /// Dépense journalière estimée (avant ajustement à l'objectif).
    public var maintenanceKcal: Double
    /// Explication courte du calcul, montrée à l'utilisateur.
    public var rationale: String

    public init(macros: Macros, maintenanceKcal: Double, rationale: String) {
        self.macros = macros
        self.maintenanceKcal = maintenanceKcal
        self.rationale = rationale
    }
}

public enum MealSlot: String, CaseIterable, Sendable, Codable {
    case breakfast
    case lunch
    case snack
    case dinner
}

public struct MealItem: Sendable, Equatable {
    public var name: String
    public var grams: Double
    /// Quantité lisible (« 2 œufs », « 120 g »).
    public var quantityLabel: String

    public init(name: String, grams: Double, quantityLabel: String) {
        self.name = name
        self.grams = grams
        self.quantityLabel = quantityLabel
    }
}

public struct PlannedMeal: Sendable, Equatable {
    public var slot: MealSlot
    public var title: String
    public var items: [MealItem]
    public var macros: Macros
    /// Repas pris dehors : des repères plutôt que des quantités.
    public var isEatingOut: Bool

    public init(slot: MealSlot, title: String, items: [MealItem], macros: Macros, isEatingOut: Bool = false) {
        self.slot = slot
        self.title = title
        self.items = items
        self.macros = macros
        self.isEatingOut = isEatingOut
    }
}

public struct DayMealPlan: Sendable, Equatable {
    public var meals: [PlannedMeal]
    /// Ajustements appliqués, en clair.
    public var notes: [String]

    public init(meals: [PlannedMeal], notes: [String] = []) {
        self.meals = meals
        self.notes = notes
    }

    public var totals: Macros { meals.reduce(.zero) { $0 + $1.macros } }
}

/// Contraintes alimentaires du jour déclarées par l'utilisateur.
public struct MealConstraints: Sendable, Equatable {
    /// Repas pris au restaurant, s'il y en a un.
    public var eatingOut: MealSlot?
    public var lowAppetite: Bool

    public init(eatingOut: MealSlot? = nil, lowAppetite: Bool = false) {
        self.eatingOut = eatingOut
        self.lowAppetite = lowAppetite
    }
}

public protocol NutritionPlanning: Sendable {
    func targets(for profile: UserProfile, currentWeightKg: Double, on date: Date) -> NutritionTargets
    func mealPlan(for targets: NutritionTargets, profile: UserProfile, on date: Date, constraints: MealConstraints) -> DayMealPlan
}
