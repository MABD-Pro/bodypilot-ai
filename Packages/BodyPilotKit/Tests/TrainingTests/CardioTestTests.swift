import BodyPilotCore
import Foundation
import Testing
@testable import Training

private let planner = TrainingPlanner(calendar: utc)
private let monday = day(2026, 10, 26)
private let sunday = day(2026, 10, 25)

@Test func rockportEstimateFollowsTheEquation() {
    // 80 kg, 40 ans, homme, 15 min, 140 bpm : 132,853 − 13,56 − 15,51 + 6,315 − 48,97 − 21,91 ≈ 39,2.
    #expect(CardioTest.vo2max(minutes: 15, heartRate: 140, weightKg: 80, age: 40, sex: .male) == 39.2)
    // Plus rapide ou pouls plus bas : meilleure forme.
    #expect(CardioTest.vo2max(minutes: 13, heartRate: 140, weightKg: 80, age: 40, sex: .male) > 39.2)
    #expect(CardioTest.vo2max(minutes: 15, heartRate: 120, weightKg: 80, age: 40, sex: .male) > 39.2)
}

@Test func moderateZoneUsesHeartRateReserveWhenRestingRateIsKnown() {
    // 40 ans : maximum 180. Repos 60 : réserve 120, 40 à 59 % → 108 à 131.
    #expect(CardioTest.moderateZone(age: 40, restingHeartRate: 60) == 108...131)
    // Sans pouls au repos : 64 à 76 % du maximum → 115 à 137.
    #expect(CardioTest.moderateZone(age: 40, restingHeartRate: nil) == 115...137)
}

@Test func testIsDueWithoutARecentMeasure() {
    #expect(CardioTest.isDue(lastMeasured: nil, on: monday, calendar: utc))
    #expect(!CardioTest.isDue(lastMeasured: utc.date(byAdding: .day, value: -30, to: monday), on: monday, calendar: utc))
    #expect(CardioTest.isDue(lastMeasured: utc.date(byAdding: .day, value: -56, to: monday), on: monday, calendar: utc))
}

@Test func aDueTestReplacesTheCardioOfTheDay() throws {
    let due = DayConstraints(lastStrengthDay: sunday, cardio: CardioStatus(testDue: true))
    let result = planner.options(for: makeProfile(), on: monday, constraints: due)
    #expect(result.recommended == .conditioning)
    #expect(result.reason.contains("test de marche"))
    guard case .workout(let test) = result.option(.conditioning)?.day.kind else { Issue.record("Test attendu"); return }
    #expect(test.isCardioTest)
    #expect(test.title == CardioTest.title)
    // Un jour de force, la force reste recommandée ; le test attend le cardio.
    let strengthDay = planner.options(for: makeProfile(), on: monday, constraints: DayConstraints(cardio: CardioStatus(testDue: true)))
    #expect(strengthDay.recommended == .strength)
}

@Test func theCardioTestWaitsForAGoodDay() {
    func isTest(_ constraints: DayConstraints) -> Bool {
        guard case .workout(let workout) = planner.trainingDay(for: makeProfile(), on: monday, constraints: constraints).kind else { return false }
        return workout.isCardioTest
    }
    let due = CardioStatus(testDue: true)
    #expect(isTest(DayConstraints(lastStrengthDay: sunday, cardio: due)))
    #expect(!isTest(DayConstraints(lowEnergy: true, lastStrengthDay: sunday, cardio: due)))
    #expect(!isTest(DayConstraints(lastStrengthDay: sunday, sore: true, choice: .conditioning, cardio: due)))
    #expect(!isTest(DayConstraints(lastStrengthDay: sunday, sleepHours: 5, choice: .conditioning, cardio: due)))
    #expect(!isTest(DayConstraints(availableMinutes: 20, lastStrengthDay: sunday, cardio: due)))
    #expect(!isTest(DayConstraints(lastStrengthDay: sunday)))
}

@Test func knownZoneGoesIntoTheCardioCue() throws {
    let constraints = DayConstraints(lastStrengthDay: sunday, cardio: CardioStatus(moderateHeartRate: 108...131))
    guard case .workout(let workout) = planner.trainingDay(for: makeProfile(), on: monday, constraints: constraints).kind else { Issue.record("Cardio attendu"); return }
    #expect(workout.intensityCue.contains("108 et 131"))
}
