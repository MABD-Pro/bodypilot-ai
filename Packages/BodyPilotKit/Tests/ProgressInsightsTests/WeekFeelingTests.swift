import BodyPilotCore
import Foundation
import Testing
@testable import ProgressInsights

private let reviewer = WeekReviewer(calendar: utc)

private func review(_ advice: [WeekAdvice]) -> WeekReview {
    WeekReview(
        days: [], completeDays: 0, averageEaten: nil, averageTarget: nil, proteinDays: 0, kcalOnTargetDays: 0,
        sessions: 0, strengthSessions: 0, activeMinutes: 0, enduranceMinutes: 0, averageSteps: nil,
        headline: "", wins: [], restOfDay: [], restOfWeek: [], weekAdvice: advice
    )
}

private let numbers = review([
    WeekAdvice(.strength, "Force"),
    WeekAdvice(.protein, "Protéines"),
    WeekAdvice(.fiber, "Fibres"),
    WeekAdvice(.endurance, "Endurance"),
])

@Test func withoutFeelingPrioritiesAreTheFirstThreeAdvices() {
    #expect(reviewer.priorities(numbers, feeling: nil).map(\.text) == ["Force", "Protéines", "Fibres"])
}

@Test func obstaclesComeFirstAndReplaceTheirTopic() {
    let feeling = WeekFeeling(mood: .soso, obstacles: [.hunger, .time])
    let priorities = reviewer.priorities(numbers, feeling: feeling)
    #expect(priorities.count == 3)
    // Ordre fixe des obstacles : la faim avant le temps, quel que soit l'ordre de saisie.
    #expect(priorities[0].topic == .obstacle(.hunger))
    #expect(priorities[1].topic == .obstacle(.time))
    // La faim couvre déjà les protéines : la priorité suivante est la force.
    #expect(priorities[2].text == "Force")
}

@Test func atMostTwoObstaclesAreKept() {
    let feeling = WeekFeeling(mood: .hard, obstacles: Set(WeekObstacle.allCases))
    let priorities = reviewer.priorities(numbers, feeling: feeling)
    #expect(priorities.map(\.topic) == [.obstacle(.pain), .obstacle(.fatigue), .strength])
}

@Test func aHardWeekWithoutObstacleAimsForTheMinimum() {
    let priorities = reviewer.priorities(numbers, feeling: WeekFeeling(mood: .hard))
    #expect(priorities.first?.topic == .mood)
    // Le minimum couvre la force : elle ne revient pas.
    #expect(priorities.map(\.text).dropFirst() == ["Protéines", "Fibres"])
}

@Test func nothingToFixStaysWhenItIsAllThereIs() {
    let calm = review([WeekAdvice(.none, "Rien à corriger")])
    #expect(reviewer.priorities(calm, feeling: WeekFeeling(mood: .great)).map(\.text) == ["Rien à corriger"])
    #expect(reviewer.priorities(calm, feeling: WeekFeeling(mood: .good, obstacles: [.time])).map(\.topic) == [.obstacle(.time)])
}
