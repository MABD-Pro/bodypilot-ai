import BodyPilotCore
import Testing
@testable import Nutrition

private let menu = [
    "LA BRASSERIE",
    "Entrées",
    "Soupe à l'oignon 8,50 €",
    "Plats",
    "Entrecôte grillée 26 €",
    "frites maison et salade verte",
    "Burger du chef, frites ........ 18,90",
    "Pâtes carbonara 16 €",
    "Pavé de saumon, riz 22€",
    "Desserts",
    "Brownie au chocolat 7 €",
    "Boissons",
    "Coca 4,00 €",
]

private let dinner = Macros(kcal: 800, proteinG: 50, carbsG: 80, fatG: 30)

@Test func pricesHeadingsDessertsAndDrinksAreRemoved() {
    let dishes = MenuAdvisor.dishes(fromLines: menu)
    #expect(dishes.contains("Soupe à l'oignon"))
    #expect(dishes.contains("Entrecôte grillée, frites maison et salade verte"))
    #expect(dishes.contains("Burger du chef, frites"))
    #expect(dishes.contains("Pavé de saumon, riz"))
    #expect(!dishes.contains { $0.contains("Brownie") || $0.contains("Coca") || $0 == "Plats" || $0 == "LA BRASSERIE" })
}

@Test func proteinRichDishInTheTargetComesFirst() throws {
    let picks = MenuAdvisor.advise(lines: menu, target: dinner)
    #expect(picks.count == MenuAdvisor.maxPicks)
    let best = try #require(picks.first)
    #expect(best.dish.hasPrefix("Pavé de saumon") || best.dish.hasPrefix("Entrecôte"))
    #expect(best.macros.proteinG >= 30)
    // Les pâtes carbonara, pauvres en protéines et copieuses, ne passent pas devant.
    #expect(picks.firstIndex { $0.dish.hasPrefix("Pâtes") } ?? Int.max > 0)
}

@Test func fitDescribesTheDish() {
    let heavy = MenuAdvisor.pick(dish: "x", meal: DescribedMeal(text: "x", foods: MealTextParser.parse("une grande pizza et des frites").foods), target: dinner)
    #expect(heavy.fit == .heavy)
    let light = MenuAdvisor.pick(dish: "y", meal: DescribedMeal(text: "y", foods: MealTextParser.parse("une soupe").foods), target: dinner)
    #expect(light.fit == .lowProtein)
}

@Test func priceFormatsAreStripped() {
    #expect(MenuAdvisor.withoutPrice("Tartare de bœuf 19,50 €") == "Tartare de bœuf")
    #expect(MenuAdvisor.withoutPrice("Salade César ..... 14.90") == "Salade César")
    #expect(MenuAdvisor.withoutPrice("• Omelette 9") == "Omelette")
}

@Test func unreadableMenuGivesNothing() {
    #expect(MenuAdvisor.advise(lines: ["Bienvenue", "Ouvert 7j/7", "12 €"], target: dinner).isEmpty)
}
