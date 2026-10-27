import AIRouter
import BodyPilotCore
import Testing
@testable import Nutrition

@Test func readsContainersSizesAndDrinks() throws {
    let parse = MealTextParser.parse("Une grande assiette de pâtes carbo et un coca")
    #expect(parse.foods.map(\.name) == ["Pâtes carbonara", "Soda"])
    #expect(parse.unrecognized.isEmpty)
    let pasta = try #require(parse.foods.first)
    #expect(pasta.grams == 420)
    #expect(pasta.quantityLabel == "1 grande assiette")
    #expect(!pasta.needsPortion)
    #expect(parse.foods[1].quantityLabel == "1 canette")
    #expect(!parse.needsClarification)
}

@Test func readsCountsAndSlices() {
    let parse = MealTextParser.parse("2 œufs, 2 tranches de pain complet")
    #expect(parse.foods.map(\.name) == ["Œufs", "Pain complet"])
    #expect(parse.foods.map(\.grams) == [110, 70])
    #expect(parse.foods.map(\.quantityLabel) == ["2 œufs", "2 tranches"])
}

@Test func readsGramsAfterTheFood() throws {
    let rice = try #require(MealTextParser.parse("riz 200 g").foods.first)
    #expect(rice.grams == 200)
    #expect(rice.quantityLabel == "200 g")
    #expect(abs(rice.macros.kcal - 260) < 1)
}

@Test func guessedPortionAsksForConfirmation() throws {
    let parse = MealTextParser.parse("poulet avec du riz")
    #expect(parse.foods.count == 2)
    #expect(parse.foods.allSatisfy { $0.needsPortion })
    #expect(parse.needsClarification)
    let chicken = try #require(parse.foods.first)
    let bigger = chicken.resized(by: 1.4, label: "Grande portion")
    #expect(!bigger.needsPortion)
    #expect(abs(bigger.macros.kcal - chicken.macros.kcal * 1.4) < 0.01)
}

@Test func unknownFoodIsReportedNotInvented() {
    let parse = MealTextParser.parse("un tajine d'agneau et un yaourt")
    #expect(parse.foods.map(\.name) == ["Yaourt"])
    #expect(parse.unrecognized == ["un tajine d'agneau"])
}

@Test func longestNameWins() {
    #expect(MealTextParser.parse("un pain au chocolat").foods.map(\.name) == ["Pain au chocolat"])
    #expect(MealTextParser.parse("des pommes de terre").foods.map(\.name) == ["Pommes de terre"])
    #expect(MealTextParser.parse("un coca zéro").foods.map(\.name) == ["Soda zéro"])
}

private struct FakeMealModel: MealLanguageModel {
    let drafts: [FoodEstimateDraft]
    func estimate(_ text: String) async throws -> [FoodEstimateDraft] { drafts }
}

@Test func modelEstimatesOnlyUnknownFoodsWithinBounds() async {
    let describer = MealDescriber(
        router: AIRouter(availableTiers: [.deterministic, .onDevice]),
        model: FakeMealModel(drafts: [
            FoodEstimateDraft(name: "tajine d'agneau", grams: 350, kcal: 520, proteinG: 35, carbsG: 30, fatG: 28),
            FoodEstimateDraft(name: "absurde", grams: 5000, kcal: 9000, proteinG: 0, carbsG: 0, fatG: 0),
        ])
    )
    let parse = await describer.describe("un tajine d'agneau et un yaourt")
    #expect(parse.foods.map(\.name) == ["Yaourt", "Tajine d'agneau"])
    #expect(parse.unrecognized.isEmpty)
    #expect(parse.foods.last?.isEstimate == true)
}

@Test func withoutModelUnknownFoodsStayToClarify() async {
    let parse = await MealDescriber().describe("un tajine d'agneau")
    #expect(parse.foods.isEmpty)
    #expect(parse.unrecognized == ["un tajine d'agneau"])
}

@Test func describedMealReplacesThePlanAndAdjustsTheRest() throws {
    let planner = MealPlanner(calculator: EnergyCalculator(calendar: utc))
    let targets = NutritionTargets(macros: Macros(kcal: 2200, proteinG: 160, carbsG: 220, fatG: 70), maintenanceKcal: 2600, rationale: "")
    let date = day(2026, 10, 27)
    let lunch = MealTextParser.parse("une grande assiette de pâtes carbo et un coca").meal
    let normal = planner.mealPlan(for: targets, profile: makeProfile(), on: date, constraints: MealConstraints())
    let after = planner.mealPlan(for: targets, profile: makeProfile(), on: date, constraints: MealConstraints(described: [.lunch: lunch]))

    let lunchMeal = try #require(after.meals.first { $0.slot == .lunch })
    #expect(lunchMeal.described == lunch)
    #expect(lunchMeal.title == "Pâtes carbonara et soda")
    #expect(abs(lunchMeal.macros.kcal - lunch.macros.kcal) < 0.01)
    #expect(after.eatenTotals == lunch.macros)
    // 420 g de carbonara et un soda (~895 kcal) contre ~770 prévues : la suite s'allège.
    let dinnerBefore = try #require(normal.meals.first { $0.slot == .dinner }).macros.kcal
    let dinnerAfter = try #require(after.meals.first { $0.slot == .dinner }).macros.kcal
    #expect(dinnerAfter < dinnerBefore)
}
