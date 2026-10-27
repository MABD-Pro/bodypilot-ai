import BodyPilotCore
import Foundation

/// Réponse du coach aux trois questions du jour.
public struct TodayPlan: Sendable, Equatable {
    /// Une phrase qui résume la journée.
    public var headline: String
    public var targets: NutritionTargets
    public var meals: DayMealPlan
    public var training: TrainingDay
    public var trend: WeightTrend
    /// Réponse à « est-ce que je progresse ? ».
    public var progressMessage: String
    public var adjustments: Set<QuickAdjustment>
}

/// Orchestre nutrition, entraînement et progression via les protocoles de BodyPilotCore.
///
/// Tout est déterministe et local : aucun appel IA n'est nécessaire pour ce plan.
public struct DailyCoach: Sendable {
    public var nutrition: any NutritionPlanning
    public var training: any TrainingPlanning
    public var progress: any ProgressAnalyzing

    public init(nutrition: any NutritionPlanning, training: any TrainingPlanning, progress: any ProgressAnalyzing) {
        self.nutrition = nutrition
        self.training = training
        self.progress = progress
    }

    public func plan(
        for profile: UserProfile,
        weights: [WeightEntry],
        adjustments: Set<QuickAdjustment> = [],
        yesterdayAdjustments: Set<QuickAdjustment> = [],
        on date: Date
    ) -> TodayPlan {
        let trend = progress.trend(of: weights, for: profile, on: date)
        let weight = trend.currentTrendKg ?? profile.startWeightKg
        let targets = nutrition.targets(for: profile, currentWeightKg: weight, on: date)
        let meals = nutrition.mealPlan(for: targets, on: date)
        let constraints = DayConstraints(today: adjustments, yesterday: yesterdayAdjustments)
        let trainingDay = training.trainingDay(for: profile, on: date, constraints: constraints)

        return TodayPlan(
            headline: headline(training: trainingDay, adjustments: adjustments, kcal: targets.macros.kcal),
            targets: targets,
            meals: meals,
            training: trainingDay,
            trend: trend,
            progressMessage: progressMessage(for: trend, goal: profile.goal),
            adjustments: adjustments
        )
    }

    func headline(training: TrainingDay, adjustments: Set<QuickAdjustment>, kcal: Double) -> String {
        if adjustments.contains(.missedWorkout) {
            return "Séance ratée, pas de souci. On ne double pas, on reprend au prochain créneau."
        }
        if adjustments.contains(.tired) && adjustments.contains(.shortOnTime) {
            return "Journée chargée et fatigue : version courte et douce, l'essentiel suffit."
        }
        if adjustments.contains(.tired) {
            return "Journée en douceur : séance allégée, alimentation inchangée pour bien récupérer."
        }
        switch training.kind {
        case .workout(let workout):
            if adjustments.contains(.shortOnTime) {
                return "Séance express de \(training.estimatedMinutes) min : l'essentiel, rien de plus."
            }
            return "\(workout.title) en \(training.estimatedMinutes) min et \(kcal.frenchInteger) kcal au menu."
        case .activeRest(_, let minutes):
            return "Jour de récupération : \(minutes) min de marche et des repas qui nourrissent."
        }
    }

    func progressMessage(for trend: WeightTrend, goal: Goal) -> String {
        guard let weekly = trend.weeklyChangeKg else {
            return trend.points.isEmpty
                ? "Pèse-toi demain matin à jeun : la tendance apparaît après une semaine."
                : "Encore quelques pesées et la tendance sera fiable. Une pesée le matin suffit."
        }
        let change = "\(weekly > 0 ? "+" : "")\(weekly.frenchOneDecimal) kg/semaine"
        switch trend.status {
        case .onTrack:
            return "Oui : \(change), le rythme visé. Continue comme ça."
        case .tooFast:
            return goal == .loseFat
                ? "Tu perds vite (\(change)). Au-delà de 1 % par semaine, le muscle trinque : envisage +150 kcal."
                : "Tu prends vite (\(change)) : une partie risque d'être du gras. Envisage −150 kcal."
        case .stalled:
            return "Tendance stable (\(change)). Normal par moments ; si ça dure 2 semaines, on ajustera ensemble."
        case .wrongDirection:
            return goal == .maintain
                ? "Ton poids dérive (\(change)). On surveille avant d'ajuster."
                : "La tendance va dans le mauvais sens (\(change)). Vérifions ensemble les portions cette semaine."
        case .notEnoughData:
            return "Encore quelques pesées et la tendance sera fiable."
        }
    }
}
