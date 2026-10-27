import BodyPilotCore

/// Séance découpée en étapes guidées, prête à être envoyée sur une montre.
///
/// Neutre vis-à-vis du framework : l'app la traduit en `WorkoutKit` (Apple Watch).
/// Une série en répétitions n'a pas de durée fixe : l'étape reste ouverte et
/// l'utilisateur passe à la suite d'une touche ; une série chronométrée et le repos
/// ont une durée.
public struct GuidedWorkout: Sendable, Equatable {
    public enum StepGoal: Sendable, Equatable {
        case open
        case seconds(Int)
    }

    public struct Step: Sendable, Equatable {
        public var isWork: Bool
        public var goal: StepGoal
        public var label: String
    }

    public struct Block: Sendable, Equatable {
        public var steps: [Step]
        public var iterations: Int
    }

    public var title: String
    public var warmupSeconds: Int?
    public var blocks: [Block]
    public var cooldownSeconds: Int?
}

extension Workout {
    public var guided: GuidedWorkout {
        GuidedWorkout(
            title: title,
            warmupSeconds: warmupMinutes > 0 ? warmupMinutes * 60 : nil,
            blocks: exercises.map { exercise in
                var steps = [GuidedWorkout.Step(isWork: true, goal: exercise.guidedGoal, label: exercise.guidedLabel)]
                if exercise.restSeconds > 0 {
                    steps.append(GuidedWorkout.Step(isWork: false, goal: .seconds(exercise.restSeconds), label: "Repos"))
                }
                return GuidedWorkout.Block(steps: steps, iterations: exercise.sets)
            },
            cooldownSeconds: cooldownMinutes > 0 ? cooldownMinutes * 60 : nil
        )
    }
}

extension TrainingDay {
    /// Séance guidée du jour ; rien pour une simple marche.
    public var guidedWorkout: GuidedWorkout? {
        guard case .workout(let workout) = kind else { return nil }
        return workout.guided
    }
}

extension WorkoutExercise {
    var guidedGoal: GuidedWorkout.StepGoal {
        switch volume {
        case .reps: .open
        case .seconds(let seconds): .seconds(seconds)
        }
    }

    var guidedLabel: String {
        switch volume {
        case .reps(let reps): "\(name) · \(reps) rép."
        case .seconds: name
        }
    }
}
