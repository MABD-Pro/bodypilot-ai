import BodyPilotCore
import Foundation
import Testing
@testable import Nutrition

@Test func lighterSwapPicksTheBiggestSaving() throws {
    let meal = MealTextParser.parse("un burger, des frites et un coca").meal
    let suggestions = MealImprover.suggestions(for: meal, slot: .lunch)
    let lighter = try #require(suggestions.first { $0.goal == .lighter })
    #expect(lighter.title == "Pommes de terre au lieu de frites")
    #expect(lighter.meal.macros.kcal < meal.macros.kcal - 300)
    #expect(lighter.meal.foods.count == meal.foods.count)
    // Le burger apporte déjà assez de protéines.
    #expect(!suggestions.contains { $0.goal == .moreProtein })
}

@Test func lowProteinMealGetsChickenAtLunchAndSkyrAtBreakfast() throws {
    let pasta = MealTextParser.parse("des pâtes").meal
    let lunch = try #require(MealImprover.suggestions(for: pasta, slot: .lunch).first { $0.goal == .moreProtein })
    #expect(lunch.title == "Ajoute 100 g de poulet")
    #expect(lunch.meal.macros.proteinG >= pasta.macros.proteinG + 30)

    let breakfast = MealTextParser.parse("un croissant et un jus d'orange").meal
    let suggestions = MealImprover.suggestions(for: breakfast, slot: .breakfast)
    #expect(suggestions.map(\.title) == ["Pain complet au lieu de croissant", "Ajoute un skyr"])
}

@Test func balancedMealHasNoSuggestion() {
    let meal = MealTextParser.parse("150 g de poulet, du riz et des haricots verts").meal
    #expect(MealImprover.suggestions(for: meal, slot: .dinner).isEmpty)
}

@Test func recentMealsPutTheSameSlotFirstWithoutDuplicates() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    let today = calendar.date(from: DateComponents(year: 2026, month: 10, day: 28))!
    func day(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: -offset, to: today)! }
    let pasta = MealTextParser.parse("des pâtes").meal
    let salad = MealTextParser.parse("une salade composée").meal
    let porridge = MealTextParser.parse("un porridge").meal
    let history: [(day: Date, meals: [MealSlot: DescribedMeal])] = [
        (today, [.lunch: salad]),
        (day(1), [.lunch: pasta, .breakfast: porridge]),
        (day(3), [.lunch: pasta, .dinner: salad]),
        (day(9), [.lunch: MealTextParser.parse("une pizza").meal]),
    ]
    let recent = RecentMeals.list(for: .lunch, history: history, today: today, calendar: calendar)
    #expect(recent.map(\.meal.title) == [pasta.title, porridge.title, salad.title])
    #expect(recent.first?.day == day(1))
}

@Test func fattyBreadPlateGetsTwoLighterSwaps() {
    let meal = MealTextParser.parse("pain fromage beurre huile d'olive dattes et les olives").meal
    #expect(Set(meal.foods.map(\.name)).isSuperset(of: ["Pain", "Fromage", "Beurre", "Huile d'olive", "Dattes", "Olives"]))
    let lighter = MealImprover.suggestions(for: meal, slot: .lunch).filter { $0.goal == .lighter }
    #expect(lighter.map(\.title) == ["Beurre ou huile, pas les deux", "Moitié moins de fromage"])
    #expect(lighter.first?.meal.foods.contains { $0.name == "Beurre" } == false)
}

@Test func cheeseIsNotTheMainProteinOfALunch() throws {
    // « date » au singulier, tel que dicté, est bien lu comme des dattes.
    let meal = MealTextParser.parse("pain fromage beurre huile d'olive date et les olives").meal
    #expect(meal.foods.contains { $0.name == "Dattes" })
    let protein = try #require(MealImprover.suggestions(for: meal, slot: .lunch).first { $0.goal == .moreProtein })
    #expect(protein.title == "Ajoute 100 g de poulet")
}

@Test func alternativesStayInTheFamilyLightestFirst() {
    let cheese = MealTextParser.parse("du fromage").meal.foods[0]
    let alternatives = MealImprover.alternatives(for: cheese)
    #expect(alternatives.first?.name == "Fromage blanc 0 %")
    #expect(!alternatives.contains { $0.name == "Fromage" })
    #expect(alternatives.allSatisfy { ["Fromage blanc 0 %", "Skyr nature", "Yaourt grec 0 %", "Yaourt"].contains($0.name) })
    #expect(alternatives.map(\.macros.kcal) == alternatives.map(\.macros.kcal).sorted())

    let halfRice = DescribedFood(name: "Riz", grams: 100, quantityLabel: "½ assiette", macros: Macros(kcal: 130, proteinG: 2.7, carbsG: 28, fatG: 0.3))
    let quinoa = MealImprover.alternatives(for: halfRice).first { $0.name == "Quinoa cuit" }
    #expect(quinoa?.grams == 75)
}
