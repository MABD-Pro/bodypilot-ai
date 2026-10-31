import BodyPilotCore
import Foundation
import Testing
@testable import Nutrition

private let planner = MealPlanner(calculator: EnergyCalculator(calendar: utc))
private let today = day(2026, 10, 31)

private func daysAgo(_ count: Int) -> Date {
    utc.date(byAdding: .day, value: -count, to: today)!
}

private func meal(_ text: String) -> DescribedMeal {
    MealTextParser.parse(text).meal
}

// MARK: - Aliments écartés

@Test func avoidedFoodsNeverAppearInPlannedMeals() {
    var profile = makeProfile()
    profile.avoidedFoods = [.fish, .dairy, .meat, .eggs, .nuts]
    let targets = planner.targets(for: profile, currentWeightKg: 90, on: today)
    let avoidedNames = Set(Foods.all.filter { $0.aversion != nil }.map(\.name))
    for offset in 0..<6 {
        let date = utc.date(byAdding: .day, value: offset, to: today)!
        let plan = planner.mealPlan(for: targets, profile: profile, on: date, constraints: MealConstraints())
        #expect(plan.meals.count == MealSlot.allCases.count)
        for meal in plan.meals {
            #expect(meal.items.allSatisfy { !avoidedNames.contains($0.name) }, "\(meal.title) : \(meal.items.map(\.name))")
        }
        #expect(abs(plan.totals.kcal - targets.macros.kcal) / targets.macros.kcal < 0.12)
    }
}

@Test func fittingTemplatesArePreferredOverSubstitutes() {
    let template = planner.template(for: .dinner, day: 0, lowAppetite: false, avoiding: [.fish])
    #expect(template.title == "Tofu sauté, quinoa et légumes")
}

@Test func substitutedTemplateIsRetitledAfterItsFoods() {
    let template = MealTemplates.snacks[0].avoiding([.dairy])
    #expect(template.ingredients.map(\.food.name) == ["Yaourt au soja nature", "Pomme"])
    #expect(template.title == "Yaourt au soja nature et pomme")
}

@Test func substitutesSharingAFoodAreMerged() {
    // Lentilles, feta, tomates, œuf : feta et œuf deviennent du tofu, une seule fois.
    let template = MealTemplates.lunches[1].avoiding([.dairy, .eggs])
    #expect(template.ingredients.filter { $0.food.name == Foods.tofu.name }.count == 1)
    #expect(template.ingredients.first { $0.food.name == Foods.tofu.name }?.grams == 95)
}

@Test func noAversionKeepsTheUsualRotation() {
    let targets = planner.targets(for: makeProfile(), currentWeightKg: 90, on: today)
    var empty = makeProfile()
    empty.avoidedFoods = []
    let plain = planner.mealPlan(for: targets, profile: makeProfile(), on: today, constraints: MealConstraints())
    let withEmpty = planner.mealPlan(for: targets, profile: empty, on: today, constraints: MealConstraints())
    #expect(plain == withEmpty)
}

// MARK: - Repas habituels

@Test func mealEatenThreeDaysBecomesTheHabit() {
    let breakfast = meal("trois tranches de pain complet, trois œufs et un café")
    let history: [(day: Date, meals: [MealSlot: DescribedMeal])] = [
        (daysAgo(1), [.breakfast: breakfast]),
        (daysAgo(3), [.breakfast: breakfast, .lunch: meal("150 g de poulet et du riz")]),
        (daysAgo(8), [.breakfast: breakfast]),
        (daysAgo(9), [.lunch: meal("150 g de poulet et du riz")]),
    ]
    let habits = HabitMeals.usual(history: history, today: today, calendar: utc)
    #expect(habits[.breakfast] == breakfast)
    // Deux fois seulement : pas encore une habitude.
    #expect(habits[.lunch] == nil)
}

@Test func habitIgnoresTodayAndOldMeals() {
    let breakfast = meal("trois tranches de pain complet, trois œufs et un café")
    let history: [(day: Date, meals: [MealSlot: DescribedMeal])] = [
        (today, [.breakfast: breakfast]),
        (daysAgo(2), [.breakfast: breakfast]),
        (daysAgo(29), [.breakfast: breakfast]),
        (daysAgo(40), [.breakfast: breakfast]),
    ]
    #expect(HabitMeals.usual(history: history, today: today, calendar: utc).isEmpty)
}

@Test func sameFoodsInOtherQuantitiesCountAsTheSameHabit() {
    let history: [(day: Date, meals: [MealSlot: DescribedMeal])] = [
        (daysAgo(1), [.breakfast: meal("deux œufs et deux tranches de pain complet")]),
        (daysAgo(2), [.breakfast: meal("trois œufs et du pain complet")]),
        (daysAgo(4), [.breakfast: meal("pain complet et 2 œufs")]),
    ]
    let habit = HabitMeals.usual(history: history, today: today, calendar: utc)[.breakfast]
    // La dernière façon de le décrire.
    #expect(habit?.text == "deux œufs et deux tranches de pain complet")
}

@Test func habitReplacesTheTemplateWithPortionsForTheDay() throws {
    let targets = planner.targets(for: makeProfile(), currentWeightKg: 90, on: today)
    let breakfast = meal("trois tranches de pain complet, trois œufs et un café")
    let plan = planner.mealPlan(for: targets, profile: makeProfile(), on: today, constraints: MealConstraints(habits: [.breakfast: breakfast]))
    let planned = try #require(plan.meals.first { $0.slot == .breakfast })
    #expect(planned.isHabit)
    #expect(planned.title == breakfast.title)
    #expect(planned.items.map(\.name) == breakfast.foods.map(\.name))
    #expect(planned.items.contains { $0.quantityLabel.hasSuffix("œufs") })
    #expect(abs(plan.totals.kcal - targets.macros.kcal) / targets.macros.kcal < 0.1)
}

@Test func habitFarFromTheMealSizeKeepsTheTemplate() throws {
    let targets = planner.targets(for: makeProfile(), currentWeightKg: 90, on: today)
    let plan = planner.mealPlan(for: targets, profile: makeProfile(), on: today, constraints: MealConstraints(habits: [.breakfast: meal("un café")]))
    let planned = try #require(plan.meals.first { $0.slot == .breakfast })
    #expect(!planned.isHabit)
}

@Test func describedMealWinsOverTheHabit() throws {
    let targets = planner.targets(for: makeProfile(), currentWeightKg: 90, on: today)
    let eaten = meal("un croissant et un café")
    let plan = planner.mealPlan(
        for: targets, profile: makeProfile(), on: today,
        constraints: MealConstraints(described: [.breakfast: eaten], habits: [.breakfast: meal("trois tranches de pain complet, trois œufs et un café")])
    )
    let planned = try #require(plan.meals.first { $0.slot == .breakfast })
    #expect(planned.described == eaten)
    #expect(!planned.isHabit)
}

// MARK: - Portions habituelles

@Test func usualPortionIsTheMedianOfConfirmedOnes() {
    let pasta = { (grams: Double) in DescribedFood(name: "Pâtes", grams: grams, quantityLabel: "\(Int(grams)) g", macros: Macros(kcal: grams * 1.3, proteinG: grams * 0.05, carbsG: grams * 0.27, fatG: 0)) }
    let guessed = DescribedFood(name: "Pâtes", grams: 999, quantityLabel: "1 assiette", macros: .zero, needsPortion: true)
    let history: [(day: Date, meals: [MealSlot: DescribedMeal])] = [
        (daysAgo(1), [.lunch: DescribedMeal(text: "", foods: [pasta(250)])]),
        (daysAgo(5), [.dinner: DescribedMeal(text: "", foods: [pasta(180), guessed])]),
        (daysAgo(9), [.lunch: DescribedMeal(text: "", foods: [pasta(220)])]),
        (daysAgo(70), [.lunch: DescribedMeal(text: "", foods: [pasta(500)])]),
    ]
    let usual = UsualPortions.learn(history: history, today: today, calendar: utc)
    #expect(usual["Pâtes"]?.grams == 220)
}

@Test func foodSeenOnceTeachesNothing() {
    let history: [(day: Date, meals: [MealSlot: DescribedMeal])] = [(daysAgo(1), [.lunch: meal("200 g de riz")])]
    #expect(UsualPortions.learn(history: history, today: today, calendar: utc).isEmpty)
}

@Test func unquantifiedFoodTakesTheUsualPortion() throws {
    let parse = MealTextParser.parse("du riz et 150 g de poulet")
    let rice = try #require(parse.foods.first { $0.needsPortion })
    let usualRice = DescribedFood(name: rice.name, grams: rice.grams * 1.5, quantityLabel: "Grande portion", macros: rice.macros.scaled(by: 1.5))
    let applied = UsualPortions.apply([rice.name: usualRice], to: parse)
    let updated = try #require(applied.foods.first { $0.name == rice.name })
    #expect(!updated.needsPortion)
    #expect(abs(updated.grams - usualRice.grams) < 0.01)
    #expect(abs(updated.macros.kcal - usualRice.macros.kcal) < 0.01)
    #expect(updated.quantityLabel.hasPrefix("Ta portion habituelle"))
    // Le poulet avait sa quantité : il ne bouge pas.
    #expect(applied.foods.first { $0.name != rice.name } == parse.foods.first { $0.name != rice.name })
}
