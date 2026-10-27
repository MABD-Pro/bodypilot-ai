import BodyPilotCore
import Foundation

/// Réponse du coach aux trois questions du jour.
public struct TodayPlan: Sendable, Equatable {
    /// Une phrase qui résume la journée.
    public var headline: String
    public var targets: NutritionTargets
    public var meals: DayMealPlan
    public var training: TrainingDay
    /// Les propositions du jour, dont celle que le coach recommande.
    public var trainingOptions: TrainingOptions
    public var trend: WeightTrend
    /// Réponse à « est-ce que je progresse ? ».
    public var progressMessage: String
    /// Variation du tour de taille sur 4 semaines (cm), si mesurée.
    public var waistChangeCm: Double?
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
        waists: [WaistEntry] = [],
        adjustments: Set<QuickAdjustment> = [],
        availableMinutes: Int? = nil,
        eatingOutSlot: MealSlot? = nil,
        exerciseSwaps: [String: Int] = [:],
        mealIntakes: [MealSlot: MealIntake] = [:],
        describedMeals: [MealSlot: DescribedMeal] = [:],
        lastWorkoutTitle: String? = nil,
        lastStrengthDay: Date? = nil,
        calibratedLifts: Set<String>? = nil,
        sleepHours: Double? = nil,
        activeDays: Set<Date> = [],
        recentActivities: [ActivitySample] = [],
        trainingChoice: TrainingChoice? = nil,
        on date: Date
    ) -> TodayPlan {
        let trend = progress.trend(of: weights, for: profile, on: date)
        let waistChange = progress.waistChange(of: waists, on: date)
        let weight = trend.currentTrendKg ?? profile.startWeightKg
        let targets = nutrition.targets(for: profile, currentWeightKg: weight, on: date)
        let meals = nutrition.mealPlan(
            for: targets,
            profile: profile,
            on: date,
            constraints: MealConstraints(today: adjustments, at: date, calendar: calendar, eatingOutSlot: eatingOutSlot, eaten: mealIntakes, described: describedMeals)
        )
        let constraints = DayConstraints(
            today: adjustments,
            availableMinutes: availableMinutes,
            exerciseSwaps: exerciseSwaps,
            lastWorkoutTitle: lastWorkoutTitle,
            lastStrengthDay: lastStrengthDay,
            calibratedLifts: calibratedLifts,
            sleepHours: sleepHours,
            activeDays: activeDays,
            recentActivities: recentActivities,
            choice: trainingChoice
        )
        let options = training.options(for: profile, on: date, constraints: constraints)
        let chosen = trainingChoice.flatMap { options.option($0) } ?? options.option(options.recommended)
        let trainingDay = chosen?.day ?? TrainingDay(kind: .rest, estimatedMinutes: 0)

        return TodayPlan(
            headline: headline(training: trainingDay, adjustments: adjustments, kcal: targets.macros.kcal),
            targets: targets,
            meals: meals,
            training: trainingDay,
            trainingOptions: options,
            trend: trend,
            progressMessage: progressMessage(for: trend, goal: profile.goal, waistChange: waistChange),
            waistChangeCm: waistChange,
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
        if case .rest = training.kind {
            return "Journée de repos : tes muscles se construisent aussi pendant la récupération."
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
            if workout.isStrengthTest {
                return "\(workout.title) : on mesure tes charges de travail, \(training.estimatedMinutes) min."
            }
            if !workout.hasStrength {
                return "Muscles en récupération : \(workout.title.lowercased()), \(training.estimatedMinutes) min."
            }
            return "\(workout.title) en \(training.estimatedMinutes) min et \(kcal.frenchInteger) kcal au menu."
        case .activeRest(_, let minutes):
            return "Aujourd'hui : \(minutes) min de marche et des repas qui nourrissent."
        case .rest:
            return "Journée de repos."
        }
    }

    /// En recomposition, le tour de taille qui baisse prouve le progrès même quand le poids stagne.
    static let meaningfulWaistDropCm = -1.0

    func progressMessage(for trend: WeightTrend, goal: Goal, waistChange: Double? = nil) -> String {
        if goal == .recomposition, let waistChange, waistChange <= Self.meaningfulWaistDropCm,
           trend.status == .stalled || trend.status == .onTrack || trend.status == .notEnoughData {
            let cm = abs(waistChange).frenchOneDecimal
            return trend.status == .onTrack
                ? "Oui, sur les deux plans : le poids baisse au bon rythme et ta taille a perdu \(cm) cm en 4 semaines."
                : "Oui : ta taille a perdu \(cm) cm en 4 semaines alors que ton poids bouge peu. Tu perds du gras et gagnes du muscle, c'est la recomposition."
        }
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
            return goal == .loseFat || goal == .recomposition
                ? "Tu perds vite (\(change)). Au-delà de 1 % par semaine, le muscle trinque : envisage +150 kcal."
                : "Tu prends vite (\(change)) : une partie risque d'être du gras. Envisage −150 kcal."
        case .stalled where goal == .recomposition:
            return "Poids stable (\(change)). En recomposition c'est possible : mesure ton tour de taille chaque semaine pour voir si le gras baisse."
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
