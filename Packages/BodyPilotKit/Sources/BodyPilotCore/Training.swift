import Foundation

public enum ExerciseVolume: Sendable, Equatable {
    case reps(Int)
    case seconds(Int)
}

public struct WorkoutExercise: Sendable, Equatable {
    public var name: String
    public var sets: Int
    public var volume: ExerciseVolume
    public var restSeconds: Int
    /// 1 = essentiel, 3 = accessoire (supprimé en premier quand le temps manque).
    public var priority: Int
    public var isHighImpact: Bool
    /// Variante sans impact, utilisée en cas de fatigue.
    public var lowImpactAlternative: String?
    /// Sollicite fortement le genou (flexion chargée, impacts).
    public var loadsKnee: Bool
    /// Variante qui épargne le genou.
    public var kneeFriendlyAlternative: String?

    public init(
        name: String,
        sets: Int,
        volume: ExerciseVolume,
        restSeconds: Int,
        priority: Int,
        isHighImpact: Bool = false,
        lowImpactAlternative: String? = nil,
        loadsKnee: Bool = false,
        kneeFriendlyAlternative: String? = nil
    ) {
        self.name = name
        self.sets = sets
        self.volume = volume
        self.restSeconds = restSeconds
        self.priority = priority
        self.isHighImpact = isHighImpact
        self.lowImpactAlternative = lowImpactAlternative
        self.loadsKnee = loadsKnee
        self.kneeFriendlyAlternative = kneeFriendlyAlternative
    }
}

public struct Workout: Sendable, Equatable {
    public var title: String
    public var warmupMinutes: Int
    public var cooldownMinutes: Int
    public var exercises: [WorkoutExercise]
    /// Consigne d'intensité (« garde 2 répétitions en réserve »).
    public var intensityCue: String

    public init(title: String, warmupMinutes: Int, cooldownMinutes: Int, exercises: [WorkoutExercise], intensityCue: String) {
        self.title = title
        self.warmupMinutes = warmupMinutes
        self.cooldownMinutes = cooldownMinutes
        self.exercises = exercises
        self.intensityCue = intensityCue
    }
}

public enum TrainingDayKind: Sendable, Equatable {
    case workout(Workout)
    /// Repos actif : marche, mobilité.
    case activeRest(title: String, minutes: Int)
}

public struct TrainingDay: Sendable, Equatable {
    public var kind: TrainingDayKind
    public var estimatedMinutes: Int
    /// Ajustements appliqués et règles de sécurité déclenchées, en clair.
    public var notes: [String]

    public init(kind: TrainingDayKind, estimatedMinutes: Int, notes: [String] = []) {
        self.kind = kind
        self.estimatedMinutes = estimatedMinutes
        self.notes = notes
    }
}

/// Contraintes du jour déclarées par l'utilisateur.
public struct DayConstraints: Sendable, Equatable {
    public var availableMinutes: Int?
    public var lowEnergy: Bool
    public var missedToday: Bool
    /// La séance d'hier a été ratée : rattrapable si aujourd'hui est un jour de repos.
    public var missedYesterday: Bool
    /// Douleur au genou : aucun exercice qui le charge.
    public var kneePain: Bool
    /// En déplacement : pas de matériel, peu de temps.
    public var traveling: Bool

    public init(
        availableMinutes: Int? = nil,
        lowEnergy: Bool = false,
        missedToday: Bool = false,
        missedYesterday: Bool = false,
        kneePain: Bool = false,
        traveling: Bool = false
    ) {
        self.availableMinutes = availableMinutes
        self.lowEnergy = lowEnergy
        self.missedToday = missedToday
        self.missedYesterday = missedYesterday
        self.kneePain = kneePain
        self.traveling = traveling
    }
}

public protocol TrainingPlanning: Sendable {
    func trainingDay(for profile: UserProfile, on date: Date, constraints: DayConstraints) -> TrainingDay
}
