import BodyPilotCore
import Testing
@testable import Training

private func lift(_ kg: Double?, _ reps: Int, on dayOfMonth: Int, _ exercise: String = "Squat à la barre") -> LiftEntry {
    LiftEntry(exercise: exercise, date: day(2026, 10, dayOfMonth), kg: kg, reps: reps)
}

@Test func oneRepMaxFollowsEpley() {
    #expect(StrengthProgress.estimatedOneRepMax(kg: 100, reps: 1) == 100)
    #expect(abs(StrengthProgress.estimatedOneRepMax(kg: 90, reps: 6) - 108) < 0.001)
    // Au-delà de 12 répétitions, l'estimation est plafonnée.
    #expect(StrengthProgress.estimatedOneRepMax(kg: 50, reps: 20) == StrengthProgress.estimatedOneRepMax(kg: 50, reps: 12))
}

@Test func recordIsTheBestEstimatedSet() {
    let history = [lift(100, 3, on: 5), lift(90, 8, on: 12), lift(80, 5, on: 19), lift(70, 6, on: 19, "Développé couché")]
    let record = StrengthProgress.record(for: "Squat à la barre", in: history)
    // 90 × 8 ≈ 114 kg estimés, mieux que 100 × 3 = 110.
    #expect(record?.entry == history[1])
    #expect(StrengthProgress.records(in: history).count == 2)
}

@Test func weightedSetsOutrankBodyweight() {
    let history = [lift(nil, 20, on: 5, "Squats bulgares"), lift(8, 10, on: 12, "Squats bulgares")]
    #expect(StrengthProgress.record(for: "Squats bulgares", in: history)?.entry.kg == 8)
}

@Test func aRecordMustBeatEveryEarlierSet() {
    let history = [lift(80, 6, on: 5), lift(82.5, 6, on: 12)]
    #expect(StrengthProgress.isRecord(lift(85, 6, on: 19), previous: history))
    #expect(!StrengthProgress.isRecord(lift(82.5, 6, on: 19), previous: history))
    // Première série notée : rien à battre.
    #expect(!StrengthProgress.isRecord(lift(60, 8, on: 19, "Rowing barre"), previous: history))
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
    let beat = StrengthProgress.target(for: "Pompes", plannedReps: 12, history: [lift(nil, 14, on: 19, "Pompes")])
    #expect(beat == LiftTarget(kg: nil, reps: 15, isIncrease: true))
    let short = StrengthProgress.target(for: "Pompes", plannedReps: 12, history: [lift(nil, 9, on: 19, "Pompes")])
    #expect(short == LiftTarget(kg: nil, reps: 12, isIncrease: false))
}

@Test func labelsReadNaturally() {
    #expect(StrengthProgress.label(kg: 82.5, reps: 6) == "82,5 kg × 6")
    #expect(StrengthProgress.label(kg: 80, reps: 5) == "80 kg × 5")
    #expect(StrengthProgress.label(kg: nil, reps: 15) == "15 rép.")
}

@Test func strengthHoldsThreeWeeksThenSlowlyDrops() {
    #expect(StrengthProgress.retention(afterDays: 21) == 1)
    #expect(StrengthProgress.retention(afterDays: 30) == 0.95)
    #expect(StrengthProgress.retention(afterDays: 60) == 0.9)
    #expect(StrengthProgress.retention(afterDays: 120) == 0.85)
}

@Test func loadsDropAfterABreak() {
    // 100 × 6 il y a 56 jours : 120 kg de 1RM × 0,9 = 108, soit 85 kg pour 6 répétitions.
    let old = LiftEntry(exercise: "Squat à la barre", date: day(2026, 9, 1), kg: 100, reps: 6)
    let target = StrengthProgress.target(for: "Squat à la barre", plannedReps: 6, history: [old], on: day(2026, 10, 27), calendar: utc)
    #expect(target == LiftTarget(kg: 85, reps: 6, isIncrease: false))
    #expect(StrengthProgress.comebackNote(pauseDays: 56)?.contains("90 %") == true)
    #expect(StrengthProgress.comebackNote(pauseDays: 10) == nil)
}

@Test func shortBreakKeepsTheProgression() {
    let target = StrengthProgress.target(for: "Squat à la barre", plannedReps: 6, history: [lift(100, 7, on: 17)], on: day(2026, 10, 27), calendar: utc)
    #expect(target == LiftTarget(kg: 105, reps: 6, isIncrease: true))
}

@Test func recentMaxLiftsTheLoadAfterAWeakSession() {
    // Max de 5 semaines (102,5 × 6, 123 kg × 0,95 ≈ 117) au-dessus de la dernière série (80 × 6).
    let max = LiftEntry(exercise: "Squat à la barre", date: day(2026, 9, 15), kg: 102.5, reps: 6)
    let target = StrengthProgress.target(for: "Squat à la barre", plannedReps: 6, history: [max, lift(80, 6, on: 20)], on: day(2026, 10, 22), calendar: utc)
    #expect(target == LiftTarget(kg: 90, reps: 6, isIncrease: true))
}

@Test func veryOldMaxCountsLessThanRecentSets() {
    // Max d'il y a près de 4 mois : 120 × 0,85 = 102 kg ; la série récente (80 × 6) garde la main.
    let max = LiftEntry(exercise: "Squat à la barre", date: day(2026, 7, 1), kg: 100, reps: 6)
    let target = StrengthProgress.target(for: "Squat à la barre", plannedReps: 6, history: [max, lift(80, 6, on: 20)], on: day(2026, 10, 22), calendar: utc)
    #expect(target == LiftTarget(kg: 80, reps: 6, isIncrease: false))
}

@Test func strengthSessionsOutsideTheAppCountAsTraining() {
    let old = LiftEntry(exercise: "Squat à la barre", date: day(2026, 9, 1), kg: 100, reps: 6)
    #expect(StrengthProgress.pauseDays(history: [old], lastStrengthDay: day(2026, 10, 20), on: day(2026, 10, 27), calendar: utc) == 7)
    #expect(StrengthProgress.pauseDays(history: [old], lastStrengthDay: nil, on: day(2026, 10, 27), calendar: utc) == 56)
}
