import BodyPilotCore
import Foundation
import Testing
@testable import Nutrition

private let planner = MealPlanner(calculator: EnergyCalculator(calendar: utc))

private func week(from start: Date = day(2026, 10, 30)) -> [Date] {
    (0..<7).map { utc.date(byAdding: .day, value: $0, to: start)! }
}

private func targets() -> NutritionTargets {
    planner.targets(for: makeProfile(), currentWeightKg: 90, on: day(2026, 10, 29))
}

@Test func groceriesCoverEveryFoodOfTheWeek() {
    let list = planner.groceries(for: targets(), profile: makeProfile(), days: week())
    #expect(list.mealCount == 28)
    // Les trois déjeuners et les trois dîners tournent sur 7 jours : leurs sources de protéines y sont toutes.
    let names = Set(list.items.map(\.name))
    for name in ["Blanc de poulet", "Bœuf haché 5 %", "Saumon", "Tofu ferme", "Thon au naturel", "Œufs"] {
        #expect(names.contains(name), "\(name) manque")
    }
    // Un aliment n'apparaît qu'une fois, quel que soit le nombre de repas qui l'utilisent.
    #expect(names.count == list.items.count)
}

@Test func cookedStarchesAreBoughtDry() throws {
    let list = planner.groceries(for: targets(), profile: makeProfile(), days: week())
    let rice = try #require(list.items.first { $0.name == "Riz basmati" })
    #expect(rice.detail == "pesé sec")
    #expect(!list.items.contains { $0.name.hasSuffix(" cuit") || $0.name.hasSuffix(" cuits") })
}

@Test func onlyChosenMealsAreCounted() {
    let lunches = planner.groceries(for: targets(), profile: makeProfile(), days: week(), slots: [.lunch])
    #expect(lunches.mealCount == 7)
    #expect(!lunches.items.contains { $0.name == "Flocons d'avoine" })
    #expect(lunches.items.contains { $0.name == "Blanc de poulet" })
}

@Test func moreDaysNeverMeanLessFood() throws {
    let three = planner.groceries(for: targets(), profile: makeProfile(), days: Array(week().prefix(3)))
    let seven = planner.groceries(for: targets(), profile: makeProfile(), days: week())
    #expect(three.items.count <= seven.items.count)
    #expect(three.mealCount == 12)
}

@Test func sectionsFollowTheStoreAndAreSorted() {
    let list = planner.groceries(for: targets(), profile: makeProfile(), days: week())
    let aisles = list.sections.map(\.aisle)
    #expect(aisles == GroceryAisle.allCases.filter { aisles.contains($0) })
    for section in list.sections {
        #expect(section.items.allSatisfy { $0.aisle == section.aisle })
        #expect(!section.items.isEmpty)
    }
}

@Test func purchaseQuantitiesRoundUpToWhatStoresSell() {
    let eggs = GroceryUnit(grams: 55, singular: "œuf", plural: "œufs")
    #expect(MealPlanner.purchaseLabel(grams: 55, unit: eggs) == "1 œuf")
    // Quelques grammes de plus ne font pas acheter un œuf de plus.
    #expect(MealPlanner.purchaseLabel(grams: 113, unit: eggs) == "2 œufs")
    #expect(MealPlanner.purchaseLabel(grams: 130, unit: eggs) == "3 œufs")
    #expect(MealPlanner.purchaseLabel(grams: 12, unit: nil) == "50 g")
    #expect(MealPlanner.purchaseLabel(grams: 420, unit: nil) == "450 g")
    // Juste sous le kilo, arrondi au-dessus : on passe en kilos.
    #expect(MealPlanner.purchaseLabel(grams: 975, unit: nil) == "1 kg")
    #expect(MealPlanner.purchaseLabel(grams: 1_240, unit: nil) == "1,3 kg")
    #expect(MealPlanner.purchaseLabel(grams: 2_000, unit: nil) == "2 kg")
    #expect(MealPlanner.purchaseLabel(grams: 180, unit: nil, density: 0.92) == "200 ml")
}
