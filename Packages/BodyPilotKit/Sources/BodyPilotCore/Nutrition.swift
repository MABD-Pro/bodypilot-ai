import Foundation

public struct Macros: Sendable, Equatable, Codable {
    public var kcal: Double
    public var proteinG: Double
    public var carbsG: Double
    public var fatG: Double
    /// Fibres : 0 quand la source ne les donne pas (repas estimé par le modèle, restaurant sans repère).
    public var fiberG: Double

    public init(kcal: Double, proteinG: Double, carbsG: Double, fatG: Double, fiberG: Double = 0) {
        self.kcal = kcal
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.fiberG = fiberG
    }

    public static let zero = Macros(kcal: 0, proteinG: 0, carbsG: 0, fatG: 0)

    public static func + (lhs: Macros, rhs: Macros) -> Macros {
        Macros(
            kcal: lhs.kcal + rhs.kcal,
            proteinG: lhs.proteinG + rhs.proteinG,
            carbsG: lhs.carbsG + rhs.carbsG,
            fatG: lhs.fatG + rhs.fatG,
            fiberG: lhs.fiberG + rhs.fiberG
        )
    }

    public func scaled(by factor: Double) -> Macros {
        Macros(kcal: kcal * factor, proteinG: proteinG * factor, carbsG: carbsG * factor, fatG: fatG * factor, fiberG: fiberG * factor)
    }

    /// Part des calories apportée par les protéines, les glucides ou les lipides (0 à 1),
    /// avec 4, 4 et 9 kcal par gramme. Nil sans calories.
    public func energyShare(of nutrient: Nutrient) -> Double? {
        guard kcal > 0 else { return nil }
        switch nutrient {
        case .protein: return proteinG * 4 / kcal
        case .carbs: return carbsG * 4 / kcal
        case .fat: return fatG * 9 / kcal
        case .fiber: return nil
        }
    }

    public func grams(of nutrient: Nutrient) -> Double {
        switch nutrient {
        case .protein: proteinG
        case .carbs: carbsG
        case .fat: fatG
        case .fiber: fiberG
        }
    }

    private enum CodingKeys: String, CodingKey { case kcal, proteinG, carbsG, fatG, fiberG }

    /// Les repas enregistrés avant les fibres n'ont pas la clé : elles valent 0.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kcal = try container.decode(Double.self, forKey: .kcal)
        proteinG = try container.decode(Double.self, forKey: .proteinG)
        carbsG = try container.decode(Double.self, forKey: .carbsG)
        fatG = try container.decode(Double.self, forKey: .fatG)
        fiberG = try container.decodeIfPresent(Double.self, forKey: .fiberG) ?? 0
    }
}

/// Nutriments détaillés dans les repas et les bilans.
public enum Nutrient: String, CaseIterable, Sendable {
    case protein
    case carbs
    case fat
    case fiber
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

/// Ce qui a vraiment été mangé, par rapport au repas prévu. Saisie en une touche, pas de pesée.
public enum MealIntake: String, CaseIterable, Sendable, Codable {
    case skipped
    case light
    case asPlanned
    case hearty
    case veryHearty

    /// Part des calories prévues réellement mangée (estimation volontairement simple).
    public var factor: Double {
        switch self {
        case .skipped: 0
        case .light: 0.6
        case .asPlanned: 1
        case .hearty: 1.4
        case .veryHearty: 1.8
        }
    }
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

/// Aliment décrit par l'utilisateur (« une grande assiette de pâtes carbo »), avec son estimation.
public struct DescribedFood: Sendable, Equatable, Codable {
    public var name: String
    public var grams: Double
    /// Quantité lisible (« 1 grande assiette », « 2 œufs », « 200 g »).
    public var quantityLabel: String
    public var macros: Macros
    /// Quantité devinée faute de précision : le coach demande de la confirmer.
    public var needsPortion: Bool
    /// Estimé par le modèle de langage plutôt que tiré du catalogue.
    public var isEstimate: Bool

    public init(name: String, grams: Double, quantityLabel: String, macros: Macros, needsPortion: Bool = false, isEstimate: Bool = false) {
        self.name = name
        self.grams = grams
        self.quantityLabel = quantityLabel
        self.macros = macros
        self.needsPortion = needsPortion
        self.isEstimate = isEstimate
    }

    /// Portion confirmée : plus petite (×0,7), normale (×1) ou plus grande (×1,4).
    public func resized(by factor: Double, label: String) -> DescribedFood {
        DescribedFood(name: name, grams: grams * factor, quantityLabel: label, macros: macros.scaled(by: factor), needsPortion: false, isEstimate: isEstimate)
    }
}

/// Ce qui a vraiment été mangé à un repas, décrit en texte.
public struct DescribedMeal: Sendable, Equatable, Codable {
    /// Phrase de l'utilisateur, gardée pour la modifier plus tard.
    public var text: String
    public var foods: [DescribedFood]

    public init(text: String, foods: [DescribedFood]) {
        self.text = text
        self.foods = foods
    }

    public var macros: Macros { foods.reduce(.zero) { $0 + $1.macros } }

    /// Titre court pour la carte : les aliments, dans l'ordre (« Pâtes carbonara et coca »).
    public var title: String {
        guard let first = foods.first?.name else { return text }
        let names = [first] + foods.dropFirst().map { $0.name.lowercased() }
        return names.count == 1 ? first : names.dropLast().joined(separator: ", ") + " et " + names[names.count - 1]
    }
}

public struct PlannedMeal: Sendable, Equatable {
    public var slot: MealSlot
    public var title: String
    public var items: [MealItem]
    public var macros: Macros
    /// Repas pris dehors : des repères plutôt que des quantités.
    public var isEatingOut: Bool
    /// Déjà mangé : les macros sont alors celles estimées, pas celles prévues.
    public var intake: MealIntake?
    /// Décrit par l'utilisateur : les aliments et les macros sont ceux qu'il a vraiment mangés.
    public var described: DescribedMeal?

    public init(slot: MealSlot, title: String, items: [MealItem], macros: Macros, isEatingOut: Bool = false, intake: MealIntake? = nil, described: DescribedMeal? = nil) {
        self.slot = slot
        self.title = title
        self.items = items
        self.macros = macros
        self.isEatingOut = isEatingOut
        self.intake = intake
        self.described = described
    }

    /// Déjà mangé, d'une touche ou décrit.
    public var isEaten: Bool { intake != nil || described != nil }
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
    /// Ce qui a déjà été mangé aujourd'hui.
    public var eatenTotals: Macros { meals.filter(\.isEaten).reduce(.zero) { $0 + $1.macros } }
}

/// Contraintes alimentaires du jour déclarées par l'utilisateur.
public struct MealConstraints: Sendable, Equatable {
    /// Repas pris au restaurant, s'il y en a un.
    public var eatingOut: MealSlot?
    public var lowAppetite: Bool
    /// Repas déjà pris et ce qui a été mangé : les repas restants s'ajustent.
    public var eaten: [MealSlot: MealIntake]
    /// Repas décrits en texte : ils priment sur la saisie d'une touche.
    public var described: [MealSlot: DescribedMeal]

    public init(eatingOut: MealSlot? = nil, lowAppetite: Bool = false, eaten: [MealSlot: MealIntake] = [:], described: [MealSlot: DescribedMeal] = [:]) {
        self.eatingOut = eatingOut
        self.lowAppetite = lowAppetite
        self.eaten = eaten
        self.described = described
    }
}

public protocol NutritionPlanning: Sendable {
    /// - Parameter exerciseKcalPerDay: dépense moyenne des séances faites, ajoutée à la vie quotidienne.
    func targets(for profile: UserProfile, currentWeightKg: Double, exerciseKcalPerDay: Double, on date: Date) -> NutritionTargets
    func mealPlan(for targets: NutritionTargets, profile: UserProfile, on date: Date, constraints: MealConstraints) -> DayMealPlan
}

extension NutritionPlanning {
    public func targets(for profile: UserProfile, currentWeightKg: Double, on date: Date) -> NutritionTargets {
        targets(for: profile, currentWeightKg: currentWeightKg, exerciseKcalPerDay: 0, on: date)
    }
}
