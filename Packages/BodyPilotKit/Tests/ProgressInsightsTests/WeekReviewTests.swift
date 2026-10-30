import BodyPilotCore
import Foundation
import Testing
@testable import ProgressInsights

private let reviewer = WeekReviewer(calendar: utc)
// Jeudi 29/10/2026 à midi : les 7 jours vont du 23 au 29, la semaine du calendrier commence le 26.
private let thursdayNoon = utc.date(from: DateComponents(year: 2026, month: 10, day: 29, hour: 12))!
private let target = Macros(kcal: 2_000, proteinG: 150, carbsG: 200, fatG: 70)

private func october(_ dayOfMonth: Int, _ hour: Int = 12) -> Date {
    utc.date(from: DateComponents(year: 2026, month: 10, day: dayOfMonth, hour: hour))!
}

private func input(_ dayOfMonth: Int, kcal: Double, protein: Double, meals: Int = 4, steps: Int? = nil) -> ReviewDayInput {
    ReviewDayInput(
        day: october(dayOfMonth), target: target,
        eaten: Macros(kcal: kcal, proteinG: protein, carbsG: 0, fatG: 0),
        mealsNoted: meals, mealsPlanned: 4, steps: steps
    )
}

private func meal(_ slot: MealSlot, _ title: String, kcal: Double, protein: Double, eaten: Bool = false) -> PlannedMeal {
    PlannedMeal(slot: slot, title: title, items: [], macros: Macros(kcal: kcal, proteinG: protein, carbsG: 0, fatG: 0), intake: eaten ? .asPlanned : nil)
}

private func today(workoutDone: Bool = false, steps: Int? = nil, stepsGoal: Int? = nil) -> ReviewToday {
    ReviewToday(
        meals: DayMealPlan(meals: [
            meal(.breakfast, "Skyr et flocons d'avoine", kcal: 500, protein: 40, eaten: true),
            meal(.lunch, "Poulet, riz et légumes", kcal: 700, protein: 50),
            meal(.snack, "Fromage blanc", kcal: 200, protein: 20),
            meal(.dinner, "Saumon et pommes de terre", kcal: 600, protein: 40),
        ]),
        target: target,
        training: TrainingDay(kind: .rest, estimatedMinutes: 0),
        workoutDone: workoutDone,
        steps: steps,
        stepsGoal: stepsGoal
    )
}

@Test func aCompleteDayIsJudgedOnCaloriesAndProtein() {
    let days = [
        input(23, kcal: 2_000, protein: 150),
        input(24, kcal: 2_400, protein: 120),
        input(25, kcal: 1_500, protein: 140),
        input(26, kcal: 900, protein: 60, meals: 2),
        input(28, kcal: 2_100, protein: 100),
        input(29, kcal: 500, protein: 40, meals: 1),
    ]
    let review = reviewer.review(days: days, samples: [], completed: [], sessionMinutes: 45, today: today(), on: thursdayNoon)
    #expect(review.days.count == 7)
    #expect(review.days.first?.day == utc.startOfDay(for: october(23)))
    #expect(review.days.map(\.kcalStatus) == [.onTarget, .over, .under, nil, nil, .onTarget, nil])
    #expect(review.days.map(\.proteinReached) == [true, false, true, nil, nil, false, nil])
    // Le 27, sans journal : aucun repas noté, la journée reste dans la liste.
    #expect(review.days[4].mealsNoted == 0)
    #expect(review.days[4].summary == "Repas non notés")
    #expect(review.days[1].comment.hasPrefix("400\u{00A0}kcal au-dessus"))
}

@Test func averagesOnlyCountCompleteDays() {
    let days = [
        input(23, kcal: 2_000, protein: 150),
        input(24, kcal: 2_400, protein: 120),
        input(25, kcal: 1_500, protein: 140),
        input(26, kcal: 900, protein: 60, meals: 2),
        input(28, kcal: 2_100, protein: 100),
    ]
    let review = reviewer.review(days: days, samples: [], completed: [], sessionMinutes: 45, today: today(), on: thursdayNoon)
    #expect(review.completeDays == 4)
    #expect(review.averageEaten?.kcal == 2_000)
    #expect(review.averageEaten?.proteinG == 127.5)
    #expect(review.proteinDays == 2)
    #expect(review.kcalOnTargetDays == 2)
    // Protéines à 85 % en moyenne : premier conseil nutrition de la semaine.
    #expect(review.restOfWeek.contains { $0.hasPrefix("Protéines : 128\u{00A0}g par jour") })
    #expect(review.wins.contains("Protéines atteintes 2 jours sur 4."))
}

@Test func sessionsAndStrengthAreCountedOverSevenDays() {
    let samples = [
        ActivitySample(id: "run", kind: .running, start: october(28, 7), minutes: 30, kcal: 300),
        // Trop courte pour une séance, mais ses minutes comptent.
        ActivitySample(id: "walk", kind: .walking, start: october(25, 18), minutes: 15),
    ]
    let completed: [(day: Date, title: String?)] = [(october(24), "Full body B"), (october(27), "Full body A")]
    let review = reviewer.review(days: [], samples: samples, completed: completed, sessionMinutes: 45, today: today(), on: thursdayNoon)
    #expect(review.sessions == 3)
    #expect(review.strengthSessions == 2)
    #expect(review.activeMinutes == 135)
    #expect(review.enduranceMinutes == 45)
    #expect(review.wins.first == "2 séances de force en 7 jours : c'est ce qui garde ton muscle pendant que le gras part.")
    #expect(review.days[4].comment.contains("Séance de force faite."))
    // Une seule séance de force dans la semaine du calendrier (le 27) : une de plus d'ici dimanche.
    #expect(review.restOfWeek.first?.hasPrefix("Force : 1 séance depuis lundi.") == true)
    #expect(review.restOfWeek.contains { $0.hasPrefix("45 min d'endurance en 7 jours") })
}

@Test func caloriesAboveTargetPointToTheWorstDay() {
    let days = [
        input(26, kcal: 2_300, protein: 150),
        input(27, kcal: 2_600, protein: 150),
        input(28, kcal: 2_300, protein: 150),
    ]
    let review = reviewer.review(days: days, samples: [], completed: [], sessionMinutes: 45, today: today(), on: thursdayNoon)
    #expect(review.restOfWeek.count == 3)
    #expect(review.restOfWeek[0].hasPrefix("Force : pas encore de séance depuis lundi. Places-en 2"))
    #expect(review.restOfWeek[1].hasPrefix("Calories : 400\u{00A0}kcal par jour au-dessus de l'objectif en moyenne, surtout mardi (+600)."))
}

@Test func fewCompleteDaysAskForOneTapMeals() {
    let review = reviewer.review(days: [input(28, kcal: 2_000, protein: 150)], samples: [], completed: [], sessionMinutes: 45, today: today(), on: thursdayNoon)
    #expect(review.restOfWeek.contains { $0.contains("avec 1 journée complète sur 7") })
    #expect(review.averageEaten?.kcal == 2_000)
}

@Test func theRestOfTheDayFollowsRemainingMealsTrainingAndSteps() {
    let advice = reviewer.restOfDay(today(steps: 3_000, stepsGoal: 8_000))
    #expect(advice.count == 3)
    #expect(advice[0] == "Encore 3 repas, environ 1\u{202F}500\u{00A0}kcal et 110\u{00A0}g de protéines. Prochain : poulet, riz et légumes.")
    #expect(advice[1].hasPrefix("Repos aujourd'hui"))
    #expect(advice[2] == "Encore 5\u{202F}000 pas pour ton objectif du jour (8\u{202F}000).")
    #expect(reviewer.restOfDay(today(workoutDone: true))[1].hasPrefix("Séance du jour faite"))
}

@Test func caloriesAlreadyReachedChangeTheAdvice() {
    var full = today()
    full.meals.meals[0].macros.kcal = 2_100
    #expect(reviewer.restOfDay(full)[0].hasPrefix("Objectif de calories déjà atteint"))
    var done = today()
    for index in done.meals.meals.indices { done.meals.meals[index].intake = .asPlanned }
    // 150 g de protéines notés sur 150 : rien à ajouter.
    #expect(reviewer.restOfDay(done)[0] == "Journée de repas bouclée. Rien à ajouter, bravo.")
}

@Test func anEmptyWeekInvitesToStartWithoutBlame() {
    let review = reviewer.review(days: [], samples: [], completed: [], sessionMinutes: 45, today: today(), on: thursdayNoon)
    #expect(review.headline.hasPrefix("Ton bilan se remplit"))
    #expect(review.wins.isEmpty)
    #expect(review.days.allSatisfy { $0.mealsNoted == 0 && $0.activities.isEmpty })
}

@Test func lowFiberIsAdvisedForTheWeek() {
    let withFiber = Macros(kcal: 2_000, proteinG: 150, carbsG: 200, fatG: 70, fiberG: 30)
    let days = (23...28).map { day in
        ReviewDayInput(day: october(day), target: withFiber, eaten: Macros(kcal: 2_000, proteinG: 150, carbsG: 200, fatG: 70, fiberG: 15), mealsNoted: 4, mealsPlanned: 4)
    }
    let review = reviewer.review(days: days, samples: [], completed: [], sessionMinutes: 45, today: today(), on: thursdayNoon)
    #expect(abs((review.averageEaten?.fiberG ?? 0) - 15) < 0.001)
    #expect(review.restOfWeek.contains { $0.hasPrefix("Fibres : 15\u{00A0}g par jour") })
}
