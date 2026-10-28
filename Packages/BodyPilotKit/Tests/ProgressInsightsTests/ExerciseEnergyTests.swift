import BodyPilotCore
import Foundation
import Testing
@testable import ProgressInsights

private let today = day(2026, 10, 26)

private func daysAgo(_ count: Int) -> Date {
    utc.date(byAdding: .day, value: -count, to: today)!
}

@Test func healthWorkoutsCountTheirActiveCalories() {
    let samples = (1...7).map { ActivitySample(id: "\($0)", kind: .strength, start: daysAgo($0 * 2), minutes: 60, kcal: 400) }
    // 7 séances de 400 kcal sur 14 jours : 200 kcal par jour.
    #expect(ExerciseEnergy.dailyAverage(samples: samples, completed: [], sessionMinutes: 45, weightKg: 90, on: today, calendar: utc) == 200)
}

@Test func tickedSessionsWithoutHealthAreEstimated() {
    // Force 45 min à 90 kg : (5 − 1) × 90 × 0,75 = 270 kcal ; 14 séances → 270 par jour.
    let completed = (1...14).map { (day: daysAgo($0), title: Optional("Full body A")) }
    #expect(ExerciseEnergy.dailyAverage(samples: [], completed: completed, sessionMinutes: 45, weightKg: 90, on: today, calendar: utc) == 270)
}

@Test func aDayIsNeverCountedTwice() {
    let sample = ActivitySample(id: "w", kind: .strength, start: daysAgo(1), minutes: 50, kcal: 350)
    let completed = [(day: daysAgo(1), title: Optional("Full body A"))]
    // La séance cochée et l'enregistrement de la Watch le même jour : seulement la Watch.
    #expect(ExerciseEnergy.dailyAverage(samples: [sample], completed: completed, sessionMinutes: 45, weightKg: 90, on: today, calendar: utc) == 30)
}

@Test func onlyThePastFourteenDaysCountAndTheTotalIsCapped() {
    let old = ActivitySample(id: "old", kind: .running, start: daysAgo(15), minutes: 60, kcal: 700)
    let todays = ActivitySample(id: "today", kind: .running, start: today, minutes: 60, kcal: 700)
    #expect(ExerciseEnergy.dailyAverage(samples: [old, todays], completed: [], sessionMinutes: 45, weightKg: 90, on: today, calendar: utc) == 0)
    let huge = (1...14).map { ActivitySample(id: "\($0)", kind: .running, start: daysAgo($0), minutes: 120, kcal: 1200) }
    #expect(ExerciseEnergy.dailyAverage(samples: huge, completed: [], sessionMinutes: 45, weightKg: 90, on: today, calendar: utc) == ExerciseEnergy.maxDailyKcal)
}
