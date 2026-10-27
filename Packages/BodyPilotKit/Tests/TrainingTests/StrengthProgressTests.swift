import BodyPilotCore
import Testing
@testable import Training

private func lift(_ exercise: String = "Squat à la barre", _ kg: Double?, _ reps: Int, on dayOfMonth: Int) -> LiftEntry {
    LiftEntry(exercise: exercise, date: day(2026, 10, dayOfMonth), kg: kg, reps: reps)
}

@Test func oneRepMaxFollowsEpley() {
    #expect(StrengthProgress.estimatedOneRepMax(kg: 100, reps: 1) == 100)
    #expect(abs(StrengthProgress.estimatedOneRepMax(kg: 90, reps: 6) - 108) < 0.001)
    // Au-delà de 12 répétitions, l'estimation est plafonnée.
    #expect(StrengthProgress.estimatedOneRepMax(kg: 50, reps: 20) == StrengthProgress.estimatedOneRepMax(kg: 50, reps: 12))
}

@Test func recordIsTheBestEstimatedSet() {
    let history = [lift(100, 3, on: 5), lift(90, 8, on: 12), lift(80, 5, on: 19), lift("Développé couché", 70, 6, on: 19)]
    let record = StrengthProgress.record(for: "Squat à la barre", in: history)
    // 90 × 8 ≈ 114 kg estimés, mieux que 100 × 3 = 110.
    #expect(record?.entry == history[1])
    #expect(StrengthProgress.records(in: history).count == 2)
}

@Test func weightedSetsOutrankBodyweight() {
    let history = [lift("Squats bulgares", nil, 20, on: 5), lift("Squats bulgares", 8, 10, on: 12)]
    #expect(StrengthProgress.record(for: "Squats bulgares", in: history)?.entry.kg == 8)
}

@Test func aRecordMustBeatEveryEarlierSet() {
    let history = [lift(80, 6, on: 5), lift(82.5, 6, on: 12)]
    #expect(StrengthProgress.isRecord(lift(85, 6, on: 19), previous: history))
    #expect(!StrengthProgress.isRecord(lift(82.5, 6, on: 19), previous: history))
    // Première série notée : rien à battre.
    #expect(!StrengthProgress.isRecord(lift("Rowing barre", 60, 8, on: 19), previous: history))
    // Les séries du même jour ou d'après ne comptent pas.
    #expect(StrengthProgress.isRecord(lift(85, 6, on: 19), previous: history + [lift(90, 6, on: 19)]))
}

@Test func loadGoesUpWhenTheRepsExceedThePlan() {
    let target = StrengthProgress.target(for: "Squat à la barre", plannedReps: 6, history: [lift(100, 7, on: 19)])
    #expect(target == LiftTarget(kg: 105, reps: 6, isIncrease: true))
}

@Test func loadStaysUntilThePlannedRepsAreBeaten() {
    #expect(StrengthProgress.target(for: "Squat à la barre", plannedReps: 6, history: [lift(100, 6, on: 19)]) == LiftTarget(kg: 100, reps: 6, isIncrease: false))
    #expect(StrengthProgress.target(for: "Squat à la barre", plannedReps: 6, history: [lift(100, 4, on: 19)]) == LiftTarget(kg: 100, reps: 6, isIncrease: false))
    #expect(StrengthProgress.target(for: "Squat à la barre", plannedReps: 6, history: []) == nil)
}

@Test func incrementsStayBetweenTwoAndTenPercentOnUsualLoads() {
    #expect(StrengthProgress.increment(from: 40) == 2.5)
    #expect(StrengthProgress.increment(from: 100) == 5)
    #expect(StrengthProgress.increment(from: 140) == 7.5)
    #expect(StrengthProgress.increment(from: 16) == 1)
}

@Test func bodyweightAimsForOneMoreRep() {
    let beat = StrengthProgress.target(for: "Pompes", plannedReps: 12, history: [lift("Pompes", nil, 14, on: 19)])
    #expect(beat == LiftTarget(kg: nil, reps: 15, isIncrease: true))
    let short = StrengthProgress.target(for: "Pompes", plannedReps: 12, history: [lift("Pompes", nil, 9, on: 19)])
    #expect(short == LiftTarget(kg: nil, reps: 12, isIncrease: false))
}

@Test func labelsReadNaturally() {
    #expect(StrengthProgress.label(kg: 82.5, reps: 6) == "82,5 kg × 6")
    #expect(StrengthProgress.label(kg: 80, reps: 5) == "80 kg × 5")
    #expect(StrengthProgress.label(kg: nil, reps: 15) == "15 rép.")
}
