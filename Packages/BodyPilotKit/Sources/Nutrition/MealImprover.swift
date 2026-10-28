import BodyPilotCore
import Foundation

/// Une façon d'améliorer un repas décrit, à appliquer d'une touche.
public struct MealSuggestion: Sendable, Equatable, Identifiable {
    public enum Goal: Sendable, Equatable {
        case lighter
        case moreProtein
    }

    public var goal: Goal
    /// « Pommes de terre au lieu des frites ».
    public var title: String
    /// « −210 kcal » ou « +31 g de protéines ».
    public var effect: String
    /// Le repas une fois la suggestion appliquée.
    public var meal: DescribedMeal

    public var id: String { title }
}

/// Suggestions déterministes et locales sur un repas décrit : deux échanges au plus qui allègent,
/// un ajout qui apporte des protéines. Peu de suggestions, pour rester une aide et pas une leçon.
public enum MealImprover {
    /// Allègements proposés au plus, sur des aliments différents.
    static let maxLighter = 2

    /// En dessous, un repas manque de protéines (environ 20 à 40 g par repas pour la synthèse
    /// musculaire, Schoenfeld et Aragon 2018 ; plus bas pour une collation).
    static func minimumProtein(for slot: MealSlot) -> Double {
        slot == .snack ? 12 : 20
    }

    /// Gain minimal pour qu'un échange vaille la peine d'être proposé.
    static let minimumSavingKcal = 50.0

    /// Échange : aliment remplacé, remplaçant (alias du lexique) et part conservée (1 = même poids).
    /// `nil` comme remplaçant : la même chose en moitié moins.
    static let swaps: [(from: String, to: String?, grams: Double?)] = [
        ("Frites", "pomme de terre", nil),
        ("Soda", "soda zero", nil),
        ("Jus de fruits", "fruit", 150),
        ("Pâtes carbonara", "pate bolognaise", nil),
        ("Croissant", "pain complet", 70),
        ("Pain au chocolat", "pain complet", 70),
        ("Céréales", "avoine", nil),
        ("Saucisse", "poulet", nil),
        ("Biscuits", "fruit", 150),
        ("Glace", "skyr", 150),
        ("Sauce", nil, nil),
        ("Fromage", nil, nil),
        ("Beurre", nil, nil),
        ("Chips", "amande", nil),
    ]

    public static func suggestions(for meal: DescribedMeal, slot: MealSlot) -> [MealSuggestion] {
        lighter(meal) + [moreProtein(meal, slot: slot)].compactMap { $0 }
    }

    /// Les échanges qui font gagner le plus de calories, un par aliment, du plus au moins utile.
    static func lighter(_ meal: DescribedMeal) -> [MealSuggestion] {
        var found: [(saving: Double, suggestion: MealSuggestion)] = []
        // Beurre et huile dans le même repas : deux matières grasses, une seule suffit.
        if let butter = meal.foods.firstIndex(where: { $0.name == "Beurre" }),
           meal.foods.contains(where: { $0.name == Foods.oliveOil.name }) {
            let saving = meal.foods[butter].macros.kcal
            var foods = meal.foods
            foods.remove(at: butter)
            if saving >= minimumSavingKcal {
                found.append((saving, MealSuggestion(
                    goal: .lighter, title: "Beurre ou huile, pas les deux", effect: "−\(saving.frenchInteger) kcal",
                    meal: DescribedMeal(text: meal.text, foods: foods)
                )))
            }
        }
        for (index, food) in meal.foods.enumerated() {
            if food.name == "Beurre", !found.isEmpty { continue }
            guard let swap = swaps.first(where: { $0.from == food.name }) else { continue }
            let replacement: DescribedFood
            let title: String
            if let alias = swap.to {
                guard let entry = entry(alias) else { continue }
                let grams = swap.grams ?? food.grams
                replacement = described(entry, grams: grams, label: swap.grams == nil ? food.quantityLabel : entry.portionLabel)
                title = "\(entry.food.name) au lieu de \(food.name.lowercased())"
            } else {
                replacement = food.resized(by: 0.5, label: "Moitié moins")
                title = "Moitié moins de \(food.name.lowercased())"
            }
            let saving = food.macros.kcal - replacement.macros.kcal
            guard saving >= minimumSavingKcal, !found.contains(where: { $0.suggestion.title == title }) else { continue }
            var foods = meal.foods
            foods[index] = replacement
            found.append((saving, MealSuggestion(
                goal: .lighter, title: title, effect: "−\(saving.frenchInteger) kcal",
                meal: DescribedMeal(text: meal.text, foods: foods)
            )))
        }
        return found.sorted { $0.saving > $1.saving }.prefix(maxLighter).map(\.suggestion)
    }

    /// Familles d'aliments interchangeables : « Remplacer » propose les autres membres de la famille.
    static let families: [[String]] = [
        ["Blanc de poulet", "Steak", "Saumon", "Thon au naturel", "Poisson", "Jambon", "Œufs", "Tofu ferme"],
        ["Pâtes", "Riz", "Pommes de terre", "Patate douce cuite", "Quinoa cuit", "Lentilles cuites", "Pois chiches cuits", "Frites"],
        ["Pain", "Pain complet", "Baguette", "Croissant", "Pain au chocolat", "Céréales", "Flocons d'avoine"],
        ["Fromage", "Fromage blanc 0 %", "Skyr nature", "Yaourt grec 0 %", "Yaourt"],
        ["Beurre", "Huile d'olive", "Avocat", "Houmous", "Sauce"],
        ["Banane", "Pomme", "Orange", "Fruit", "Fruits rouges", "Dattes"],
        ["Légumes", "Brocoli", "Haricots verts", "Courgette", "Tomates", "Salade verte"],
        ["Chips", "Olives", "Amandes", "Noix", "Chocolat", "Biscuits", "Glace", "Barre protéinée"],
        ["Soda", "Soda zéro", "Jus de fruits", "Eau", "Café", "Bière", "Vin"],
    ]

    /// Équivalents d'un aliment, les plus légers d'abord, à la même part de portion :
    /// une demi-portion de fromage devient une demi-portion de fromage blanc.
    public static func alternatives(for food: DescribedFood) -> [DescribedFood] {
        guard let family = families.first(where: { $0.contains(food.name) }),
              let current = FoodLexicon.entries.first(where: { $0.food.name == food.name })
        else { return [] }
        let share = current.portionGrams > 0 ? food.grams / current.portionGrams : 1
        return family.filter { $0 != food.name }
            .compactMap { name in FoodLexicon.entries.first { $0.food.name == name } }
            .map { entry in
                let grams = (entry.portionGrams * share).rounded()
                let label = abs(share - 1) < 0.05 ? entry.portionLabel : "≈ \(Int(grams)) g"
                return described(entry, grams: grams, label: label)
            }
            .sorted { $0.macros.kcal < $1.macros.kcal }
    }

    /// Un ajout riche en protéines quand le repas en manque : un skyr le matin et en collation,
    /// une portion de poulet au déjeuner et au dîner (un skyr si le plat a déjà sa viande).
    static func moreProtein(_ meal: DescribedMeal, slot: MealSlot) -> MealSuggestion? {
        guard meal.macros.proteinG < minimumProtein(for: slot) else { return nil }
        let hasMainProtein = meal.foods.contains { $0.grams > 0 && $0.macros.proteinG / $0.grams * 100 >= 15 }
        let useMeat = (slot == .lunch || slot == .dinner) && !hasMainProtein
        guard let entry = entry(useMeat ? "poulet" : "skyr") else { return nil }
        let grams = useMeat ? 100.0 : 150
        let added = described(entry, grams: grams, label: useMeat ? "100 g" : "1 pot")
        return MealSuggestion(
            goal: .moreProtein,
            title: useMeat ? "Ajoute 100 g de poulet" : "Ajoute un skyr",
            effect: "+\(Int(added.macros.proteinG.rounded())) g de protéines",
            meal: DescribedMeal(text: meal.text, foods: meal.foods + [added])
        )
    }

    private static func entry(_ alias: String) -> LexiconEntry? {
        FoodLexicon.entries.first { $0.aliases.contains(alias) }
    }

    private static func described(_ entry: LexiconEntry, grams: Double, label: String) -> DescribedFood {
        DescribedFood(name: entry.food.name, grams: grams, quantityLabel: label, macros: entry.food.per100g.scaled(by: grams / 100))
    }
}

/// Un repas décrit un jour récent, à reprendre d'une touche.
public struct RecentMeal: Sendable, Equatable {
    public var day: Date
    public var slot: MealSlot
    public var meal: DescribedMeal
}

public enum RecentMeals {
    /// Repas décrits sur les `days` derniers jours (aujourd'hui exclu) : ceux du même moment de
    /// la journée d'abord, puis les autres, du plus récent au plus ancien, sans doublon.
    public static func list(
        for slot: MealSlot, history: [(day: Date, meals: [MealSlot: DescribedMeal])],
        today: Date, days: Int = 7, limit: Int = 8, calendar: Calendar = .current
    ) -> [RecentMeal] {
        let start = calendar.startOfDay(for: today)
        guard let since = calendar.date(byAdding: .day, value: -days, to: start) else { return [] }
        let all = history
            .filter { $0.day >= since && $0.day < start }
            .sorted { $0.day > $1.day }
            .flatMap { entry in
                MealSlot.allCases.compactMap { s in entry.meals[s].map { RecentMeal(day: entry.day, slot: s, meal: $0) } }
            }
        var seen: Set<String> = []
        return (all.filter { $0.slot == slot } + all.filter { $0.slot != slot })
            .filter { seen.insert($0.meal.title.lowercased()).inserted }
            .prefix(limit)
            .map { $0 }
    }
}
