import BodyPilotCore
import Foundation
import Testing
@testable import Training

private let planner = TrainingPlanner(calendar: utc)
private let monday = day(2026, 10, 26)
private let wednesday = day(2026, 10, 28)
private let week6 = CycleWeek(program: .crossfit, number: 6)

private func options(sessions: Int, done: [String], lastStrength: Date? = nil, on date: Date = wednesday) -> TrainingOptions {
    planner.options(for: makeProfile(sessionMinutes: 60, equipment: .gym), on: date, constraints: DayConstraints(
        lastWorkoutTitle: done.last { TrainingPlanner.isStrengthSession($0) },
        lastStrengthDay: lastStrength,
        cycleWeek: week6, cycleWorkoutsThisWeek: done, cyclePlan: CycleSessionPlan(sessions: sessions)
    ))
}

@Test func sessionPlanSharesStrengthIntervalsAndAerobic() {
    let shares = (2...6).map { CycleSessionPlan(sessions: $0) }.map { [$0.strength, $0.hard, $0.aerobic] }
    #expect(shares == [[2, 0, 0], [2, 1, 0], [3, 1, 0], [3, 1, 1], [3, 1, 2]])
    #expect(CycleSessionPlan(sessions: 1).sessions == 2)
    #expect(CycleSessionPlan(sessions: 9).sessions == 6)
}

@Test func recentAverageCountsDoneDaysOverFullWeeks() {
    let done = (1...21).filter { $0 % 3 == 0 }.map { day(2026, 10, $0) } + [day(2026, 10, 22)]
    // Historique depuis le 3 : 2 semaines pleines (du 8 au 21), 5 séances, 2,5 arrondi à 3.
    #expect(CycleSessionPlan.recentAverage(doneDays: done, before: day(2026, 10, 22), calendar: utc) == 3)
    // Avec le 1er : 3 semaines pleines, 8 séances, 2,7 arrondi à 3 ; sur 2 semaines seulement, la même chose.
    #expect(CycleSessionPlan.recentAverage(doneDays: done + [day(2026, 10, 1)], before: day(2026, 10, 22), calendar: utc) == 3)
    #expect(CycleSessionPlan.recentAverage(doneDays: [day(2026, 10, 20)], before: day(2026, 10, 22), calendar: utc) == nil)
}

@Test func threeSessionsGiveTwoStrengthAndTheIntervals() {
    // Deux forces faites, la force serait possible (48 h) : c'est le jour du fractionné.
    let third = options(sessions: 3, done: ["Full body A", "Full body B"], lastStrength: monday)
    #expect(third.recommended == .conditioning)
    #expect(third.reason.contains("fractionné"))
    // Les 3 séances faites : repos.
    let fourth = options(sessions: 3, done: ["Full body A", CycleCardio.intervalsTitle, "Full body B"], lastStrength: monday)
    #expect(fourth.recommended == .rest)
}

@Test func strengthLeftWithCardioDoneMeansAWalkUntilTheNextStrength() {
    let next = options(sessions: 3, done: ["Full body A", CycleCardio.intervalsTitle], lastStrength: day(2026, 10, 27))
    #expect(next.recommended == .light)
}

@Test func withoutPlanStrengthStillComesEvery48Hours() {
    let free = planner.options(for: makeProfile(sessionMinutes: 60, equipment: .gym), on: wednesday, constraints: DayConstraints(
        lastWorkoutTitle: "Full body B", lastStrengthDay: monday, cycleWeek: week6, cycleWorkoutsThisWeek: ["Full body A", "Full body B"]
    ))
    #expect(free.recommended == .strength)
}

@Test func twoSessionsPutTheIntervalsAfterStrength() throws {
    let options = options(sessions: 2, done: [], on: monday)
    #expect(options.recommended == .strength)
    let day = try #require(options.option(.strength)?.day)
    guard case .workout(let workout) = day.kind else { Issue.record("Pas de séance"); return }
    #expect(workout.exercises.contains { $0.name == "Rameur fractionné" })
    #expect(!workout.exercises.contains { $0.name.hasPrefix("EMOM") })
    #expect(day.notes.contains { $0.hasPrefix("2 séances cette semaine") })
    // Pas de fractionné à part : le cardio du jour reste aérobie.
    guard case .workout(let cardio) = options.option(.conditioning)?.day.kind else { Issue.record("Pas de cardio"); return }
    #expect(cardio.title == CycleCardio.aerobicTitle)
}
