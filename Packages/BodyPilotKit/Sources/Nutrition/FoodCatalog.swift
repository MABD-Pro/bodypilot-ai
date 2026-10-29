import BodyPilotCore

/// Aliment de base, valeurs pour 100 g.
///
/// Valeurs moyennes arrondies (ordre de grandeur des tables Ciqual), suffisantes pour planifier.
/// Une vraie base nutritionnelle remplacera ce catalogue.
struct Food: Sendable {
    let name: String
    let per100g: Macros
    /// Unité naturelle (un œuf, une banane) pour afficher des quantités lisibles.
    let unit: FoodUnit?

    /// Fibres : valeur Ciqual 2025 de l'aliment le plus proche (fruits rouges : moyenne framboise,
    /// fraise, myrtille), 0 quand Ciqual n'en mesure pas.
    init(_ name: String, kcal: Double, protein: Double, carbs: Double, fat: Double, fiber: Double = 0, unit: FoodUnit? = nil) {
        self.name = name
        self.per100g = Macros(kcal: kcal, proteinG: protein, carbsG: carbs, fatG: fat, fiberG: fiber)
        self.unit = unit
    }
}

struct FoodUnit: Sendable {
    let grams: Double
    let singular: String
    let plural: String
}

struct Ingredient: Sendable {
    let food: Food
    let grams: Double

    init(_ food: Food, _ grams: Double) {
        self.food = food
        self.grams = grams
    }
}

enum Foods {
    static let oats = Food("Flocons d'avoine", kcal: 372, protein: 13.5, carbs: 58.7, fat: 7, fiber: 11.2)
    static let greekYogurt = Food("Yaourt grec 0 %", kcal: 59, protein: 10.3, carbs: 3.6, fat: 0.4)
    static let skyr = Food("Skyr nature", kcal: 63, protein: 11, carbs: 4, fat: 0.2)
    static let cottageCheese = Food("Fromage blanc 0 %", kcal: 47, protein: 7.5, carbs: 4, fat: 0.2)
    static let banana = Food("Banane", kcal: 89, protein: 1.1, carbs: 22.8, fat: 0.3, fiber: 2.7, unit: FoodUnit(grams: 120, singular: "banane", plural: "bananes"))
    static let berries = Food("Fruits rouges", kcal: 57, protein: 0.7, carbs: 14.5, fat: 0.3, fiber: 3.5)
    static let apple = Food("Pomme", kcal: 52, protein: 0.3, carbs: 13.8, fat: 0.2, fiber: 1.4, unit: FoodUnit(grams: 150, singular: "pomme", plural: "pommes"))
    static let almonds = Food("Amandes", kcal: 579, protein: 21, carbs: 21.6, fat: 49.9, fiber: 12.5)
    static let eggs = Food("Œufs", kcal: 143, protein: 12.6, carbs: 0.7, fat: 9.5, unit: FoodUnit(grams: 55, singular: "œuf", plural: "œufs"))
    static let wholeBread = Food("Pain complet", kcal: 247, protein: 13, carbs: 41, fat: 3.4, fiber: 7.3)
    static let avocado = Food("Avocat", kcal: 160, protein: 2, carbs: 8.5, fat: 14.7, fiber: 3.6)
    static let chicken = Food("Blanc de poulet", kcal: 165, protein: 31, carbs: 0, fat: 3.6)
    static let salmon = Food("Saumon", kcal: 208, protein: 20, carbs: 0, fat: 13)
    static let tuna = Food("Thon au naturel", kcal: 116, protein: 26, carbs: 0, fat: 1)
    static let leanBeef = Food("Bœuf haché 5 %", kcal: 125, protein: 21, carbs: 0, fat: 5)
    static let tofu = Food("Tofu ferme", kcal: 144, protein: 17, carbs: 3, fat: 8.7)
    static let rice = Food("Riz basmati cuit", kcal: 130, protein: 2.7, carbs: 28, fat: 0.3)
    static let pasta = Food("Pâtes complètes cuites", kcal: 124, protein: 5.3, carbs: 26.5, fat: 0.5, fiber: 5.1)
    static let quinoa = Food("Quinoa cuit", kcal: 120, protein: 4.4, carbs: 21.3, fat: 1.9, fiber: 3.8)
    static let sweetPotato = Food("Patate douce cuite", kcal: 90, protein: 2, carbs: 20.7, fat: 0.2, fiber: 2.9)
    static let lentils = Food("Lentilles cuites", kcal: 116, protein: 9, carbs: 20, fat: 0.4, fiber: 8.45)
    static let chickpeas = Food("Pois chiches cuits", kcal: 164, protein: 8.9, carbs: 27.4, fat: 2.6, fiber: 8.2)
    static let broccoli = Food("Brocoli", kcal: 34, protein: 2.8, carbs: 6.6, fat: 0.4, fiber: 2.6)
    static let greenBeans = Food("Haricots verts", kcal: 31, protein: 1.8, carbs: 7, fat: 0.2, fiber: 4)
    static let zucchini = Food("Courgette", kcal: 17, protein: 1.2, carbs: 3.1, fat: 0.3, fiber: 1.5)
    static let tomato = Food("Tomates", kcal: 18, protein: 0.9, carbs: 3.9, fat: 0.2, fiber: 1)
    static let feta = Food("Feta", kcal: 264, protein: 14, carbs: 4, fat: 21, fiber: 0.2)
    static let oliveOil = Food("Huile d'olive", kcal: 884, protein: 0, carbs: 0, fat: 100)
}

struct MealTemplate: Sendable {
    let slot: MealSlot
    let title: String
    let ingredients: [Ingredient]
}

enum MealTemplates {
    static let all: [MealTemplate] = breakfasts + lunches + snacks + dinners

    static let breakfasts: [MealTemplate] = [
        MealTemplate(slot: .breakfast, title: "Porridge protéiné aux fruits rouges", ingredients: [
            Ingredient(Foods.oats, 60), Ingredient(Foods.skyr, 150), Ingredient(Foods.berries, 100), Ingredient(Foods.almonds, 10),
        ]),
        MealTemplate(slot: .breakfast, title: "Tartines œufs et avocat", ingredients: [
            Ingredient(Foods.wholeBread, 70), Ingredient(Foods.eggs, 110), Ingredient(Foods.avocado, 50), Ingredient(Foods.tomato, 80),
        ]),
        MealTemplate(slot: .breakfast, title: "Bol yaourt grec, banane et amandes", ingredients: [
            Ingredient(Foods.greekYogurt, 200), Ingredient(Foods.banana, 120), Ingredient(Foods.oats, 30), Ingredient(Foods.almonds, 15),
        ]),
    ]

    static let lunches: [MealTemplate] = [
        MealTemplate(slot: .lunch, title: "Poulet, riz basmati et brocoli", ingredients: [
            Ingredient(Foods.chicken, 140), Ingredient(Foods.rice, 180), Ingredient(Foods.broccoli, 150), Ingredient(Foods.oliveOil, 10),
        ]),
        MealTemplate(slot: .lunch, title: "Salade de lentilles, feta et tomates", ingredients: [
            Ingredient(Foods.lentils, 200), Ingredient(Foods.feta, 40), Ingredient(Foods.tomato, 150), Ingredient(Foods.eggs, 55), Ingredient(Foods.oliveOil, 10),
        ]),
        MealTemplate(slot: .lunch, title: "Bœuf haché, pâtes complètes et courgettes", ingredients: [
            Ingredient(Foods.leanBeef, 130), Ingredient(Foods.pasta, 180), Ingredient(Foods.zucchini, 150), Ingredient(Foods.oliveOil, 5),
        ]),
    ]

    static let snacks: [MealTemplate] = [
        MealTemplate(slot: .snack, title: "Fromage blanc et pomme", ingredients: [
            Ingredient(Foods.cottageCheese, 150), Ingredient(Foods.apple, 150),
        ]),
        MealTemplate(slot: .snack, title: "Skyr et amandes", ingredients: [
            Ingredient(Foods.skyr, 150), Ingredient(Foods.almonds, 15),
        ]),
    ]

    static let dinners: [MealTemplate] = [
        MealTemplate(slot: .dinner, title: "Saumon, patate douce et haricots verts", ingredients: [
            Ingredient(Foods.salmon, 130), Ingredient(Foods.sweetPotato, 200), Ingredient(Foods.greenBeans, 150),
        ]),
        MealTemplate(slot: .dinner, title: "Tofu sauté, quinoa et légumes", ingredients: [
            Ingredient(Foods.tofu, 150), Ingredient(Foods.quinoa, 150), Ingredient(Foods.broccoli, 100), Ingredient(Foods.zucchini, 100), Ingredient(Foods.oliveOil, 10),
        ]),
        MealTemplate(slot: .dinner, title: "Thon, pois chiches et crudités", ingredients: [
            Ingredient(Foods.tuna, 120), Ingredient(Foods.chickpeas, 150), Ingredient(Foods.tomato, 150), Ingredient(Foods.oliveOil, 10),
        ]),
    ]
}
