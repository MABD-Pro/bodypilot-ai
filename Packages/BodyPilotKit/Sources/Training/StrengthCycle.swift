import BodyPilotCore

/// Force dans le cycle de 12 semaines : dans chaque phase, 3 semaines de montée puis une
/// semaine allégée. Pourcentages choisis par BodyPilot dans la fourchette de l'ACSM (2009) ;
/// la semaine allégée suit le consensus de Bell et al. (2023). Voir docs/COACH_RULES.md.
public enum StrengthCycle {
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

    /// Séries, répétitions et charge des mouvements principaux selon la semaine ; avec des
    /// charges (salle), la charge visée devient un pourcentage du max estimé.
    public static func apply(_ week: CycleWeek, to workout: Workout, usesLoads: Bool) -> Workout {
        let plan = prescription(for: week)
        var result = workout
        result.exercises = workout.exercises.map { exercise in
            var adjusted = exercise
            guard exercise.priority < 4 else { return exercise }
            if exercise.priority == 1, case .reps = exercise.volume {
                adjusted.sets = plan.sets
                adjusted.volume = .reps(plan.reps)
                adjusted.percentOfMax = usesLoads ? plan.percentOfMax : nil
            } else {
                adjusted.sets = week.isDeload ? accessorySets - 1 : accessorySets
            }
            return adjusted
        }
        let load = usesLoads ? " à environ \(Int((plan.percentOfMax * 100).rounded())) % de ton max" : ""
        result.intensityCue = "Mouvements principaux : \(plan.sets) × \(plan.reps)\(load), \(plan.repsInReserve) répétitions en réserve."
        return result
    }

    /// Note sous le titre de la séance : où l'on en est, et ce que veut dire la semaine allégée.
    public static func note(for week: CycleWeek) -> String {
        week.isDeload
            ? "\(week.label) : moitié moins de séries, charges plus basses, pas de record. La fatigue retombe et la phase suivante repart plus haut."
            : week.label
    }
}
