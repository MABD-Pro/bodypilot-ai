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
