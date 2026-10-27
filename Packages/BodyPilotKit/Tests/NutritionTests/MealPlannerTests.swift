import BodyPilotCore
import Testing
@testable import Nutrition

private let planner = MealPlanner(calculator: EnergyCalculator(calendar: utc))

@Test func planCoversEveryMealOfTheDay() {
    let targets = planner.targets(for: makeProfile(), currentWeightKg: 90, on: day(2026, 10, 27))
    let plan = planner.mealPlan(for: targets, on: day(2026, 10, 27))
    #expect(plan.meals.map(\.slot) == MealSlot.allCases)
}

@Test func portionsLandCloseToTargetCalories() {
    for kcal in stride(from: 1600.0, through: 3000, by: 200) {
        let targets = NutritionTargets(macros: Macros(kcal: kcal, proteinG: 150, carbsG: 200, fatG: 60), maintenanceKcal: kcal, rationale: "")
        for offset in 0..<3 {
            let date = utc.date(byAdding: .day, value: offset, to: day(2026, 10, 27))!
            let total = planner.mealPlan(for: targets, on: date).totals.kcal
            #expect(abs(total - kcal) / kcal < 0.1, "\(kcal) kcal, jour \(offset) : \(total)")
        }
    }
}

@Test func mealsRotateFromOneDayToTheNext() {
    let targets = planner.targets(for: makeProfile(), currentWeightKg: 90, on: day(2026, 10, 27))
    let monday = planner.mealPlan(for: targets, on: day(2026, 10, 26))
    let tuesday = planner.mealPlan(for: targets, on: day(2026, 10, 27))
    #expect(monday.meals.map(\.title) != tuesday.meals.map(\.title))
}

@Test func unitFoodsShowNaturalQuantities() {
    let template = MealTemplates.breakfasts[1]
    let meal = planner.portioned(template, targetKcal: 500)
    let eggs = meal.items.first { $0.name == "Œufs" }
    #expect(eggs?.quantityLabel.hasSuffix("œufs") == true)
}
