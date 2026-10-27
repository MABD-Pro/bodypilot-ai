import BodyPilotCore
import Foundation
import Testing
@testable import Nutrition

private let export = HealthMealExport(calendar: utc)
private let today = day(2026, 10, 27)
private let evening = utc.date(bySettingHour: 21, minute: 0, second: 0, of: today)!

private func meal(_ slot: MealSlot, kcal: Double, intake: MealIntake? = nil, described: DescribedMeal? = nil) -> PlannedMeal {
    PlannedMeal(slot: slot, title: "Repas \(slot.rawValue)", items: [], macros: Macros(kcal: kcal, proteinG: 30, carbsG: 50, fatG: 15), intake: intake, described: described)
}

@Test func onlyEatenMealsGoToHealth() {
    let plan = DayMealPlan(meals: [
        meal(.breakfast, kcal: 500, intake: .asPlanned),
        meal(.lunch, kcal: 700, described: DescribedMeal(text: "pâtes", foods: [])),
        meal(.snack, kcal: 0, intake: .skipped),
        meal(.dinner, kcal: 800),
    ])
    let entries = export.entries(for: plan, on: today, now: evening)
    #expect(entries.map(\.slot) == [.breakfast, .lunch])
    #expect(entries.first?.macros.kcal == 500)
}

@Test func theIdentifierIsStablePerMealAndDay() {
    #expect(export.id(for: .dinner, on: today) == "bodypilot-2026-10-27-dinner")
    #expect(export.id(for: .dinner, on: today) != export.id(for: .lunch, on: today))
}

@Test func aMealLoggedInAdvanceIsNotDatedInTheFuture() {
    let sixPM = utc.date(bySettingHour: 18, minute: 0, second: 0, of: today)!
    let plan = DayMealPlan(meals: [meal(.dinner, kcal: 800, intake: .asPlanned), meal(.lunch, kcal: 600, intake: .asPlanned)])
    let entries = export.entries(for: plan, on: today, now: sixPM)
    #expect(entries.first { $0.slot == .dinner }?.date == sixPM)
    #expect(entries.first { $0.slot == .lunch }?.date == utc.date(bySettingHour: 12, minute: 30, second: 0, of: today))
}

@Test func theFingerprintChangesOnlyWithTheContent() {
    let plan = DayMealPlan(meals: [meal(.breakfast, kcal: 500, intake: .asPlanned)])
    let early = export.entries(for: plan, on: today, now: utc.date(bySettingHour: 7, minute: 0, second: 0, of: today)!)
    let late = export.entries(for: plan, on: today, now: evening)
    #expect(early.first?.fingerprint == late.first?.fingerprint)
    let hearty = export.entries(for: DayMealPlan(meals: [meal(.breakfast, kcal: 700, intake: .hearty)]), on: today, now: evening)
    #expect(hearty.first?.fingerprint != late.first?.fingerprint)
}
