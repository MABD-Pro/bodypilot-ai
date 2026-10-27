import BodyPilotCore
import Testing
@testable import Nutrition

private let planner = MealPlanner(calculator: EnergyCalculator(calendar: utc))

@Test func planCoversEveryMealOfTheDay() {
    let targets = planner.targets(for: makeProfile(), currentWeightKg: 90, on: day(2026, 10, 27))
    let plan = planner.mealPlan(for: targets, profile: makeProfile(), on: day(2026, 10, 27), constraints: MealConstraints())
    #expect(plan.meals.map(\.slot) == MealSlot.allCases)
}

@Test func portionsLandCloseToTargetCalories() {
    for kcal in stride(from: 1600.0, through: 3000, by: 200) {
        let targets = NutritionTargets(macros: Macros(kcal: kcal, proteinG: 150, carbsG: 200, fatG: 60), maintenanceKcal: kcal, rationale: "")
        for offset in 0..<3 {
            let date = utc.date(byAdding: .day, value: offset, to: day(2026, 10, 27))!
            let total = planner.mealPlan(for: targets, profile: makeProfile(), on: date, constraints: MealConstraints()).totals.kcal
            #expect(abs(total - kcal) / kcal < 0.1, "\(kcal) kcal, jour \(offset) : \(total)")
        }
    }
}

@Test func mealsRotateFromOneDayToTheNext() {
    let targets = planner.targets(for: makeProfile(), currentWeightKg: 90, on: day(2026, 10, 27))
    let monday = planner.mealPlan(for: targets, profile: makeProfile(), on: day(2026, 10, 26), constraints: MealConstraints())
    let tuesday = planner.mealPlan(for: targets, profile: makeProfile(), on: day(2026, 10, 27), constraints: MealConstraints())
    #expect(monday.meals.map(\.title) != tuesday.meals.map(\.title))
}

@Test func unitFoodsShowNaturalQuantities() {
    let template = MealTemplates.breakfasts[1]
    let meal = planner.portioned(template, targetKcal: 500)
    let eggs = meal.items.first { $0.name == "Œufs" }
    #expect(eggs?.quantityLabel.hasSuffix("œufs") == true)
}

@Test func restaurantReplacesMealAndAbsorbsSnack() throws {
    let targets = planner.targets(for: makeProfile(), currentWeightKg: 90, on: day(2026, 10, 27))
    let plan = planner.mealPlan(for: targets, profile: makeProfile(), on: day(2026, 10, 27), constraints: MealConstraints(eatingOut: .dinner))
    #expect(plan.meals.map(\.slot) == [.breakfast, .lunch, .dinner])
    let dinner = try #require(plan.meals.last)
    #expect(dinner.isEatingOut)
    #expect(abs(dinner.macros.kcal - targets.macros.kcal * 0.40) < 1)
    #expect(!plan.notes.isEmpty)
}

@Test func lowAppetiteShrinksPortionsAboveSafetyFloor() {
    let profile = makeProfile()
    let targets = planner.targets(for: profile, currentWeightKg: 90, on: day(2026, 10, 27))
    let normal = planner.mealPlan(for: targets, profile: profile, on: day(2026, 10, 27), constraints: MealConstraints())
    let light = planner.mealPlan(for: targets, profile: profile, on: day(2026, 10, 27), constraints: MealConstraints(lowAppetite: true))
    #expect(light.totals.kcal < normal.totals.kcal)
    #expect(light.totals.kcal > targets.macros.kcal * 0.75)
}

@Test func lowAppetiteNeverPlansBelowFloor() {
    let floorTargets = NutritionTargets(macros: Macros(kcal: 1250, proteinG: 100, carbsG: 120, fatG: 40), maintenanceKcal: 1500, rationale: "")
    let profile = makeProfile(sex: .female)
    let plan = planner.mealPlan(for: floorTargets, profile: profile, on: day(2026, 10, 27), constraints: MealConstraints(lowAppetite: true))
    // 85 % de 1 250 = 1 062 < 1 200 : on reste au plancher (à l'arrondi des portions près).
    #expect(plan.totals.kcal > 1200 * 0.9)
}
