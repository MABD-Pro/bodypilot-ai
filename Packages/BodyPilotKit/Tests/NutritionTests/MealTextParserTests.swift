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
    let parse = MealTextParser.parse("un mafé et un yaourt")
    #expect(parse.foods.map(\.name) == ["Yaourt"])
    #expect(parse.unrecognized == ["un mafé"])
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
            FoodEstimateDraft(name: "mafé", grams: 350, kcal: 520, proteinG: 35, carbsG: 30, fatG: 28),
            FoodEstimateDraft(name: "absurde", grams: 5000, kcal: 9000, proteinG: 0, carbsG: 0, fatG: 0),
        ])
    )
    let parse = await describer.describe("un mafé et un yaourt")
    #expect(parse.foods.map(\.name) == ["Yaourt", "Mafé"])
    #expect(parse.unrecognized.isEmpty)
    #expect(parse.foods.last?.isEstimate == true)
}

@Test func partialEstimateKeepsUnknownFoodsToClarify() async {
    let text = "un mafé et un zaalouk"
    #expect(MealTextParser.parse(text).unrecognized.count == 2)
    let describer = MealDescriber(
        router: AIRouter(availableTiers: [.deterministic, .onDevice]),
        model: FakeMealModel(drafts: [
            FoodEstimateDraft(name: "mafé", grams: 350, kcal: 520, proteinG: 35, carbsG: 30, fatG: 28),
        ])
    )
    let parse = await describer.describe(text)
    #expect(parse.foods.map(\.name) == ["Mafé"])
    #expect(parse.unrecognized.count == 2)
}

@Test func withoutModelUnknownFoodsStayToClarify() async {
    let parse = await MealDescriber().describe("un mafé")
    #expect(parse.foods.isEmpty)
    #expect(parse.unrecognized == ["un mafé"])
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
    let demi = try #require(MealTextParser.parse("une demi baguette").foods.first)
    #expect(demi.grams == 125 && demi.quantityLabel == "½ baguette")
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
    #expect(MealTextParser.parse("une salade de fruits").foods.map(\.name) == ["Salade de fruits"])
}

@Test func baguetteIsAWholeBaguette() throws {
    #expect(try #require(MealTextParser.parse("une baguette").foods.first).grams == 250)
    #expect(try #require(MealTextParser.parse("2 baguettes").foods.first).grams == 500)
    #expect(try #require(MealTextParser.parse("2 tranches de pain").foods.first).grams == 70)
}

@Test func puisAndPlusSeparateFoods() {
    #expect(MealTextParser.parse("un mafé puis un yaourt").unrecognized == ["un mafé"])
    #expect(MealTextParser.parse("un mafé plus un yaourt").unrecognized == ["un mafé"])
}

@Test func petitsSuissesAreKnown() throws {
    let weighed = try #require(MealTextParser.parse("120 g de petits suisses").foods.first)
    #expect(weighed.name == "Petit-suisse")
    #expect(weighed.grams == 120)
    #expect(abs(weighed.macros.kcal - 160.8) < 1)
    let counted = try #require(MealTextParser.parse("2 petits-suisses").foods.first)
    #expect(counted.grams == 120)
    #expect(MealTextParser.parse("2 petits-suisses").unrecognized.isEmpty)
}

@Test func writtenGramsOverrideTheModelPortion() async throws {
    let describer = MealDescriber(
        router: AIRouter(availableTiers: [.deterministic, .onDevice]),
        model: FakeMealModel(drafts: [
            FoodEstimateDraft(name: "tajine", grams: 300, kcal: 900, proteinG: 60, carbsG: 30, fatG: 60),
        ])
    )
    let tajine = try #require(await describer.describe("120 g de mafé").foods.first)
    #expect(tajine.grams == 120)
    #expect(tajine.quantityLabel == "120 g")
    #expect(abs(tajine.macros.kcal - 360) < 1)
}

@Test func ciqualCoversGenericFoods() throws {
    let faisselle = try #require(MealTextParser.parse("120 g de faisselle").foods.first)
    #expect(faisselle.name == "Faisselle")
    #expect(faisselle.grams == 120)
    #expect(abs(faisselle.macros.kcal - 100.3) < 1)
    #expect(MealTextParser.parse("une mangue").foods.first?.name == "Mangue")
    let soup = try #require(MealTextParser.parse("un bol de chorba").foods.first)
    #expect(soup.name == "Soupe chorba frik")
    #expect(soup.grams == 300)
    #expect(!soup.needsPortion)
    let mango = try #require(MealTextParser.parse("une mangue").foods.first)
    #expect(mango.grams == 220)
    #expect(!mango.needsPortion)
    let semolina = try #require(MealTextParser.parse("de la semoule").foods.first)
    #expect(semolina.grams == 100)
    #expect(semolina.needsPortion)
}

@Test func ciqualLeavesUnknownDishesToTheModel() {
    #expect(MealTextParser.parse("un mafé").unrecognized == ["un mafé"])
    #expect(CiqualMatcher.foods.count > 3000)
}

@Test func preciseNamesGetCiqualValues() throws {
    let comte = try #require(MealTextParser.parse("2 tranches de comté").foods.first)
    #expect(comte.name == "Comté")
    #expect(comte.grams == 70)
    let kiwi = try #require(MealTextParser.parse("un kiwi").foods.first)
    #expect(kiwi.name == "Kiwi")
    #expect(kiwi.grams == 75)
    #expect(MealTextParser.parse("des épinards").foods.first?.name == "Épinard")
    #expect(MealTextParser.parse("un tajine d'agneau").foods.first?.name == "Tajine")
    #expect(MealTextParser.parse("un yaourt grec").foods.first?.name == "Yaourt à la grecque")
    #expect(MealTextParser.parse("un yaourt grec 0%").foods.first?.name == "Yaourt grec 0 %")
}

@Test func modelDensityIsCappedByPortion() {
    let soup = MealDescriber.draft(name: "harira", portion: "bol", kcalPer100g: 400, proteinPer100g: 8, carbsPer100g: 40, fatPer100g: 20)
    #expect(soup.grams == 300)
    #expect(abs(soup.kcal - 450) < 0.1)
    #expect(abs(soup.fatG - 22.5) < 0.1)
    let plate = MealDescriber.draft(name: "mafé", portion: "assiette", kcalPer100g: 160, proteinPer100g: 9, carbsPer100g: 12, fatPer100g: 8)
    #expect(abs(plate.kcal - 480) < 0.1)
}
