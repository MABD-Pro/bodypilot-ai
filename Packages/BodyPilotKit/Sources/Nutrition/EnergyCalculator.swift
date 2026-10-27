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
        var explanation: String
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
        case .recomposition:
            let ratio = Self.recompositionDeficitRatio(currentKg: currentWeightKg, targetKg: profile.targetWeightKg)
            let deficit = min(maintenance * ratio, SafetyLimits.maxDeficitKcal)
            let floor = max(bmr, SafetyLimits.minimumKcal(for: profile.sex))
            kcal = max(maintenance - deficit, min(floor, maintenance))
            if deficit < 1 {
                explanation = "Dépense estimée \(maintenance.frenchInteger) kcal. Tu es à ton poids visé : on reste à l'équilibre, les protéines et la force font le reste."
            } else if kcal > maintenance - deficit {
                explanation = "Dépense estimée \(maintenance.frenchInteger) kcal. Déficit limité pour ne pas descendre sous \(floor.frenchInteger) kcal, le minimum sûr pour toi."
            } else {
                explanation = "Dépense estimée \(maintenance.frenchInteger) kcal, moins \(deficit.frenchInteger) kcal : assez pour perdre du gras, pas trop pour garder de quoi construire du muscle. Le déficit se réduit à l'approche de ton poids visé."
            }
        case .buildMuscle:
            let surplus = min(maintenance * SafetyLimits.surplusRatio, SafetyLimits.maxSurplusKcal)
            kcal = maintenance + surplus
            explanation = "Dépense estimée \(maintenance.frenchInteger) kcal, plus \(surplus.frenchInteger) kcal pour construire du muscle en limitant le gras."
        }
        if profile.calorieAdjustmentKcal != 0 {
            let adjusted = clampAdjusted(kcal + profile.calorieAdjustmentKcal, planned: kcal, bmr: bmr, maintenance: maintenance, profile: profile)
            let applied = adjusted - kcal
            if abs(applied) >= 1 {
                explanation += " Ajusté de \(applied > 0 ? "+" : "")\(applied.frenchInteger) kcal après tes bilans de la semaine."
            }
            kcal = adjusted
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

    /// Une correction de bilan ne franchit jamais les garde-fous : pas sous le plancher de sécurité,
    /// pas de surplus pendant une perte de gras, pas plus que le surplus maximal sinon.
    private func clampAdjusted(_ kcal: Double, planned: Double, bmr: Double, maintenance: Double, profile: UserProfile) -> Double {
        let floor = min(max(bmr, SafetyLimits.minimumKcal(for: profile.sex)), planned)
        let noSurplus = profile.goal == .loseFat || profile.goal == .recomposition
        let ceiling = max(planned, noSurplus ? maintenance : maintenance + SafetyLimits.maxSurplusKcal)
        return min(max(kcal, floor), ceiling)
    }

    private func proteinPerKg(for goal: Goal) -> Double {
        switch goal {
        case .loseFat: 2.0
        case .maintain: 1.6
        case .buildMuscle: 1.8
        case .recomposition: 2.0
        }
    }

    /// Recomposition : 20 % de déficit à 10 kg ou plus du poids visé, de moins en moins en
    /// s'en approchant (5 % au minimum), plus rien une fois arrivé. Sans poids visé : 10 %.
    static func recompositionDeficitRatio(currentKg: Double, targetKg: Double?) -> Double {
        guard let targetKg else { return 0.10 }
        let gap = currentKg - targetKg
        guard gap > 0.5 else { return 0 }
        return min(max(gap / 10 * SafetyLimits.deficitRatio, 0.05), SafetyLimits.deficitRatio)
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
