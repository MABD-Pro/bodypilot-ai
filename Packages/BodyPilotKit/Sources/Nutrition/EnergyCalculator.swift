import BodyPilotCore
import Foundation

/// Calcul déterministe des besoins : Mifflin-St Jeor, facteur d'activité (pas mesurés, sinon
/// niveau déclaré), ajustement à l'objectif.
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

    /// - Parameter exerciseKcalPerDay: dépense moyenne par jour des séances faites ces derniers jours.
    public func targets(for profile: UserProfile, currentWeightKg: Double, exerciseKcalPerDay: Double = 0, on date: Date) -> NutritionTargets {
        let age = profile.age(on: date, calendar: calendar)
        let bmr = basalMetabolicRate(sex: profile.sex, weightKg: currentWeightKg, heightCm: profile.heightCm, age: age)
        let exercise = max(exerciseKcalPerDay, 0)
        let estimated = bmr * profile.dailyActivity.factor + exercise
        // Dépense mesurée sur les repas et les pesées : elle prend le pas sur l'équation au fil des jours.
        let measured = profile.measuredExpenditure
        let confidence = measured?.confidence ?? 0
        let maintenance = measured.map { measured in
            let bounded = min(max(measured.kcal, estimated * (1 - MeasuredExpenditure.maxDeviation)), estimated * (1 + MeasuredExpenditure.maxDeviation))
            return estimated * (1 - confidence) + bounded * confidence
        } ?? estimated
        // Les pas, quand Santé les donne, expliquent la vie quotidienne juste après la dépense.
        let daily = profile.averageDailySteps.map { "vie quotidienne d'après tes pas, environ \(StepActivity.displayed($0).frenchInteger) par jour sur 14 jours" }
        let spent: String
        switch (measured, daily, exercise >= 1) {
        case let (measured?, daily, _):
            // Mesure encore partielle : l'estimation par les pas compte toujours un peu.
            let steps = confidence < 1 ? daily.map { ", et ta \($0)" } ?? "" : ""
            spent = "Dépense mesurée \(maintenance.frenchInteger) kcal, d'après tes repas notés et tes pesées sur \(measured.days) jours\(steps)"
        case let (nil, daily?, true):
            spent = "Dépense estimée \(maintenance.frenchInteger) kcal : \(daily), plus \(exercise.frenchInteger) kcal pour tes séances (moyenne de 14 jours)"
        case let (nil, daily?, false):
            spent = "Dépense estimée \(maintenance.frenchInteger) kcal (\(daily))"
        case (nil, nil, true):
            spent = "Dépense estimée \(maintenance.frenchInteger) kcal, dont \(exercise.frenchInteger) kcal pour tes séances (moyenne de 14 jours)"
        case (nil, nil, false):
            spent = "Dépense estimée \(maintenance.frenchInteger) kcal"
        }

        var kcal: Double
        var explanation: String
        let noDeficit = profile.noDeficitReason(on: date, calendar: calendar)
        switch profile.goal {
        case .loseFat where noDeficit != nil, .recomposition where noDeficit != nil:
            kcal = maintenance
            explanation = "\(spent). Pas de déficit (\(noDeficit ?? "")) : on vise l'équilibre. Pour un objectif de poids, parles-en à un professionnel de santé."
        case .loseFat:
            let deficit = min(maintenance * SafetyLimits.deficitRatio, SafetyLimits.maxDeficitKcal)
            let floor = max(bmr, SafetyLimits.minimumKcal(for: profile.sex))
            kcal = max(maintenance - deficit, floor)
            if kcal > maintenance - deficit {
                explanation = "\(spent). Déficit limité pour ne pas descendre sous \(floor.frenchInteger) kcal, le minimum sûr pour toi."
            } else {
                explanation = "\(spent), moins \(deficit.frenchInteger) kcal pour perdre du gras sans sacrifier le muscle."
            }
        case .maintain:
            kcal = maintenance
            explanation = "\(spent) : on vise l'équilibre."
        case .recomposition:
            let ratio = Self.recompositionDeficitRatio(currentKg: currentWeightKg, targetKg: profile.targetWeightKg)
            let deficit = min(maintenance * ratio, SafetyLimits.maxDeficitKcal)
            let floor = max(bmr, SafetyLimits.minimumKcal(for: profile.sex))
            kcal = max(maintenance - deficit, min(floor, maintenance))
            if deficit < 1 {
                explanation = "\(spent). Tu es à ton poids visé : on reste à l'équilibre, les protéines et la force font le reste."
            } else if kcal > maintenance - deficit {
                explanation = "\(spent). Déficit limité pour ne pas descendre sous \(floor.frenchInteger) kcal, le minimum sûr pour toi."
            } else {
                explanation = "\(spent), moins \(deficit.frenchInteger) kcal : assez pour perdre du gras, pas trop pour garder de quoi construire du muscle. Le déficit se réduit à l'approche de ton poids visé."
            }
        case .buildMuscle:
            let surplus = min(maintenance * SafetyLimits.surplusRatio, SafetyLimits.maxSurplusKcal)
            kcal = maintenance + surplus
            explanation = "\(spent), plus \(surplus.frenchInteger) kcal pour construire du muscle en limitant le gras."
        }
        // Les corrections des bilans s'effacent à mesure que la dépense est mesurée : elles
        // compensaient l'erreur de l'équation, que la mesure corrige déjà.
        let adjustment = profile.calorieAdjustmentKcal * (1 - confidence)
        if abs(adjustment) >= 1 {
            let adjusted = clampAdjusted(kcal + adjustment, planned: kcal, bmr: bmr, maintenance: maintenance, profile: profile, on: date)
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
    private func clampAdjusted(_ kcal: Double, planned: Double, bmr: Double, maintenance: Double, profile: UserProfile, on date: Date) -> Double {
        // Sans déficit permis (grossesse, trouble alimentaire, moins de 18 ans), jamais sous l'équilibre.
        let floor = profile.forbidsDeficit(on: date, calendar: calendar) && profile.goal != .buildMuscle
            ? maintenance
            : min(max(bmr, SafetyLimits.minimumKcal(for: profile.sex)), planned)
        let noSurplus = profile.goal == .loseFat || profile.goal == .recomposition
        let ceiling = max(planned, noSurplus ? maintenance : maintenance + SafetyLimits.maxSurplusKcal)
        return min(max(kcal, floor), ceiling)
    }

    /// 2,0 g/kg quelle que soit la phase : au-dessus du plateau de 1,6 g/kg (Morton et al., 2018),
    /// dans la fourchette conseillée en déficit (Helms et al., 2014). Le coach change de phase
    /// sans faire varier les protéines.
    private func proteinPerKg(for goal: Goal) -> Double { 2.0 }

    /// Recomposition : 20 % de déficit à 10 kg ou plus du poids visé, de moins en moins en
    /// s'en approchant (5 % au minimum), plus rien une fois arrivé. Sans poids visé : 10 %.
    static func recompositionDeficitRatio(currentKg: Double, targetKg: Double?) -> Double {
        guard let targetKg else { return 0.10 }
        let gap = currentKg - targetKg
        guard gap > 0.5 else { return 0 }
        return min(max(gap / 10 * SafetyLimits.deficitRatio, 0.05), SafetyLimits.deficitRatio)
    }

    /// Au-delà d'un IMC de 30, les protéines se calculent sur le poids correspondant à un IMC de 30,
    /// pour éviter des apports excessifs et irréalistes. Le plafond est continu : un kilo de plus
    /// ne fait jamais baisser l'objectif.
    func proteinReferenceWeight(weightKg: Double, heightCm: Double) -> Double {
        let heightM = heightCm / 100
        return min(weightKg, 30 * heightM * heightM)
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
