import BodyPilotCore
import Foundation
import HealthKit
import Training
import WorkoutKit

/// Traduction de la séance guidée en plan WorkoutKit, que l'Apple Watch déroule étape par étape.
extension GuidedWorkout {
    var watchPlan: WorkoutPlan? {
        guard let activity = Self.watchActivity(strength: hasStrength) else { return nil }
        let workout = CustomWorkout(
            activity: activity,
            location: .indoor,
            displayName: title,
            warmup: warmupSeconds.map { WorkoutStep(goal: .time(Double($0), .seconds), displayName: "Échauffement") },
            blocks: blocks.map { block in
                IntervalBlock(
                    steps: block.steps.map { step in
                        IntervalStep(step.isWork ? .work : .recovery, step: WorkoutStep(goal: step.goal.workoutGoal, displayName: step.label))
                    },
                    iterations: block.iterations
                )
            },
            cooldown: cooldownSeconds.map { WorkoutStep(goal: .time(Double($0), .seconds), displayName: "Retour au calme") }
        )
        return WorkoutPlan(.custom(workout))
    }

    /// Renforcement musculaire pour une séance avec de la force ; cardio sinon, pour que Santé
    /// ne la compte pas comme de la force (la règle des 48 h bloquerait la force du lendemain).
    private static func watchActivity(strength: Bool) -> HKWorkoutActivityType? {
        let candidates: [HKWorkoutActivityType] = strength
            ? [.traditionalStrengthTraining, .functionalStrengthTraining, .highIntensityIntervalTraining]
            : [.mixedCardio, .highIntensityIntervalTraining, .walking]
        return candidates.first { CustomWorkout.supportsActivity($0) }
    }
}

private extension GuidedWorkout.StepGoal {
    var workoutGoal: WorkoutGoal {
        switch self {
        case .open: .open
        case .seconds(let seconds): .time(Double(seconds), .seconds)
        }
    }
}

extension TrainingDay {
    /// Titre de la séance, `nil` un jour de marche.
    var workoutTitle: String? {
        if case .workout(let workout) = kind { return workout.title }
        return nil
    }

    /// La séance guidée, ou la marche du jour avec son objectif de durée.
    var watchPlan: WorkoutPlan? {
        switch kind {
        case .workout(let workout) where workout.isCardioTest:
            // Le test de marche : 1,6 km, la Watch mesure le temps et le pouls.
            WorkoutPlan(.goal(SingleGoalWorkout(activity: .walking, location: .outdoor, goal: .distance(CardioTest.distanceKm, .kilometers))))
        case .workout(let workout):
            workout.guided.watchPlan
        case .activeRest(_, let minutes):
            WorkoutPlan(.goal(SingleGoalWorkout(activity: .walking, location: .outdoor, goal: .time(Double(minutes), .minutes))))
        case .rest:
            nil
        }
    }
}

/// La séance du jour, planifiée sur l'Apple Watch : elle attend dans l'app Exercice, rubrique
/// planifiée, sans rien valider sur l'iPhone. Une seule à la fois, celle d'aujourd'hui.
enum WatchSchedule {
    /// Planifie la séance (ou retire celle de BodyPilot si `plan` est `nil`). `ask` demande
    /// l'autorisation si besoin : seulement après une touche sur « Envoyer sur ma Watch ».
    @discardableResult
    static func replace(with plan: WorkoutPlan?, ask: Bool, now: Date = .now, calendar: Calendar = .current) async -> Bool {
        guard WorkoutScheduler.isSupported else { return false }
        let scheduler = WorkoutScheduler.shared
        var state = await scheduler.authorizationState
        if state != .authorized, ask { state = await scheduler.requestAuthorization() }
        guard state == .authorized else { return false }
        // Le planificateur ne contient que les entraînements de BodyPilot : on repart de zéro.
        await scheduler.removeAllWorkouts()
        guard let plan else { return true }
        await scheduler.schedule(plan, at: slot(after: now, calendar: calendar))
        return true
    }

    /// L'utilisateur a déjà permis à BodyPilot de planifier sur la montre.
    static func isAuthorized() async -> Bool {
        guard WorkoutScheduler.isSupported else { return false }
        return await WorkoutScheduler.shared.authorizationState == .authorized
    }

    /// Prochain quart d'heure d'aujourd'hui, au plus tard 23 h 45 : une heure passée pourrait
    /// ne plus s'afficher sur la montre. Reprogrammée à chaque retour dans l'app.
    static func slot(after now: Date, calendar: Calendar = .current) -> DateComponents {
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        let minutes = min((components.hour ?? 0) * 60 + (components.minute ?? 0) + 15, 23 * 60 + 45) / 15 * 15
        components.hour = minutes / 60
        components.minute = minutes % 60
        return components
    }
}
