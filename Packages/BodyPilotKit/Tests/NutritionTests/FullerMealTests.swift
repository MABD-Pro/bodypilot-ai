import BodyPilotCore
import Foundation
import Testing
@testable import Nutrition

private let planner = MealPlanner(calculator: EnergyCalculator(calendar: utc))
private let today = day(2026, 10, 31)

@Test func fullerMealGetsMoreProteinAndTheDayStaysTheSame() throws {
    let targets = planner.targets(for: makeProfile(), currentWeightKg: 90, on: today)
    let plain = planner.mealPlan(for: targets, profile: makeProfile(), on: today, constraints: MealConstraints())
    let fuller = planner.mealPlan(for: targets, profile: makeProfile(), on: today, constraints: MealConstraints(fullerMeal: .lunch))
    let plainLunch = try #require(plain.meals.first { $0.slot == .lunch })
    let fullerLunch = try #require(fuller.meals.first { $0.slot == .lunch })
    #expect(fullerLunch.macros.proteinG > plainLunch.macros.proteinG + 5)
    #expect(fullerLunch.macros.kcal > plainLunch.macros.kcal)
    // Le total du jour ne bouge presque pas : la part vient des autres repas.
    #expect(abs(fuller.totals.kcal - plain.totals.kcal) / plain.totals.kcal < 0.05)
    #expect(abs(fuller.totals.proteinG - plain.totals.proteinG) / plain.totals.proteinG < 0.08)
}

@Test func snackIsNeverTheFullerMeal() {
    let targets = planner.targets(for: makeProfile(), currentWeightKg: 90, on: today)
    let plain = planner.mealPlan(for: targets, profile: makeProfile(), on: today, constraints: MealConstraints())
    let snack = planner.mealPlan(for: targets, profile: makeProfile(), on: today, constraints: MealConstraints(fullerMeal: .snack))
    #expect(plain == snack)
}
