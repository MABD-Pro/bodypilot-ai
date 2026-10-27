import BodyPilotCore
import Foundation
import Testing
@testable import Training

private let planner = TrainingPlanner(calendar: utc)
private let monday = day(2026, 10, 26)

private func workout(_ day: TrainingDay) -> Workout? {
    if case .workout(let workout) = day.kind { return workout }
    return nil
}

@Test func theFirstGymSessionTestsSquatBenchAndRow() throws {
    let result = planner.trainingDay(for: makeProfile(equipment: .gym), on: monday, constraints: DayConstraints(calibratedLifts: []))
    let test = try #require(workout(result))
    #expect(test.isStrengthTest)
    #expect(test.title == "Test de force 1/2")
    #expect(test.exercises.map(\.name) == ["Squat à la barre", "Développé couché", "Rowing barre"])
    #expect(test.exercises.allSatisfy { $0.volume == .reps(5) && $0.alternatives.isEmpty })
    #expect(result.estimatedMinutes <= 45)
    #expect(result.notes.contains { $0.contains("Test de force") })
    #expect(TrainingPlanner.isStrengthSession(test.title))
}

@Test func theSecondTestComesOnceTheFirstIsDone() throws {
    let done: Set<String> = ["Squat à la barre", "Développé couché", "Rowing barre"]
    let test = try #require(workout(planner.trainingDay(for: makeProfile(equipment: .gym), on: monday, constraints: DayConstraints(calibratedLifts: done))))
    #expect(test.title == "Test de force 2/2")
    #expect(test.exercises.map(\.name) == ["Soulevé de terre", "Développé militaire", "Tirage vertical lourd"])

    let all = Set(StrengthCalibration.referenceLifts)
    let session = try #require(workout(planner.trainingDay(for: makeProfile(equipment: .gym), on: monday, constraints: DayConstraints(calibratedLifts: all))))
    #expect(!session.isStrengthTest)
    #expect(session.title == "Full body A")
}

@Test func noTestWhenTiredInPainAtHomeOrWithoutCalibration() throws {
    let tired = try #require(workout(planner.trainingDay(for: makeProfile(equipment: .gym), on: monday, constraints: DayConstraints(lowEnergy: true, calibratedLifts: []))))
    #expect(!tired.isStrengthTest)
    let knee = try #require(workout(planner.trainingDay(for: makeProfile(equipment: .gym), on: monday, constraints: DayConstraints(kneePain: true, calibratedLifts: []))))
    #expect(!knee.isStrengthTest)
    let home = try #require(workout(planner.trainingDay(for: makeProfile(equipment: .bodyweight), on: monday, constraints: DayConstraints(calibratedLifts: []))))
    #expect(!home.isStrengthTest)
    let unknown = try #require(workout(planner.trainingDay(for: makeProfile(equipment: .gym), on: monday, constraints: DayConstraints())))
    #expect(!unknown.isStrengthTest)
    // Le lendemain d'un test, les muscles récupèrent : pas de second test.
    let sunday = try #require(utc.date(byAdding: .day, value: -1, to: monday))
    let recovery = try #require(workout(planner.trainingDay(for: makeProfile(equipment: .gym), on: monday, constraints: DayConstraints(lastStrengthDay: sunday, calibratedLifts: []))))
    #expect(!recovery.hasStrength)
}

@Test func aShortSessionTestsFewerLifts() throws {
    var profile = makeProfile(equipment: .gym)
    profile.sessionMinutes = 30
    let test = try #require(workout(planner.trainingDay(for: profile, on: monday, constraints: DayConstraints(calibratedLifts: []))))
    #expect(test.isStrengthTest)
    #expect(test.exercises.count < 3)
    #expect(test.estimatedMinutes <= 30)
}

@Test func theRampClimbsToTheFirstAttempt() {
    let ramp = StrengthCalibration.ramp(for: "Squat à la barre", firstAttemptKg: 60)
    #expect(ramp == [RampStep(reps: 10, kg: 30), RampStep(reps: 5, kg: 42.5), RampStep(reps: 3, kg: 50), RampStep(reps: 5, kg: 60)])
    // Jamais sous la barre vide.
    #expect(StrengthCalibration.ramp(for: "Développé militaire", firstAttemptKg: 25).first?.kg == 20)
    #expect(StrengthCalibration.attemptIncrement(for: "Squat à la barre", from: 60) == 5)
    #expect(StrengthCalibration.attemptIncrement(for: "Soulevé de terre", from: 140) == 15)
    #expect(StrengthCalibration.attemptIncrement(for: "Développé couché", from: 60) == 2.5)
}

@Test func workingLoadsComeFromTheTest() {
    // 100 × 5 au test ≈ 116,7 kg de 1RM ; 6 répétitions avec 2 en réserve ≈ 92 kg, arrondi à 90.
    let test = LiftEntry(exercise: "Squat à la barre", date: day(2026, 10, 19), kg: 100, reps: 5, isTest: true)
    #expect(StrengthProgress.target(for: "Squat à la barre", plannedReps: 6, history: [test]) == LiftTarget(kg: 90, reps: 6, isIncrease: false))
    // Exercice jamais noté : déduit du mouvement de référence.
    let goblet = StrengthProgress.target(for: "Squat goblet lourd", plannedReps: 6, history: [test])
    #expect(goblet?.kg == 30)
    #expect(StrengthProgress.target(for: "Pompes", plannedReps: 12, history: [test]) == nil)
    // Une série notée ensuite reprend la main.
    let session = LiftEntry(exercise: "Squat à la barre", date: day(2026, 10, 22), kg: 90, reps: 7)
    #expect(StrengthProgress.target(for: "Squat à la barre", plannedReps: 6, history: [test, session])?.kg == 95)
}
