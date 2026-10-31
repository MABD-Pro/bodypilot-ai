import BodyPilotCore
import Foundation
import Testing
@testable import Nutrition

private func json(_ text: String) -> Data { Data(text.utf8) }

@Test func openFoodFactsProductIsRead() throws {
    let data = json("""
    {"status":1,"product":{"product_name_fr":"Skyr nature","product_name":"Skyr","brands":"Siggi's, Arla","serving_quantity":"150","nutriscore_grade":"A",
    "nutriments":{"energy-kcal_100g":63,"proteins_100g":"11","carbohydrates_100g":4,"fat_100g":0.2,"fiber_100g":0}}}
    """)
    let food = try #require(PackagedFood.fromOpenFoodFacts(data, barcode: "123"))
    #expect(food.name == "Skyr nature")
    #expect(food.brand == "Siggi's")
    #expect(food.per100g.proteinG == 11)
    #expect(food.servingGrams == 150)
    #expect(food.nutriScore == "a")
    #expect(ProductVerdict.of(food).rating == .great)
}

@Test func energyInKilojoulesIsConverted() throws {
    let data = json(#"{"status":1,"product":{"product_name":"Biscuit","nutriments":{"energy_100g":2092,"proteins_100g":6}}}"#)
    let food = try #require(PackagedFood.fromOpenFoodFacts(data, barcode: "9"))
    #expect(abs(food.per100g.kcal - 500) < 0.5)
    #expect(ProductVerdict.of(food).rating == .occasional)
}

@Test func unknownProductGivesNil() {
    #expect(PackagedFood.fromOpenFoodFacts(json(#"{"status":0,"status_verbose":"product not found"}"#), barcode: "0") == nil)
    #expect(PackagedFood.fromOpenFoodFacts(json(#"{"status":1,"product":{"product_name":"Eau","nutriments":{"energy-kcal_100g":0}}}"#), barcode: "1") == nil)
    #expect(PackagedFood.fromOpenFoodFacts(json("pas du json"), barcode: "2") == nil)
}

@Test func moderateProductIsFine() {
    let bread = PackagedFood(barcode: "3", name: "Pain complet", per100g: Macros(kcal: 250, proteinG: 9, carbsG: 45, fatG: 3))
    let verdict = ProductVerdict.of(bread)
    #expect(verdict.rating == .fine)
    #expect(verdict.headline == "Peu de protéines")
}
