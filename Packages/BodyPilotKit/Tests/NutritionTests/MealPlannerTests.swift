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

@Test func heartyLunchLightensTheRestOfTheDay() throws {
    let targets = NutritionTargets(macros: Macros(kcal: 2200, proteinG: 160, carbsG: 220, fatG: 70), maintenanceKcal: 2600, rationale: "")
    let date = day(2026, 10, 27)
    let normal = planner.mealPlan(for: targets, profile: makeProfile(), on: date, constraints: MealConstraints())
    let after = planner.mealPlan(for: targets, profile: makeProfile(), on: date, constraints: MealConstraints(eaten: [.breakfast: .asPlanned, .lunch: .hearty]))

    let lunch = try #require(after.meals.first { $0.slot == .lunch })
    #expect(lunch.intake == .hearty)
    let dinnerBefore = try #require(normal.meals.first { $0.slot == .dinner })
    let dinnerAfter = try #require(after.meals.first { $0.slot == .dinner })
    #expect(dinnerAfter.macros.kcal < dinnerBefore.macros.kcal)
    #expect(abs(after.totals.kcal - 2200) / 2200 < 0.1)
    #expect(after.notes.contains { $0.hasPrefix("Repas copieux") })
}

@Test func skippedMealIsOnlyPartlyMadeUp() throws {
    let targets = NutritionTargets(macros: Macros(kcal: 2200, proteinG: 160, carbsG: 220, fatG: 70), maintenanceKcal: 2600, rationale: "")
    let date = day(2026, 10, 27)
    let normal = planner.mealPlan(for: targets, profile: makeProfile(), on: date, constraints: MealConstraints())
    let after = planner.mealPlan(for: targets, profile: makeProfile(), on: date, constraints: MealConstraints(eaten: [.breakfast: .skipped, .lunch: .skipped]))

    let breakfast = try #require(after.meals.first { $0.slot == .breakfast })
    #expect(breakfast.macros.kcal == 0)
    let dinnerBefore = try #require(normal.meals.first { $0.slot == .dinner }).macros.kcal
    let dinnerAfter = try #require(after.meals.first { $0.slot == .dinner }).macros.kcal
    // On ne double pas le dîner : au plus +40 % (à l'arrondi des portions près).
    #expect(dinnerAfter > dinnerBefore)
    #expect(dinnerAfter < dinnerBefore * 1.5)
    #expect(after.notes.contains { $0.contains("sans tout rattraper") })
}

@Test func mealsEatenAsPlannedChangeNothing() {
    let targets = planner.targets(for: makeProfile(), currentWeightKg: 90, on: day(2026, 10, 27))
    let date = day(2026, 10, 27)
    let normal = planner.mealPlan(for: targets, profile: makeProfile(), on: date, constraints: MealConstraints())
    let after = planner.mealPlan(for: targets, profile: makeProfile(), on: date, constraints: MealConstraints(eaten: [.breakfast: .asPlanned]))
    #expect(after.meals.map(\.macros) == normal.meals.map(\.macros))
    #expect(after.notes.isEmpty)
}

@Test func mealEatenAsPlannedCountsTheAdjustedPortion() throws {
    let targets = NutritionTargets(macros: Macros(kcal: 2200, proteinG: 160, carbsG: 220, fatG: 70), maintenanceKcal: 2600, rationale: "")
    let date = day(2026, 10, 27)
    let proposed = planner.mealPlan(for: targets, profile: makeProfile(), on: date, constraints: MealConstraints(eaten: [.breakfast: .asPlanned, .lunch: .hearty]))
    let eaten = planner.mealPlan(for: targets, profile: makeProfile(), on: date, constraints: MealConstraints(eaten: [.breakfast: .asPlanned, .lunch: .hearty, .dinner: .asPlanned]))

    // Le dîner allégé qu'on vient de proposer est celui qui a été mangé, pas la portion d'origine.
    let dinnerProposed = try #require(proposed.meals.first { $0.slot == .dinner })
    let dinnerEaten = try #require(eaten.meals.first { $0.slot == .dinner })
    #expect(dinnerEaten.intake == .asPlanned)
    #expect(dinnerEaten.macros == dinnerProposed.macros)
    #expect(abs(eaten.totals.kcal - 2200) / 2200 < 0.1)
}

@Test func proteinIsSpreadEvenlyOverMainMeals() {
    // 175 g par jour : au moins 0,4 g/kg (35 g pour 87,5 kg de référence) à chaque repas principal.
    let targets = NutritionTargets(macros: Macros(kcal: 2340, proteinG: 175, carbsG: 250, fatG: 70), maintenanceKcal: 2725, rationale: "")
    for offset in 0..<3 {
        let date = utc.date(byAdding: .day, value: offset, to: day(2026, 10, 27))!
        let plan = planner.mealPlan(for: targets, profile: makeProfile(), on: date, constraints: MealConstraints())
        for meal in plan.meals where meal.slot != .snack {
            #expect(meal.macros.proteinG >= 35, "\(meal.title) : \(meal.macros.proteinG) g")
        }
        #expect(abs(plan.totals.proteinG - 175) / 175 < 0.1, "jour \(offset) : \(plan.totals.proteinG) g")
        #expect(abs(plan.totals.kcal - 2340) / 2340 < 0.1)
    }
}

@Test func lowAppetiteKeepsProtein() {
    let targets = NutritionTargets(macros: Macros(kcal: 2340, proteinG: 175, carbsG: 250, fatG: 70), maintenanceKcal: 2725, rationale: "")
    let date = day(2026, 10, 27)
    let normal = planner.mealPlan(for: targets, profile: makeProfile(), on: date, constraints: MealConstraints())
    let light = planner.mealPlan(for: targets, profile: makeProfile(), on: date, constraints: MealConstraints(lowAppetite: true))
    #expect(light.totals.kcal < normal.totals.kcal)
    #expect(light.totals.proteinG >= normal.totals.proteinG * 0.9)
}
