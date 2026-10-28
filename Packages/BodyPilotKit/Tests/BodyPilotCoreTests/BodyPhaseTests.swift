import Foundation
import Testing
@testable import BodyPilotCore

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()
private let today = utc.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 9))!

private func profile(weight: Double, target: Double?, height: Double = 180, sex: BiologicalSex = .male) -> UserProfile {
    UserProfile(
        sex: sex, birthDate: utc.date(from: DateComponents(year: 1991, month: 1, day: 1))!, heightCm: height,
        startWeightKg: weight, targetWeightKg: target, activity: .light, goal: .recomposition,
        trainingDaysPerWeek: 3, sessionMinutes: 45, equipment: .gym
    )
}

private func phase(_ profile: UserProfile, weight: Double, waist: Double? = nil, fat: Double? = nil) -> BodyPhase {
    BodyPhase.resolve(for: profile, currentWeightKg: weight, waistCm: waist, fatPercent: fat, on: today, calendar: utc)
}

@Test func targetDecidesThePhase() {
    #expect(phase(profile(weight: 90, target: 80), weight: 90) == .fatLoss)
    #expect(phase(profile(weight: 70, target: 70.3), weight: 70) == .maintenance)
    #expect(phase(profile(weight: 64, target: 70), weight: 64) == .leanGain)
}

@Test func underweightNeverGetsADeficit() {
    // 58 kg pour 1,80 m : IMC 17,9, même avec un poids visé plus bas.
    #expect(phase(profile(weight: 58, target: 55), weight: 58) == .leanGain)
}

@Test func noDeficitSituationsStayAtMaintenance() {
    var pregnant = profile(weight: 80, target: 65, height: 165, sex: .female)
    pregnant.screening = HealthScreening(answeredAt: today, situations: [.pregnancy])
    #expect(phase(pregnant, weight: 80) == .maintenance)
}

@Test func withoutTargetMeasuresDecide() {
    #expect(phase(profile(weight: 80, target: nil), weight: 80, waist: 92) == .fatLoss)
    #expect(phase(profile(weight: 80, target: nil), weight: 80, waist: 84) == .maintenance)
    #expect(phase(profile(weight: 80, target: nil), weight: 80, fat: 27) == .fatLoss)
    #expect(phase(profile(weight: 85, target: nil), weight: 85) == .fatLoss)
    #expect(phase(profile(weight: 75, target: nil), weight: 75) == .maintenance)
}

@Test func phasesMapToCoachGoals() {
    #expect(BodyPhase.fatLoss.goal == .recomposition)
    #expect(BodyPhase.maintenance.goal == .maintain)
    #expect(BodyPhase.leanGain.goal == .buildMuscle)
}

@Test func maintenanceWeekComesAfterTwelveWeeksOfDeficit() {
    let start = utc.date(byAdding: .day, value: -84, to: today)!
    #expect(MaintenanceWeek.isDue(deficitSince: start, dismissedAt: nil, on: today, calendar: utc))
    #expect(!MaintenanceWeek.isDue(deficitSince: utc.date(byAdding: .day, value: 1, to: start)!, dismissedAt: nil, on: today, calendar: utc))
    // « Pas maintenant » : proposée de nouveau 4 semaines plus tard.
    let dismissed = utc.date(byAdding: .day, value: -27, to: today)!
    #expect(!MaintenanceWeek.isDue(deficitSince: start, dismissedAt: dismissed, on: today, calendar: utc))
    #expect(MaintenanceWeek.isDue(deficitSince: start, dismissedAt: utc.date(byAdding: .day, value: -28, to: today)!, on: today, calendar: utc))
}

@Test func maintenanceWeekHoldsTheDeficit() {
    var onBreak = profile(weight: 90, target: 80)
    onBreak.maintenanceWeekUntil = utc.date(byAdding: .day, value: 3, to: today)
    #expect(phase(onBreak, weight: 90) == .maintenance)
    #expect(BodyPhase.maintenance.reason(for: onBreak, currentWeightKg: 90, on: today).contains("semaine à l'équilibre"))
    onBreak.maintenanceWeekUntil = today
    #expect(phase(onBreak, weight: 90) == .fatLoss)
}
