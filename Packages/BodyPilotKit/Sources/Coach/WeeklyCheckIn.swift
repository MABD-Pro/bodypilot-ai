import BodyPilotCore
import Foundation

/// Proposition du bilan de la semaine : le coach suggère, l'utilisateur décide.
public struct CalorieSuggestion: Sendable, Equatable {
    /// Correction à ajouter à `UserProfile.calorieAdjustmentKcal`.
    public var deltaKcal: Double
    /// Objectif calorique du jour si la proposition est acceptée.
    public var newTargetKcal: Double
    public var message: String
}

extension DailyCoach {
    /// Un pas modeste : l'effet se mesure sur la tendance des semaines suivantes.
    static let calorieStep = 150.0
    /// Au-delà, mieux vaut revoir le profil (activité, objectif) qu'empiler les corrections.
    static let maxCalorieAdjustment = 450.0

    /// Bilan hebdomadaire : une correction de ±150 kcal seulement si la tendance le justifie.
    ///
    /// - Trop rapide (perte au-delà de 1 %/semaine, prise au-delà de 0,5 %) : on corrige tout de suite.
    /// - Stagnation ou mauvaise direction : seulement si c'était déjà le cas une semaine plus tôt,
    ///   pour ne pas réagir à une variation d'eau.
    /// - Jamais au-delà de ±450 kcal cumulés, jamais sous le plancher de sécurité.
    /// - Pas de baisse pendant la rétention d'eau qui entoure les règles (`retainsWater`,
    ///   voir `MenstrualCycle`) : la balance ne reflète pas la perte de gras.
    public func weeklyCheckIn(
        for profile: UserProfile,
        weights: [WeightEntry],
        waists: [WaistEntry] = [],
        exerciseKcalPerDay: Double = 0,
        retainsWater: Bool = false,
        on date: Date
    ) -> CalorieSuggestion? {
        let trend = progress.trend(of: weights, for: profile, on: date)
        guard let weekly = trend.weeklyChangeKg else { return nil }
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: date) ?? date
        let previous = progress.trend(of: weights, for: profile, on: weekAgo).status
        let persistent = trend.status == previous
        let change = "\(weekly > 0 ? "+" : "")\(weekly.frenchOneDecimal) kg/semaine"

        let direction: Double
        let reason: String
        switch (profile.goal, trend.status) {
        case (.loseFat, .tooFast), (.recomposition, .tooFast):
            direction = 1
            reason = "Tu perds vite (\(change)) : au-delà de 1 % par semaine, le muscle trinque."
        case (.buildMuscle, .tooFast):
            direction = -1
            reason = "Tu prends vite (\(change)) : une partie risque d'être du gras."
        case (.loseFat, .stalled), (.loseFat, .wrongDirection):
            guard persistent else { return nil }
            direction = -1
            reason = "Ta tendance ne baisse plus depuis deux semaines (\(change))."
        case (.recomposition, .stalled), (.recomposition, .wrongDirection):
            // Taille en baisse : le gras part, on ne touche à rien.
            guard persistent else { return nil }
            if let waist = progress.waistChange(of: waists, on: date), waist <= Self.meaningfulWaistDropCm { return nil }
            direction = -1
            reason = waists.isEmpty
                ? "Ton poids ne baisse plus depuis deux semaines (\(change)). Mesure aussi ton tour de taille : s'il baisse, pas besoin de manger moins."
                : "Ni ton poids ni ta taille ne baissent depuis deux semaines (\(change))."
        case (.buildMuscle, .stalled), (.buildMuscle, .wrongDirection):
            guard persistent else { return nil }
            direction = 1
            reason = "Ton poids ne monte plus depuis deux semaines (\(change))."
        case (.maintain, .wrongDirection):
            guard persistent else { return nil }
            direction = weekly > 0 ? -1 : 1
            reason = "Ton poids dérive depuis deux semaines (\(change))."
        default:
            return nil
        }

        if direction < 0, retainsWater { return nil }

        let current = profile.calorieAdjustmentKcal
        let proposed = min(max(current + direction * Self.calorieStep, -Self.maxCalorieAdjustment), Self.maxCalorieAdjustment)
        guard proposed != current else { return nil }

        // Effet réel une fois les garde-fous appliqués : rien à proposer s'il est négligeable.
        let weight = trend.currentTrendKg ?? profile.startWeightKg
        var adjusted = profile
        adjusted.calorieAdjustmentKcal = proposed
        let before = nutrition.targets(for: profile, currentWeightKg: weight, exerciseKcalPerDay: exerciseKcalPerDay, on: date).macros.kcal
        let after = nutrition.targets(for: adjusted, currentWeightKg: weight, exerciseKcalPerDay: exerciseKcalPerDay, on: date).macros.kcal
        guard abs(after - before) >= 50 else { return nil }

        let delta = after - before
        let proposal = "Je te propose \(delta > 0 ? "+" : "−")\(abs(delta).frenchInteger) kcal par jour, soit \(after.frenchInteger) kcal."
        return CalorieSuggestion(deltaKcal: proposed - current, newTargetKcal: after, message: "\(reason) \(proposal)")
    }
}
