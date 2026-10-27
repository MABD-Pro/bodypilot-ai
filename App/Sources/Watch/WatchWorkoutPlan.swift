import BodyPilotCore
import Foundation
import HealthKit
import Training
import WorkoutKit

/// Traduction de la séance guidée en plan WorkoutKit, que l'Apple Watch déroule étape par étape.
extension GuidedWorkout {
    var watchPlan: WorkoutPlan? {
        guard let activity = Self.watchActivity else { return nil }
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

    /// Renforcement musculaire si la montre le gère en séance personnalisée, sinon la meilleure approche.
    private static var watchActivity: HKWorkoutActivityType? {
        [.traditionalStrengthTraining, .functionalStrengthTraining, .highIntensityIntervalTraining]
            .first { CustomWorkout.supportsActivity($0) }
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

    /// La séance guidée, ou la marche du jour de repos avec son objectif de durée.
    var watchPlan: WorkoutPlan? {
        switch kind {
        case .workout(let workout):
            workout.guided.watchPlan
        case .activeRest(_, let minutes):
            WorkoutPlan(.goal(SingleGoalWorkout(activity: .walking, location: .outdoor, goal: .time(Double(minutes), .minutes))))
        }
    }
}

/// Planning de la semaine sur l'Apple Watch : chaque jour apparaît dans l'app Exercice, rubrique planifiée.
enum WatchSchedule {
    static var isSupported: Bool { WorkoutScheduler.isSupported }

    /// Heure affichée sur la montre ; c'est toi qui lances l'entraînement quand tu veux.
    static let hour = 7

    /// Remplace le planning BodyPilot de la montre. `false` si l'autorisation est refusée.
    static func replace(with plans: [(day: Date, plan: WorkoutPlan)], calendar: Calendar = .current) async -> Bool {
        let scheduler = WorkoutScheduler.shared
        guard await scheduler.requestAuthorization() == .authorized else { return false }
        // Le planificateur ne contient que les entraînements de BodyPilot : on repart de zéro.
        await scheduler.removeAllWorkouts()
        for item in plans.prefix(WorkoutScheduler.maxAllowedScheduledWorkoutCount) {
            var components = calendar.dateComponents([.year, .month, .day], from: item.day)
            components.hour = hour
            components.minute = 0
            await scheduler.schedule(item.plan, at: components)
        }
        return true
    }
}
