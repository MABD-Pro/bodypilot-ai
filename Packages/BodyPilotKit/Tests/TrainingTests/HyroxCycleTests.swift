import BodyPilotCore
import Foundation
import Testing
@testable import Training

private let planner = TrainingPlanner(calendar: utc)
private let monday = day(2026, 10, 26)
private let tuesday = day(2026, 10, 27)

private func hyrox(_ number: Int) -> CycleWeek { CycleWeek(program: .hyrox, number: number) }

private func workout(_ day: TrainingDay?) -> Workout? {
    if case .workout(let workout) = day?.kind { return workout }
    return nil
}

private func options(week: Int, done: [String] = [], sessions: Int = 5, lastStrength: Date? = monday, lowEnergy: Bool = false, on date: Date = tuesday) -> TrainingOptions {
    var constraints = DayConstraints(
        lastWorkoutTitle: "Full body A", lastStrengthDay: lastStrength,
        cycleWeek: hyrox(week), cycleWorkoutsThisWeek: done, cyclePlan: CycleSessionPlan(sessions: sessions, program: .hyrox)
    )
    constraints.lowEnergy = lowEnergy
    return planner.options(for: makeProfile(sessionMinutes: 60, equipment: .gym), on: date, constraints: constraints)
}

@Test func hyroxPlanPutsRunningFirst() {
    let shares = (2...6).map { CycleSessionPlan(sessions: $0, program: .hyrox) }.map { [$0.strength, $0.hard, $0.fundamentals, $0.aerobic] }
    #expect(shares == [[1, 1, 0, 0], [1, 1, 1, 0], [2, 1, 0, 1], [2, 1, 1, 1], [2, 1, 1, 2]])
    #expect(CycleSessionPlan(sessions: 4, program: .hyrox).stationsAfterStrength)
    #expect(!CycleSessionPlan(sessions: 2, program: .hyrox).intervalsAfterStrength)
}

@Test func hyroxPhasesAreAboutRunning() {
    #expect(hyrox(2).label == "Cycle Hyrox · semaine 2 sur 12 · phase 1, courir-marcher")
    #expect(hyrox(10).phaseTitle == "courir fatigué")
}

@Test func dayAfterStrengthIsTheQualitySession() throws {
    let options = options(week: 6, done: ["Full body A"])
    #expect(options.recommended == .conditioning)
    #expect(options.reason.contains("séance de qualité"))
    let session = try #require(workout(options.option(.conditioning)?.day))
    #expect(session.title == HyroxCycle.qualityTitle)
    #expect(session.exercises.first?.name == "1 km à allure Hyrox" && session.exercises.first?.sets == 5)
}

@Test func firstAndEleventhWeeksHaveTheTest() throws {
    let first = try #require(workout(options(week: 1, done: ["Full body A"]).option(.conditioning)?.day))
    #expect(first.title == HyroxCycle.benchmarkTitle && first.isCycleBenchmark)
    let eleventh = try #require(workout(options(week: 11, done: ["Full body A"]).option(.conditioning)?.day))
    #expect(eleventh.title == HyroxCycle.benchmarkTitle)
}

@Test func tiredSkipsTheQualitySessionForTheFundamentals() throws {
    let session = try #require(workout(options(week: 6, done: ["Full body A"], lowEnergy: true).option(.conditioning)?.day))
    #expect(session.title == HyroxCycle.fundamentalsTitle)
}

@Test func easyRunWalksInPhaseOneThenRunsContinuously() throws {
    let done = ["Full body A", HyroxCycle.qualityTitle, HyroxCycle.fundamentalsTitle]
    let walkRun = try #require(workout(options(week: 2, done: done).option(.conditioning)?.day))
    #expect(walkRun.title == HyroxCycle.easyRunTitle)
    #expect(walkRun.exercises.first.map { $0.sets == 7 && $0.volume == .seconds(120) && $0.restSeconds == 90 } == true)
    let continuous = try #require(workout(options(week: 7, done: done).option(.conditioning)?.day))
    #expect(continuous.exercises.first?.sets == 1 && continuous.exercises.first?.name == "Course facile continue")
}

@Test func hyroxStrengthAlternatesAAndBWithTheSled() throws {
    let profile = makeProfile(equipment: .gym)
    #expect(planner.nextWorkout(after: "Full body B", for: profile, on: monday, cycleWeek: hyrox(6)).title == "Full body A")
    #expect(planner.nextWorkout(after: "Full body A", for: profile, on: monday, cycleWeek: hyrox(6)).title == "Full body B")
    let constraints = DayConstraints(lastWorkoutTitle: "Full body B", cycleWeek: hyrox(6), cyclePlan: CycleSessionPlan(sessions: 4, program: .hyrox))
    let session = try #require(workout(planner.trainingDay(for: makeProfile(sessionMinutes: 120, equipment: .gym), on: monday, constraints: constraints)))
    #expect(session.exercises.contains { $0.name == "Poussée de traîneau (20 m)" })
    // 4 séances : pas de séance de fondamentaux, 10 minutes d'ateliers en fin de force.
    #expect(session.exercises.last?.name.hasPrefix("Ateliers") == true)
}

@Test func oneStrengthSessionWhenTheWeekIsShort() {
    // 3 séances : une seule force, déjà faite ; la force serait possible, mais la course passe.
    let options = options(week: 6, done: ["Full body A"], sessions: 3, lastStrength: day(2026, 10, 24))
    #expect(options.recommended == .conditioning)
}
