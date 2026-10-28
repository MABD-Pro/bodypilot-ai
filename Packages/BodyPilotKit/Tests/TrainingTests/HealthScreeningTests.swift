import BodyPilotCore
import Testing
@testable import Training

private let planner = TrainingPlanner(calendar: utc)
private let monday = day(2026, 10, 26)

private func cautious(_ profile: UserProfile, cleared: Bool = false) -> UserProfile {
    var profile = profile
    profile.screening = HealthScreening(answeredAt: monday, yes: [.heartCondition], medicalClearance: cleared)
    return profile
}

@Test func screeningYesSkipsStrengthTestAndLightensSession() throws {
    let profile = cautious(makeProfile(equipment: .gym))
    let result = planner.trainingDay(for: profile, on: monday, constraints: DayConstraints(calibratedLifts: []))
    guard case .workout(let workout) = result.kind else { Issue.record("séance attendue"); return }
    #expect(!workout.isStrengthTest)
    #expect(result.notes.contains(TrainingPlanner.medicalCautionNote))
    #expect(result.notes.contains { $0.contains("avis médical en attente") })
}

@Test func medicalClearanceRestoresStrengthTest() throws {
    let profile = cautious(makeProfile(equipment: .gym), cleared: true)
    let result = planner.trainingDay(for: profile, on: monday, constraints: DayConstraints(calibratedLifts: []))
    guard case .workout(let workout) = result.kind else { Issue.record("séance attendue"); return }
    #expect(workout.isStrengthTest)
    #expect(!result.notes.contains(TrainingPlanner.medicalCautionNote))
}

@Test func screeningYesSkipsCardioTest() {
    let constraints = DayConstraints(cardio: CardioStatus(testDue: true), medicalCaution: true)
    #expect(planner.cardioTest(budget: 45, constraints: constraints) == nil)
}
