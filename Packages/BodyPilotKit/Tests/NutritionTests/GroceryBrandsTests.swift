import BodyPilotCore
import Foundation
import Testing
@testable import Nutrition

private let skyr = GroceryBrandQuery(terms: "skyr nature", must: ["skyr"], exclude: ["fraise", "vanille"], isProteinSource: true)

@Test func everyBrandedItemIsOnTheWeeklyList() {
    let planner = MealPlanner(calculator: EnergyCalculator(calendar: utc))
    let targets = planner.targets(for: makeProfile(), currentWeightKg: 90, on: day(2026, 10, 29))
    let days = (0..<7).map { utc.date(byAdding: .day, value: $0, to: day(2026, 10, 30))! }
    let names = Set(planner.groceries(for: targets, profile: makeProfile(), days: days).items.map(\.name))
    // Une clé qui ne correspond à aucun article ne s'afficherait jamais.
    for name in GroceryBrandTable.entries.keys {
        #expect(names.contains(name), "\(name) n'est pas un article de la liste")
    }
}

@Test func freshProduceHasNoBrand() {
    #expect(GroceryBrands.picks(for: "Brocoli").isEmpty)
    #expect(GroceryBrands.query(for: "Brocoli") == nil)
}

@Test func rankingPrefersNutriScoreThenProcessingThenProtein() {
    let products = [
        OpenFoodFactsProduct(code: "1", name: "Skyr nature", brands: "Marque B", nutriScore: "b", nova: 1, scans: 5_000, proteinPer100g: 10),
        OpenFoodFactsProduct(code: "2", name: "Skyr nature", brands: "Marque A", nutriScore: "a", nova: 1, scans: 10, proteinPer100g: 10),
        OpenFoodFactsProduct(code: "3", name: "Skyr à la fraise", brands: "Marque C", nutriScore: "a", nova: 1, scans: 9_000),
        OpenFoodFactsProduct(code: "4", name: "Skyr nature", brands: "Marque A", nutriScore: "a", nova: 1, scans: 20, proteinPer100g: 11),
        OpenFoodFactsProduct(code: "5", name: "Skyr nature", brands: nil, nutriScore: "a", nova: 1),
        OpenFoodFactsProduct(code: "6", name: "Yaourt nature", brands: "Marque D", nutriScore: "a", nova: 1),
    ]
    let picks = GroceryBrands.rank(products, for: skyr, count: 5)
    // La fraise est exclue, une marque ne compte qu'une fois, un produit sans marque ou sans skyr est écarté.
    #expect(picks.map(\.barcode) == ["4", "1"])
    #expect(picks.first?.nutriScore == "A")
}

@Test func zeroPercentItemsKeepOnlyLeanProducts() {
    let yogurt = GroceryBrandQuery(terms: "yaourt grec 0%", must: ["grec"], maxFat: 1)
    let products = [
        OpenFoodFactsProduct(code: "1", name: "Yaourt à la grecque", brands: "Gras", nutriScore: "c", nova: 1, fatPer100g: 9),
        OpenFoodFactsProduct(code: "2", name: "Yaourt grec 0 %", brands: "Maigre", nutriScore: "a", nova: 1, fatPer100g: 0.2),
        OpenFoodFactsProduct(code: "3", name: "Yaourt grec", brands: "Inconnu", nutriScore: "a", nova: 1),
    ]
    #expect(GroceryBrands.rank(products, for: yogurt, count: 5).map(\.brand) == ["Maigre"])
}

@Test func wordsMatchFromTheirStartWithoutAccents() {
    let words = GroceryBrands.normalize("Lentilles vertes du Puy, BIO").split(separator: " ").map(String.init)
    #expect(GroceryBrands.contains(words, "lentille"))
    #expect(GroceryBrands.contains(words, GroceryBrands.normalize("vertes du")))
    #expect(!GroceryBrands.contains(words, "ver du"))
    #expect(!GroceryBrands.contains(words, "entille"))
    #expect(GroceryBrands.normalize("Bœuf haché 5 %") == "bœuf hache 5")
}

@Test func searchResponsesAcceptNumbersWrittenAsText() throws {
    let json = Data(#"""
    {"products": [
      {"code": "3017620422003", "product_name_fr": "Skyr nature", "brands": "Siggi's, Arla", "nutriscore_grade": "a", "nova_group": "1", "unique_scans_n": 120, "nutriments": {"proteins_100g": "11"}},
      {"code": 42, "product_name": "Skyr", "brands": "Autre", "nutriscore_grade": "unknown"}
    ]}
    """#.utf8)
    let picks = try GroceryBrands.picks(fromSearchResponse: json, for: skyr)
    #expect(picks.map(\.brand) == ["Siggi's", "Autre"])
    #expect(picks[0].nova == 1)
    #expect(picks[1].nutriScore == nil)
    #expect(picks[1].barcode == "42")
}

@Test func searchURLTargetsFrenchProducts() throws {
    let url = try #require(GroceryBrands.searchURL(for: skyr))
    let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    #expect(items.contains(URLQueryItem(name: "search_terms", value: "skyr nature")))
    #expect(items.contains(URLQueryItem(name: "tag_0", value: "france")))
}

@Test func namesMustStartWithTheItemAndBeSoldInFrance() {
    let feta = GroceryBrandQuery(terms: "feta", must: ["feta"], lead: ["feta"])
    let products = [
        OpenFoodFactsProduct(code: "1", name: "Lentilles boulgour féta", brands: "Plat", nutriScore: "a", nova: 1),
        OpenFoodFactsProduct(code: "2", name: "Feta AOP", brands: "Allemande", nutriScore: "d", nova: 3, countries: ["en:germany"]),
        OpenFoodFactsProduct(code: "3", name: "Fêta AOP", brands: "Française", nutriScore: "d", nova: 3, countries: ["en:france", "en:belgium"]),
    ]
    #expect(GroceryBrands.rank(products, for: feta, count: 5).map(\.barcode) == ["3"])
}

@Test func brandVariantsCountOnce() {
    let pasta = GroceryBrandQuery(terms: "pâtes complètes", must: ["complet"])
    let products = [
        OpenFoodFactsProduct(code: "1", name: "Spaghetti complets", brands: "Barilla", nutriScore: "a", nova: 1),
        OpenFoodFactsProduct(code: "2", name: "Penne complètes", brands: "BARILLA NORGE AS", nutriScore: "a", nova: 1),
        OpenFoodFactsProduct(code: "3", name: "Fusilli complets", brands: "Panzani", nutriScore: "a", nova: 1),
    ]
    #expect(GroceryBrands.rank(products, for: pasta, count: 5).map(\.brand) == ["Barilla", "Panzani"])
}
