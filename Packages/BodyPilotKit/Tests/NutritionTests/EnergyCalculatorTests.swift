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
    // BMR 1855 × 1,4 (vie quotidienne, hors sport) = 2597 ; déficit de 20 % (519) → 2080.
    #expect(targets.maintenanceKcal.rounded() == 2597)
    #expect(targets.macros.kcal == 2080)
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
    // IMC 37 → poids de référence 30 × 1,8² = 97,2 kg → 194 g.
    #expect(targets.macros.proteinG == 194)
}

@Test func proteinNeverDropsWhenWeightRises() {
    // Autour de l'IMC 30 (97,2 kg à 1,80 m), un kilo de plus ne baisse jamais l'objectif.
    let proteins = stride(from: 95.0, through: 100, by: 0.2).map {
        calculator.targets(for: makeProfile(weightKg: $0), currentWeightKg: $0, on: today).macros.proteinG
    }
    #expect(zip(proteins, proteins.dropFirst()).allSatisfy { $0 <= $1 })
}

@Test func weeklyAdjustmentShiftsTargetAndIsExplained() {
    var profile = makeProfile()
    profile.calorieAdjustmentKcal = -150
    let targets = calculator.targets(for: profile, currentWeightKg: 90, on: today)
    #expect(targets.macros.kcal == 1930)
    #expect(targets.rationale.contains("-150 kcal"))
}

@Test func weeklyAdjustmentNeverBreaksSafetyLimits() {
    // Perte de gras : jamais au-dessus de la maintenance (2597), jamais sous le plancher (BMR 1855).
    var profile = makeProfile()
    profile.calorieAdjustmentKcal = 900
    #expect(calculator.targets(for: profile, currentWeightKg: 90, on: today).macros.kcal == 2600)
    profile.calorieAdjustmentKcal = -900
    #expect(calculator.targets(for: profile, currentWeightKg: 90, on: today).macros.kcal == 1860)
}

@Test func recompositionDeficitShrinksNearTarget() {
    #expect(EnergyCalculator.recompositionDeficitRatio(currentKg: 95, targetKg: 80) == SafetyLimits.deficitRatio)
    #expect(abs(EnergyCalculator.recompositionDeficitRatio(currentKg: 85, targetKg: 80) - 0.10) < 0.0001)
    #expect(EnergyCalculator.recompositionDeficitRatio(currentKg: 81, targetKg: 80) == 0.05)
    #expect(EnergyCalculator.recompositionDeficitRatio(currentKg: 80, targetKg: 80) == 0)
    #expect(EnergyCalculator.recompositionDeficitRatio(currentKg: 80, targetKg: nil) == 0.10)
}

@Test func recompositionKeepsHighProteinAndNoSurplus() {
    var profile = makeProfile(targetWeightKg: 85)
    profile.goal = .recomposition
    let targets = calculator.targets(for: profile, currentWeightKg: 90, on: today)
    // 5 kg d'écart → 10 % de déficit sur 2597 → ≈ 2340.
    #expect(abs(targets.macros.kcal - 2340) <= 10)
    #expect(targets.macros.proteinG == 180)

    profile.targetWeightKg = 90
    let atTarget = calculator.targets(for: profile, currentWeightKg: 90, on: today)
    #expect(abs(atTarget.macros.kcal - atTarget.maintenanceKcal) <= 10)

    profile.calorieAdjustmentKcal = 450
    let adjusted = calculator.targets(for: profile, currentWeightKg: 90, on: today)
    #expect(adjusted.macros.kcal <= adjusted.maintenanceKcal + 10)
}

@Test func sessionsDoneAddToDailyExpenditure() {
    var profile = makeProfile(targetWeightKg: 85)
    profile.goal = .recomposition
    let rest = calculator.targets(for: profile, currentWeightKg: 90, on: today)
    let training = calculator.targets(for: profile, currentWeightKg: 90, exerciseKcalPerDay: 300, on: today)
    // La dépense des séances s'ajoute à la vie quotidienne, le déficit reste proportionnel.
    #expect(abs(training.maintenanceKcal - rest.maintenanceKcal - 300) < 0.01)
    #expect(training.macros.kcal > rest.macros.kcal + 250)
    #expect(training.rationale.contains("dont 300 kcal pour tes séances"))
    #expect(training.macros.proteinG == rest.macros.proteinG)
}

@Test func pregnancyMeansNoDeficitEvenAfterCheckIns() {
    var profile = makeProfile(sex: .female, goal: .recomposition)
    profile.screening = HealthScreening(answeredAt: today, situations: [.pregnancy])
    profile.calorieAdjustmentKcal = -300
    let targets = calculator.targets(for: profile, currentWeightKg: 90, on: today)
    #expect(targets.macros.kcal == (targets.maintenanceKcal / 10).rounded() * 10)
    #expect(targets.rationale.contains("grossesse"))
}

@Test func minorsGetNoDeficit() {
    let teen = UserProfile(
        sex: .male, birthDate: day(2010, 1, 1), heightCm: 175, startWeightKg: 80, targetWeightKg: 70,
        activity: .light, goal: .recomposition, trainingDaysPerWeek: 3, sessionMinutes: 45, equipment: .bodyweight
    )
    let targets = calculator.targets(for: teen, currentWeightKg: 80, on: today)
    #expect(targets.macros.kcal == (targets.maintenanceKcal / 10).rounded() * 10)
    #expect(targets.rationale.contains("moins de 18 ans"))
}

@Test func measuredStepsReplaceDeclaredActivity() {
    var profile = makeProfile()
    profile.averageDailySteps = 4_200
    let targets = calculator.targets(for: profile, currentWeightKg: 90, on: today)
    // BMR 1855 × 1,2 (moins de 5 000 pas) au lieu de 1,4 déclaré.
    #expect(targets.maintenanceKcal.rounded() == 2226)
    #expect(targets.rationale.contains("4\u{202F}200"))
}
