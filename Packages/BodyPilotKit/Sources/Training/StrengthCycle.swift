import BodyPilotCore

/// Force dans le cycle de 12 semaines : dans chaque phase, 3 semaines de montée puis une
/// semaine allégée. Mouvements à la barre en 5/3/1 (Wendler) avec « First Set Last » ;
/// les autres mouvements principaux gardent des pourcentages choisis par BodyPilot dans la
/// fourchette de l'ACSM (2009). La semaine allégée suit le consensus de Bell et al. (2023).
/// Voir docs/COACH_RULES.md.
public enum StrengthCycle {
    /// Max d'entraînement du 5/3/1 : 90 % du max estimé.
    public static let trainingMaxShare = 0.9
    public static let backoffSets = 5
    public static let backoffReps = 5
    static let backoffRestSeconds = 90
    static let waveRestSeconds = 180

    /// La vague de la semaine, en part du max estimé (pourcentages du max d'entraînement × 0,9).
    public static func wave(for week: CycleWeek) -> [WaveSet] {
        let sets: [(Int, Double)]
        switch week.weekInPhase {
        case 1: sets = [(5, 0.65), (5, 0.75), (5, 0.85)]
        case 2: sets = [(3, 0.70), (3, 0.80), (3, 0.90)]
        case 3: sets = [(5, 0.75), (3, 0.85), (1, 0.95)]
        default: sets = [(5, 0.40), (5, 0.50), (5, 0.60)]
        }
        return sets.enumerated().map { index, set in
            WaveSet(reps: set.0, percentOfMax: set.1 * trainingMaxShare, isPlus: !week.isDeload && index == sets.count - 1)
        }
    }

    /// Charges de la vague sans max noté : le max s'estime depuis la charge d'essai prudente
    /// (prévue pour `reps` répétitions, Epley), arrondi au 2,5 kg inférieur, jamais sous la barre vide.
    public static func waveLoads(_ wave: [WaveSet], startingKg: Double, reps: Int) -> [Double] {
        let estimatedMax = startingKg * (1 + Double(reps) / 30)
        return wave.map { StrengthCalibration.roundDown(estimatedMax * $0.percentOfMax, barbell: true) }
    }

    /// Mouvement mené en 5/3/1 : principal, aux répétitions, à la barre et avec des charges.
    static func usesWave(_ exercise: WorkoutExercise, usesLoads: Bool) -> Bool {
        guard usesLoads, exercise.priority == 1, case .reps = exercise.volume else { return false }
        return ExerciseGuide.guide(for: exercise.name)?.barbell == true
    }

    public struct Prescription: Sendable, Equatable {
        public var sets: Int
        public var reps: Int
        public var percentOfMax: Double
        public var repsInReserve: Int
    }

    public static func prescription(for week: CycleWeek) -> Prescription {
        switch week.weekInPhase {
        case 1: Prescription(sets: 3, reps: 6, percentOfMax: 0.75, repsInReserve: 3)
        case 2: Prescription(sets: 4, reps: 6, percentOfMax: 0.78, repsInReserve: 2)
        case 3: Prescription(sets: 4, reps: 5, percentOfMax: 0.82, repsInReserve: 1)
        default: Prescription(sets: 2, reps: 5, percentOfMax: 0.70, repsInReserve: 4)
        }
    }

    /// Exercices secondaires : 3 séries, une de moins en semaine allégée.
    static let accessorySets = 3
    /// Semaine allégée : la séance raccourcit, le temps gagné ne part pas en cardio.
    public static let deloadTimeShare = 0.7

    /// Séries, répétitions et charge des mouvements principaux selon la semaine ; avec des
    /// charges (salle), la charge visée devient un pourcentage du max estimé.
    public static func apply(_ week: CycleWeek, to workout: Workout, usesLoads: Bool) -> Workout {
        let plan = prescription(for: week)
        var result = workout
        result.exercises = workout.exercises.map { exercise in
            var adjusted = exercise
            guard exercise.priority < 4 else { return exercise }
            if usesWave(exercise, usesLoads: usesLoads) {
                let steps = Self.wave(for: week)
                adjusted.wave = steps
                adjusted.sets = steps.count
                adjusted.volume = .reps(steps[steps.count - 1].reps)
                adjusted.percentOfMax = steps[steps.count - 1].percentOfMax
                adjusted.restSeconds = waveRestSeconds
                adjusted.backoffSets = week.isDeload ? 0 : backoffSets
            } else if exercise.priority == 1, case .reps = exercise.volume {
                adjusted.sets = plan.sets
                adjusted.volume = .reps(plan.reps)
                adjusted.percentOfMax = usesLoads ? plan.percentOfMax : nil
            } else {
                adjusted.sets = week.isDeload ? accessorySets - 1 : accessorySets
                // Semaine allégée : les secondaires s'allègent aussi, à la même part du max.
                if week.isDeload, usesLoads { adjusted.percentOfMax = plan.percentOfMax }
            }
            return adjusted
        }
        if result.exercises.contains(where: { !$0.wave.isEmpty }) {
            result.intensityCue = week.isDeload
                ? "Mouvements à la barre en 5/3/1, semaine allégée : 3 séries de 5 légères, rien au maximum."
                : "Mouvements à la barre en 5/3/1 : 3 séries qui montent, la dernière au maximum de répétitions propres en gardant 1 répétition en réserve, puis des séries de 5 à la charge de la première."
            return result
        }
        let load = usesLoads ? " à environ \(Int((plan.percentOfMax * 100).rounded())) % de ton max" : ""
        result.intensityCue = "Mouvements principaux : \(plan.sets) × \(plan.reps)\(load), \(plan.repsInReserve) répétition\(plan.repsInReserve > 1 ? "s" : "") en réserve."
        return result
    }

    /// Note sous le titre de la séance : où l'on en est, et ce que veut dire la semaine allégée.
    public static func note(for week: CycleWeek) -> String {
        week.isDeload
            ? "\(week.label) : moitié moins de séries, charges plus basses, pas de record. La fatigue retombe et la phase suivante repart plus haut."
            : week.label
    }
}
