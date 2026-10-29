import BodyPilotCore
import Foundation

/// Rayon du magasin, dans l'ordre d'un parcours habituel.
public enum GroceryAisle: String, CaseIterable, Sendable, Codable {
    case produce
    case meatAndFish
    case dairy
    case bakery
    case pantry

    public var title: String {
        switch self {
        case .produce: "Fruits et légumes"
        case .meatAndFish: "Viandes et poissons"
        case .dairy: "Frais et œufs"
        case .bakery: "Boulangerie"
        case .pantry: "Épicerie"
        }
    }
}

/// Un article à acheter : la somme de ce que les repas de la période en utilisent, en quantité d'achat
/// (cru, sec ou en boîte, arrondi à ce qui se trouve en magasin).
public struct GroceryItem: Sendable, Equatable, Identifiable {
    /// Nom de l'aliment, stable d'une génération à l'autre : il sert à retenir ce qui est coché.
    public var id: String { name }
    public var name: String
    public var aisle: GroceryAisle
    /// Quantité à acheter (« 1,2 kg », « 9 œufs », « 3 boîtes »).
    public var quantityLabel: String
    /// Précision sur la quantité (« pesé cru », « boîtes de 400 g »).
    public var detail: String?
    /// Nombre de repas de la période qui l'utilisent.
    public var mealCount: Int

    public init(name: String, aisle: GroceryAisle, quantityLabel: String, detail: String? = nil, mealCount: Int) {
        self.name = name
        self.aisle = aisle
        self.quantityLabel = quantityLabel
        self.detail = detail
        self.mealCount = mealCount
    }
}

public struct GroceryList: Sendable, Equatable {
    public var items: [GroceryItem]
    /// Repas comptés (hors restaurant).
    public var mealCount: Int

    public init(items: [GroceryItem], mealCount: Int) {
        self.items = items
        self.mealCount = mealCount
    }

    /// Les rayons non vides, dans l'ordre du parcours, articles par ordre alphabétique.
    public var sections: [GrocerySection] {
        GroceryAisle.allCases.compactMap { aisle in
            let items = items.filter { $0.aisle == aisle }
            return items.isEmpty ? nil : GrocerySection(aisle: aisle, items: items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending })
        }
    }
}

public struct GrocerySection: Sendable, Equatable, Identifiable {
    public var aisle: GroceryAisle
    public var items: [GroceryItem]
    public var id: GroceryAisle { aisle }
}

/// Comment s'achète un aliment du catalogue : rayon, passage du poids dans l'assiette au poids
/// acheté, et unité de vente.
struct GroceryProduct: Sendable {
    let aisle: GroceryAisle
    /// Poids acheté pour 1 g dans l'assiette : sec pour les féculents cuits (rapport des kcal
    /// cuit/cru, Ciqual), cru pour le poulet (environ 25 % de perte à la cuisson), épluchures.
    let purchaseFactor: Double
    /// Vendu à l'unité ou à la boîte plutôt qu'au poids.
    let unit: GroceryUnit?
    let detail: String?
    /// Densité pour compter en volume (huile) plutôt qu'en poids.
    let density: Double?

    init(_ aisle: GroceryAisle, factor: Double = 1, unit: GroceryUnit? = nil, detail: String? = nil, density: Double? = nil) {
        self.aisle = aisle
        self.purchaseFactor = factor
        self.unit = unit
        self.detail = detail
        self.density = density
    }
}

struct GroceryUnit: Sendable {
    let grams: Double
    let singular: String
    let plural: String
}

enum GroceryProducts {
    /// Par nom d'aliment du catalogue (`Foods`). Un aliment absent est rangé en épicerie, au poids.
    static let byName: [String: GroceryProduct] = [
        Foods.oats.name: GroceryProduct(.pantry),
        Foods.greekYogurt.name: GroceryProduct(.dairy),
        Foods.skyr.name: GroceryProduct(.dairy),
        Foods.cottageCheese.name: GroceryProduct(.dairy),
        Foods.banana.name: GroceryProduct(.produce, unit: GroceryUnit(grams: 120, singular: "banane", plural: "bananes")),
        Foods.berries.name: GroceryProduct(.produce, detail: "frais ou surgelés"),
        Foods.apple.name: GroceryProduct(.produce, unit: GroceryUnit(grams: 150, singular: "pomme", plural: "pommes")),
        Foods.almonds.name: GroceryProduct(.pantry),
        Foods.eggs.name: GroceryProduct(.dairy, unit: GroceryUnit(grams: 55, singular: "œuf", plural: "œufs")),
        Foods.wholeBread.name: GroceryProduct(.bakery),
        // Environ 150 g de chair par avocat.
        Foods.avocado.name: GroceryProduct(.produce, unit: GroceryUnit(grams: 150, singular: "avocat", plural: "avocats")),
        Foods.chicken.name: GroceryProduct(.meatAndFish, factor: 1.33, detail: "pesé cru"),
        Foods.salmon.name: GroceryProduct(.meatAndFish),
        // Une boîte de 140 g donne environ 100 g de thon égoutté.
        Foods.tuna.name: GroceryProduct(.pantry, unit: GroceryUnit(grams: 100, singular: "boîte", plural: "boîtes"), detail: "boîtes de 140 g"),
        Foods.leanBeef.name: GroceryProduct(.meatAndFish),
        Foods.tofu.name: GroceryProduct(.dairy),
        Foods.rice.name: GroceryProduct(.pantry, factor: 0.37, detail: "pesé sec"),
        Foods.pasta.name: GroceryProduct(.pantry, factor: 0.35, detail: "pesées sèches"),
        Foods.quinoa.name: GroceryProduct(.pantry, factor: 0.33, detail: "pesé sec"),
        // Patate douce : environ 10 % de peau.
        Foods.sweetPotato.name: GroceryProduct(.produce, factor: 1.1),
        Foods.lentils.name: GroceryProduct(.pantry, factor: 0.33, detail: "pesées sèches"),
        // Une boîte de 400 g donne environ 240 g de pois chiches égouttés.
        Foods.chickpeas.name: GroceryProduct(.pantry, unit: GroceryUnit(grams: 240, singular: "boîte", plural: "boîtes"), detail: "boîtes de 400 g"),
        Foods.broccoli.name: GroceryProduct(.produce),
        Foods.greenBeans.name: GroceryProduct(.produce, detail: "frais ou surgelés"),
        Foods.zucchini.name: GroceryProduct(.produce),
        Foods.tomato.name: GroceryProduct(.produce),
        Foods.feta.name: GroceryProduct(.dairy),
        Foods.oliveOil.name: GroceryProduct(.pantry, detail: "souvent déjà au placard", density: 0.92),
    ]

    /// Noms d'achat : « Riz basmati » plutôt que « Riz basmati cuit ».
    static func purchaseName(_ name: String) -> String {
        for suffix in [" cuites", " cuits", " cuite", " cuit"] where name.hasSuffix(suffix) {
            return String(name.dropLast(suffix.count))
        }
        return name
    }
}

extension MealPlanner {
    /// Liste de courses des repas proposés sur ces jours, avec les objectifs donnés.
    ///
    /// Les jours sont planifiés sans contrainte (pas de restaurant ni de repas noté) : c'est ce que
    /// le coach proposera si rien ne change. Les repas au restaurant n'ont rien à acheter.
    public func groceries(for targets: NutritionTargets, profile: UserProfile, days: [Date], slots: Set<MealSlot> = Set(MealSlot.allCases)) -> GroceryList {
        let meals = days.flatMap { day in
            mealPlan(for: targets, profile: profile, on: day, constraints: MealConstraints()).meals
                .filter { slots.contains($0.slot) && !$0.isEatingOut && !$0.isEaten }
        }
        var grams: [String: Double] = [:]
        var mealCounts: [String: Int] = [:]
        for meal in meals {
            for item in meal.items where item.grams > 0 {
                grams[item.name, default: 0] += item.grams
                mealCounts[item.name, default: 0] += 1
            }
        }
        let items = grams.map { name, plate in
            let product = GroceryProducts.byName[name] ?? GroceryProduct(.pantry)
            return GroceryItem(
                name: GroceryProducts.purchaseName(name),
                aisle: product.aisle,
                quantityLabel: Self.purchaseLabel(grams: plate * product.purchaseFactor, unit: product.unit, density: product.density),
                detail: product.detail,
                mealCount: mealCounts[name] ?? 0
            )
        }
        return GroceryList(items: items, mealCount: meals.count)
    }

    /// Quantité arrondie au-dessus, à ce qui s'achète : à l'unité, par 50 g, puis par 100 g au-delà d'un kilo.
    static func purchaseLabel(grams: Double, unit: GroceryUnit?, density: Double? = nil) -> String {
        if let density {
            let milliliters = grams / density
            return milliliters < 1000 ? "\(Int(max(50, (milliliters / 50).rounded(.up) * 50))) ml" : "\(((milliliters / 100).rounded(.up) / 10).frenchCompact) l"
        }
        if let unit {
            // Une marge de 10 % évite d'acheter une unité de plus pour quelques grammes.
            let count = max(1, Int((grams / unit.grams - 0.1).rounded(.up)))
            return "\(count) \(count > 1 ? unit.plural : unit.singular)"
        }
        if grams < 1000 {
            return "\(Int(max(50, (grams / 50).rounded(.up) * 50))) g"
        }
        return "\(((grams / 100).rounded(.up) / 10).frenchCompact) kg"
    }
}
