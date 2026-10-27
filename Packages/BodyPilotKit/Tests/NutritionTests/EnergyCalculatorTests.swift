import BodyPilotCore
import Testing
@testable import Nutrition

private let calculator = EnergyCalculator(calendar: utc)
private let today = day(2026, 10, 27)

@Test func basalMetabolicRateFollowsMifflinStJeor() {
    #expect(calculator.basalMetabolicRate(sex: .male, weightKg: 90, heightCm: 180, age: 35) == 1855)
    #expect(calculator.basalMetabolicRate(sex: .female, weightKg: 60, heightCm: 165, age: 30) == 1320.25)
}

@Test func fatLossAppliesCappedDeficit() {
    let targets = calculator.targets(for: makeProfile(), currentWeightKg: 90, on: today)
    // BMR 1855 × 1,55 = 2875 ; déficit plafonné à 575 (20 %) → 2300.
    #expect(targets.maintenanceKcal.rounded() == 2875)
    #expect(targets.macros.kcal == 2300)
    #expect(targets.macros.proteinG == 180)
}

@Test func caloriesNeverGoBelowSafetyFloor() {
    let small = UserProfile(
        sex: .female, birthDate: day(1966, 1, 1), heightCm: 150, startWeightKg: 48,
        activity: .sedentary, goal: .loseFat, trainingDaysPerWeek: 2, sessionMinutes: 30, equipment: .bodyweight
    )
    let targets = calculator.targets(for: small, currentWeightKg: 48, on: today)
    let bmr = calculator.basalMetabolicRate(sex: .female, weightKg: 48, heightCm: 150, age: 60)
    #expect(targets.macros.kcal >= max(bmr, SafetyLimits.minimumKcal(for: .female)) - 5)
}

@Test func macrosAddUpToCalories() {
    for goal in Goal.allCases {
        let targets = calculator.targets(for: makeProfile(goal: goal), currentWeightKg: 90, on: today)
        let m = targets.macros
        #expect(abs(m.proteinG * 4 + m.carbsG * 4 + m.fatG * 9 - m.kcal) < 15)
    }
}

@Test func proteinUsesAdjustedWeightAboveBMI30() {
    let targets = calculator.targets(for: makeProfile(weightKg: 120), currentWeightKg: 120, on: today)
    // IMC 37 → poids de référence 27 × 1,8² = 87,5 kg → 175 g.
    #expect(targets.macros.proteinG == 175)
}
