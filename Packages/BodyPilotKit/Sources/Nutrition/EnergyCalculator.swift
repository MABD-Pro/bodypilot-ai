import BodyPilotCore
import Foundation

/// Calcul déterministe des besoins : Mifflin-St Jeor, facteur d'activité, ajustement à l'objectif.
public struct EnergyCalculator: Sendable {
    public var calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// Métabolisme de base (kcal/jour), équation de Mifflin-St Jeor.
    public func basalMetabolicRate(sex: BiologicalSex, weightKg: Double, heightCm: Double, age: Int) -> Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        return sex == .male ? base + 5 : base - 161
    }

    public func targets(for profile: UserProfile, currentWeightKg: Double, on date: Date) -> NutritionTargets {
        let age = profile.age(on: date, calendar: calendar)
        let bmr = basalMetabolicRate(sex: profile.sex, weightKg: currentWeightKg, heightCm: profile.heightCm, age: age)
        let maintenance = bmr * profile.activity.factor

        var kcal: Double
        let explanation: String
        switch profile.goal {
        case .loseFat:
            let deficit = min(maintenance * SafetyLimits.deficitRatio, SafetyLimits.maxDeficitKcal)
            let floor = max(bmr, SafetyLimits.minimumKcal(for: profile.sex))
            kcal = max(maintenance - deficit, floor)
            if kcal > maintenance - deficit {
                explanation = "Dépense estimée \(maintenance.frenchInteger) kcal. Déficit limité pour ne pas descendre sous \(floor.frenchInteger) kcal, le minimum sûr pour toi."
            } else {
                explanation = "Dépense estimée \(maintenance.frenchInteger) kcal, moins \(deficit.frenchInteger) kcal pour perdre du gras sans sacrifier le muscle."
            }
        case .maintain:
            kcal = maintenance
            explanation = "Dépense estimée \(maintenance.frenchInteger) kcal : on vise l'équilibre."
        case .buildMuscle:
            let surplus = min(maintenance * SafetyLimits.surplusRatio, SafetyLimits.maxSurplusKcal)
            kcal = maintenance + surplus
            explanation = "Dépense estimée \(maintenance.frenchInteger) kcal, plus \(surplus.frenchInteger) kcal pour construire du muscle en limitant le gras."
        }
        kcal = (kcal / 10).rounded() * 10

        let proteinReferenceKg = proteinReferenceWeight(weightKg: currentWeightKg, heightCm: profile.heightCm)
        let protein = (proteinReferenceKg * proteinPerKg(for: profile.goal)).rounded()
        let fat = (kcal * SafetyLimits.fatShare / 9).rounded()
        let carbs = max(((kcal - protein * 4 - fat * 9) / 4).rounded(), 0)

        return NutritionTargets(
            macros: Macros(kcal: kcal, proteinG: protein, carbsG: carbs, fatG: fat),
            maintenanceKcal: maintenance,
            rationale: explanation
        )
    }

    private func proteinPerKg(for goal: Goal) -> Double {
        switch goal {
        case .loseFat: 2.0
        case .maintain: 1.6
        case .buildMuscle: 1.8
        }
    }

    /// Au-delà d'un IMC de 30, les protéines se calculent sur le poids correspondant à un IMC de 27,
    /// pour éviter des apports excessifs et irréalistes.
    private func proteinReferenceWeight(weightKg: Double, heightCm: Double) -> Double {
        let heightM = heightCm / 100
        let bmi = weightKg / (heightM * heightM)
        return bmi > 30 ? 27 * heightM * heightM : weightKg
    }
}

/// Règles de sécurité nutritionnelles. Volontairement prudentes.
public enum SafetyLimits {
    public static let deficitRatio = 0.20
    public static let maxDeficitKcal = 600.0
    public static let surplusRatio = 0.10
    public static let maxSurplusKcal = 300.0
    public static let fatShare = 0.27

    public static func minimumKcal(for sex: BiologicalSex) -> Double {
        sex == .male ? 1500 : 1200
    }
}
