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

@Test func cycleWeeksCountFromTheStartDay() throws {
    let cycle = TrainingCycle(program: .crossfit, startDate: day(2026, 11, 2))
    #expect(cycle.week(on: day(2026, 11, 1), calendar: utc) == nil)
    #expect(cycle.week(on: day(2026, 11, 8), calendar: utc)?.number == 1)
    let fourth = try #require(cycle.week(on: day(2026, 11, 23), calendar: utc))
    #expect(fourth.number == 4 && fourth.isDeload && fourth.phase == 1)
    let fifth = try #require(cycle.week(on: day(2026, 11, 30), calendar: utc))
    #expect(fifth.phase == 2 && fifth.weekInPhase == 1 && !fifth.isDeload)
    #expect(cycle.week(on: day(2027, 1, 24), calendar: utc)?.number == 12)
    #expect(cycle.week(on: day(2027, 1, 25), calendar: utc) == nil)
}

@Test func cycleSetsMainLiftsByWeek() throws {
    let profile = makeProfile(sessionMinutes: 120, equipment: .gym)
    let week3 = DayConstraints(cycleWeek: CycleWeek(program: .crossfit, number: 3))
    let heavy = try #require(workout(planner.trainingDay(for: profile, on: monday, constraints: week3)))
    let main = heavy.exercises.filter { $0.priority == 1 }
    #expect(!main.isEmpty)
    #expect(main.allSatisfy { $0.sets == 4 && $0.volume == .reps(5) && $0.percentOfMax == 0.82 })

    let deload = DayConstraints(cycleWeek: CycleWeek(program: .crossfit, number: 8))
    let light = try #require(workout(planner.trainingDay(for: profile, on: monday, constraints: deload)))
    #expect(light.exercises.filter { $0.priority == 1 }.allSatisfy { $0.sets == 2 && $0.percentOfMax == 0.70 })
    #expect(light.exercises.filter { $0.priority == 2 }.allSatisfy { $0.sets == 2 })
    let notes = planner.trainingDay(for: profile, on: monday, constraints: deload).notes
    #expect(notes.first?.hasPrefix("Cycle CrossFit · semaine 8 sur 12 (allégée)") == true)
}

@Test func cycleWithoutLoadsKeepsBodyweightTargets() throws {
    let week = DayConstraints(cycleWeek: CycleWeek(program: .crossfit, number: 1))
    let session = try #require(workout(planner.trainingDay(for: makeProfile(sessionMinutes: 120), on: monday, constraints: week)))
    #expect(session.exercises.allSatisfy { $0.percentOfMax == nil })
}

@Test func cycleLoadIsAShareOfTheWeightedMax() throws {
    // 100 kg × 5 : 1RM estimé 116,7 kg ; 82 % → 95,6, arrondi aux disques en dessous : 95 kg.
    let history = [LiftEntry(exercise: "Squat à la barre", date: day(2026, 10, 20), kg: 100, reps: 5)]
    let target = try #require(StrengthProgress.target(for: "Squat à la barre", plannedReps: 5, percentOfMax: 0.82, history: history, on: day(2026, 10, 23), calendar: utc))
    #expect(target.kg == 95)
    #expect(!target.isIncrease)
    let deload = try #require(StrengthProgress.target(for: "Squat à la barre", plannedReps: 5, percentOfMax: 0.70, history: history, on: day(2026, 10, 23), calendar: utc))
    #expect(deload.kg == 80)
}
