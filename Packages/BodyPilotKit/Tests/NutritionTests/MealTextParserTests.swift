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

@Test func earlierUnloggedMealsAreNotInflated() throws {
    let planner = MealPlanner(calculator: EnergyCalculator(calendar: utc))
    let targets = NutritionTargets(macros: Macros(kcal: 2200, proteinG: 160, carbsG: 220, fatG: 70), maintenanceKcal: 2600, rationale: "")
    let date = day(2026, 10, 27)
    let dinner = MealTextParser.parse("une soupe").meal
    let normal = planner.mealPlan(for: targets, profile: makeProfile(), on: date, constraints: MealConstraints())
    let after = planner.mealPlan(for: targets, profile: makeProfile(), on: date, constraints: MealConstraints(described: [.dinner: dinner]))

    // Dîner léger noté : le petit-déjeuner et le déjeuner, non notés, restent tels que prévus.
    for slot in [MealSlot.breakfast, .lunch, .snack] {
        let before = try #require(normal.meals.first { $0.slot == slot }).macros
        let now = try #require(after.meals.first { $0.slot == slot }).macros
        #expect(before == now)
    }
    #expect(after.notes.isEmpty)
}

@Test func photoLabelsBecomeASentenceTheParserReads() throws {
    let sentence = try #require(PhotoLabelReader.sentence(from: [
        (identifier: "food", confidence: 0.95),
        (identifier: "spaghetti", confidence: 0.8),
        (identifier: "pasta", confidence: 0.7),
        (identifier: "salad", confidence: 0.5),
        (identifier: "wine", confidence: 0.1),
    ]))
    #expect(sentence == "pâtes, salade composée")
    #expect(MealTextParser.parse(sentence).foods.map(\.name) == ["Pâtes", "Salade composée"])
    #expect(PhotoLabelReader.sentence(from: [(identifier: "plate", confidence: 0.9)]) == nil)
}

@Test func everyPhotoLabelIsKnownToTheParser() {
    for name in Set(PhotoLabelReader.names.values) {
        #expect(!MealTextParser.parse(name).foods.isEmpty, "\(name)")
    }
}

@Test func decimalCommaAndFractionsAreQuantities() throws {
    let coke = try #require(MealTextParser.parse("1,5 l de coca").foods.first)
    #expect(MealTextParser.parse("1,5 l de coca").foods.count == 1)
    #expect(coke.grams == 1500)
    #expect(coke.quantityLabel == "1,5 l")
    #expect(try #require(MealTextParser.parse("0,5 kg de pâtes").foods.first).grams == 500)
    let half = try #require(MealTextParser.parse("1/2 baguette").foods.first)
    #expect(half.name == "Baguette" && half.grams == 125)
    #expect(half.quantityLabel == "½ baguette")
    let pizza = try #require(MealTextParser.parse("trois quarts de pizza").foods.first)
    #expect(abs(pizza.grams - 262.5) < 0.1)
    #expect(pizza.quantityLabel == "¾ pizza")
    #expect(try #require(MealTextParser.parse("un tiers de pizza").foods.first).grams < 120)
    #expect(try #require(MealTextParser.parse("douze sushis").foods.first).grams == 360)
    let halfLitre = try #require(MealTextParser.parse("un demi-litre de coca").foods.first)
    #expect(halfLitre.grams == 500 && halfLitre.quantityLabel == "½ l")
    #expect(try #require(MealTextParser.parse("un demi litre de coca").foods.first).grams == 500)
}

@Test func neighbouringFoodsAreAllKept() {
    #expect(MealTextParser.parse("steak frites").foods.map(\.name) == ["Steak", "Frites"])
    #expect(MealTextParser.parse("poulet riz brocoli").foods.map(\.name) == ["Blanc de poulet", "Riz", "Brocoli"])
    #expect(MealTextParser.parse("un thé glacé").foods.map(\.name) == ["Soda"])
}

@Test func compoundNamesAddNoGhostFood() {
    #expect(MealTextParser.parse("une pizza 4 fromages").foods.map(\.name) == ["Pizza"])
    #expect(MealTextParser.parse("une salade de fruits").foods.map(\.name) == ["Fruit"])
}

@Test func baguetteIsAWholeBaguette() throws {
    #expect(try #require(MealTextParser.parse("une baguette").foods.first).grams == 250)
    #expect(try #require(MealTextParser.parse("2 baguettes").foods.first).grams == 500)
    #expect(try #require(MealTextParser.parse("2 tranches de pain").foods.first).grams == 70)
}

@Test func puisAndPlusSeparateFoods() {
    #expect(MealTextParser.parse("un tajine puis un yaourt").unrecognized == ["un tajine"])
    #expect(MealTextParser.parse("un tajine plus un yaourt").unrecognized == ["un tajine"])
}
