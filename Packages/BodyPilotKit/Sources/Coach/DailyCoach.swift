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
    public var calendar: Calendar

    public init(
        nutrition: any NutritionPlanning,
        training: any TrainingPlanning,
        progress: any ProgressAnalyzing,
        calendar: Calendar = .current
    ) {
        self.nutrition = nutrition
        self.training = training
        self.progress = progress
        self.calendar = calendar
    }

    public func plan(
        for profile: UserProfile,
        weights: [WeightEntry],
        adjustments: Set<QuickAdjustment> = [],
        availableMinutes: Int? = nil,
        eatingOutSlot: MealSlot? = nil,
        yesterdayAdjustments: Set<QuickAdjustment> = [],
        exerciseSwaps: [String: Int] = [:],
        weekTrainingDays: [Int]? = nil,
        mealIntakes: [MealSlot: MealIntake] = [:],
        on date: Date
    ) -> TodayPlan {
        // Les jours de séance de cette semaine, s'ils diffèrent des jours habituels.
        var profile = profile
        if let weekTrainingDays {
            profile.trainingWeekdays = UserProfile.normalized(weekTrainingDays, allowEmpty: true)
        }
        let trend = progress.trend(of: weights, for: profile, on: date)
        let weight = trend.currentTrendKg ?? profile.startWeightKg
        let targets = nutrition.targets(for: profile, currentWeightKg: weight, on: date)
        let meals = nutrition.mealPlan(
            for: targets,
            profile: profile,
            on: date,
            constraints: MealConstraints(today: adjustments, at: date, calendar: calendar, eatingOutSlot: eatingOutSlot, eaten: mealIntakes)
        )
        let constraints = DayConstraints(
            today: adjustments,
            yesterday: yesterdayAdjustments,
            availableMinutes: availableMinutes,
            exerciseSwaps: exerciseSwaps
        )
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

    /// Une phrase qui dit ce qui change aujourd'hui, la contrainte la plus forte d'abord.
    func headline(training: TrainingDay, adjustments: Set<QuickAdjustment>, kcal: Double) -> String {
        if adjustments.contains(.kneePain) {
            return "Genou sensible : on le ménage aujourd'hui, le reste du plan continue."
        }
        if adjustments.contains(.missedWorkout) {
            return "Séance ratée, pas de souci. On ne double pas, on reprend au prochain créneau."
        }
        if adjustments.contains(.traveling) {
            return "En déplacement : séance sans matériel et repères simples pour manger."
        }
        if adjustments.contains(.tired) && adjustments.contains(.shortOnTime) {
            return "Journée chargée et fatigue : version courte et douce, l'essentiel suffit."
        }
        if adjustments.contains(.tired) {
            return "Journée en douceur : séance allégée, alimentation inchangée pour bien récupérer."
        }
        if adjustments.contains(.eatingOut) {
            return "Restaurant au programme : profite, avec trois repères simples pour garder le cap."
        }
        if adjustments.contains(.notHungry) {
            return "Peu d'appétit : des portions plus petites, les protéines d'abord."
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
