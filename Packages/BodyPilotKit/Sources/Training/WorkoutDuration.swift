import BodyPilotCore

extension WorkoutExercise {
    /// Durée estimée d'une série : 3 s par répétition.
    var workSeconds: Int {
        switch volume {
        case .reps(let reps): reps * 3
        case .seconds(let seconds): seconds
        }
    }

    var estimatedSeconds: Int {
        sets * workSeconds + max(sets - 1, 0) * restSeconds
            + backoffSets * (StrengthCycle.backoffReps * 3 + StrengthCycle.backoffRestSeconds)
            + Self.transitionSeconds
    }

    static let transitionSeconds = 30
}

extension Workout {
    public var estimatedMinutes: Int {
        let exerciseSeconds = exercises.reduce(0) { $0 + $1.estimatedSeconds }
        return warmupMinutes + cooldownMinutes + Int((Double(exerciseSeconds) / 60).rounded(.up))
    }
}
