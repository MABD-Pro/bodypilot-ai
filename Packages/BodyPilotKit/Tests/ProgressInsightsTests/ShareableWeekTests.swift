import BodyPilotCore
import Foundation
import Testing
@testable import ProgressInsights

private let thursday = utc.date(from: DateComponents(year: 2026, month: 10, day: 29, hour: 12))!
private let dayTarget = Macros(kcal: 2_000, proteinG: 150, carbsG: 200, fatG: 70)

private func oct(_ day: Int) -> Date { utc.date(from: DateComponents(year: 2026, month: 10, day: day, hour: 12))! }

private func weekReview(completed: [(day: Date, title: String?)] = []) -> WeekReview {
    let days = (23...28).map {
        ReviewDayInput(day: oct($0), target: dayTarget, eaten: Macros(kcal: 2_000, proteinG: 150, carbsG: 0, fatG: 0), mealsNoted: 4, mealsPlanned: 4)
    }
    let today = ReviewToday(meals: DayMealPlan(meals: []), target: dayTarget, training: TrainingDay(kind: .rest, estimatedMinutes: 0), workoutDone: false)
    return WeekReviewer(calendar: utc).review(days: days, samples: [], completed: completed, sessionMinutes: 45, today: today, on: thursday)
}

@Test func shareableWeekHidesBodyByDefault() {
    let review = weekReview(completed: [(oct(24), "Full body A"), (oct(26), "Cardio")])
    let week = ShareableWeekBuilder.make(review: review, headline: "Belle semaine.", weeklyWeightChangeKg: -0.4, waistChangeCm: -1.5, showsBody: false, calendar: utc)
    #expect(week.period == "23 – 29 octobre")
    #expect(week.stats.first?.value == "2")
    #expect(!week.stats.contains { $0.label.contains("poids") || $0.label.contains("taille") })
    #expect(week.stats.contains { $0.label == "jours avec mes protéines" && $0.value == "6/6" })
    #expect(week.text.hasPrefix("Ma semaine avec BodyPilot (23 – 29 octobre)\nBelle semaine."))
}

@Test func shareableWeekShowsChangesOnlyWhenAsked() {
    let week = ShareableWeekBuilder.make(review: weekReview(), headline: "", weeklyWeightChangeKg: -0.4, waistChangeCm: -1.5, showsBody: true, calendar: utc)
    #expect(week.stats.contains { $0.value == "-0,4 kg" })
    #expect(week.stats.contains { $0.value == "-1,5 cm" })
    // Sans séance : pas de « dont 0 de force ».
    #expect(week.stats.first?.label == "séance")
}

@Test func periodSpansTwoMonths() {
    let days = [utc.date(from: DateComponents(year: 2026, month: 10, day: 28))!, utc.date(from: DateComponents(year: 2026, month: 11, day: 3))!]
    #expect(ShareableWeekBuilder.periodLabel(days, calendar: utc) == "28 octobre – 3 novembre")
}
