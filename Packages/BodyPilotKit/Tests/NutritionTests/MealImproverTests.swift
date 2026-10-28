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
