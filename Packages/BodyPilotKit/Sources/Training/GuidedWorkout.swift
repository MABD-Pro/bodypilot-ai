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
    /// Séance avec de la force : enregistrée comme renforcement dans Santé ; sinon comme cardio,
    /// pour ne pas bloquer la force du lendemain (48 h).
    public var hasStrength: Bool
    public var warmupSeconds: Int?
    public var blocks: [Block]
    public var cooldownSeconds: Int?
}

extension Workout {
    public var guided: GuidedWorkout {
        GuidedWorkout(
            title: title,
            hasStrength: hasStrength,
            warmupSeconds: warmupMinutes > 0 ? warmupMinutes * 60 : nil,
            blocks: exercises.flatMap(\.guidedBlocks),
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
    /// Un bloc répété `sets` fois ; en 5/3/1, une étape par série de la vague (5, 3, 1+),
    /// puis les séries « First Set Last ».
    var guidedBlocks: [GuidedWorkout.Block] {
        guard !wave.isEmpty else {
            return [block(label: guidedLabel, rest: restSeconds, iterations: sets)]
        }
        var blocks = wave.map { set in
            block(label: "\(name) · \(set.reps)\(set.isPlus ? "+" : "") rép.", rest: restSeconds, iterations: 1)
        }
        if backoffSets > 0 {
            blocks.append(block(label: "\(name) · \(StrengthCycle.backoffReps) rép.", rest: StrengthCycle.backoffRestSeconds, iterations: backoffSets))
        }
        return blocks
    }

    private func block(label: String, rest: Int, iterations: Int) -> GuidedWorkout.Block {
        var steps = [GuidedWorkout.Step(isWork: true, goal: guidedGoal, label: label)]
        if rest > 0 {
            steps.append(GuidedWorkout.Step(isWork: false, goal: .seconds(rest), label: "Repos"))
        }
        return GuidedWorkout.Block(steps: steps, iterations: iterations)
    }

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
