import Foundation

public enum ExerciseVolume: Sendable, Equatable {
    case reps(Int)
    case seconds(Int)
}

public struct WorkoutExercise: Sendable, Equatable {
    /// Nom de l'exercice au catalogue : il ne change pas quand l'exercice est adapté ou remplacé,
    /// ce qui permet de retrouver un remplacement choisi par l'utilisateur.
    public var key: String
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
    /// Variantes équivalentes (même mouvement, même matériel), proposées quand l'utilisateur
    /// veut remplacer l'exercice : poste occupé, matériel absent, mouvement qu'il n'aime pas.
    public var alternatives: [String]

    public init(
        name: String,
        sets: Int,
        volume: ExerciseVolume,
        restSeconds: Int,
        priority: Int,
        isHighImpact: Bool = false,
        lowImpactAlternative: String? = nil,
        loadsKnee: Bool = false,
        kneeFriendlyAlternative: String? = nil,
        alternatives: [String] = []
    ) {
        self.key = name
        self.name = name
        self.sets = sets
        self.volume = volume
        self.restSeconds = restSeconds
        self.priority = priority
        self.isHighImpact = isHighImpact
        self.lowImpactAlternative = lowImpactAlternative
        self.loadsKnee = loadsKnee
        self.kneeFriendlyAlternative = kneeFriendlyAlternative
        self.alternatives = alternatives
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
    /// Remplacements demandés : clé de l'exercice → nombre de demandes. Chaque demande passe
    /// à la variante suivante, puis revient à l'exercice d'origine.
    public var exerciseSwaps: [String: Int]
    /// Envie de bouger un jour sans séance prévue : le coach propose une séance en plus.
    public var wantsExtraSession: Bool
    /// Dernière séance faite, pour enchaîner sur la suivante plutôt que retravailler les mêmes muscles.
    public var lastWorkoutTitle: String?

    public init(
        availableMinutes: Int? = nil,
        lowEnergy: Bool = false,
        missedToday: Bool = false,
        missedYesterday: Bool = false,
        kneePain: Bool = false,
        traveling: Bool = false,
        exerciseSwaps: [String: Int] = [:],
        wantsExtraSession: Bool = false,
        lastWorkoutTitle: String? = nil
    ) {
        self.availableMinutes = availableMinutes
        self.lowEnergy = lowEnergy
        self.missedToday = missedToday
        self.missedYesterday = missedYesterday
        self.kneePain = kneePain
        self.traveling = traveling
        self.exerciseSwaps = exerciseSwaps
        self.wantsExtraSession = wantsExtraSession
        self.lastWorkoutTitle = lastWorkoutTitle
    }
}

public protocol TrainingPlanning: Sendable {
    func trainingDay(for profile: UserProfile, on date: Date, constraints: DayConstraints) -> TrainingDay
}

/// Famille d'activité sportive, telle que lue dans Santé (Apple Watch ou autres apps).
public enum ActivityKind: String, Sendable, Codable, CaseIterable {
    case strength, running, cycling, walking, swimming, intervals, mobility, sport, combat, cardio, other

    public var title: String {
        switch self {
        case .strength: "Renforcement"
        case .running: "Course"
        case .cycling: "Vélo"
        case .walking: "Marche"
        case .swimming: "Natation"
        case .intervals: "Fractionné"
        case .mobility: "Mobilité"
        case .sport: "Sport"
        case .combat: "Sport de combat"
        case .cardio: "Cardio"
        case .other: "Activité"
        }
    }
}

/// Activité enregistrée hors de l'app (Santé), sur une période.
public struct ActivitySample: Sendable, Equatable, Identifiable {
    public var id: String
    public var kind: ActivityKind
    public var start: Date
    public var minutes: Double
    public var kcal: Double?

    public init(id: String, kind: ActivityKind, start: Date, minutes: Double, kcal: Double? = nil) {
        self.id = id
        self.kind = kind
        self.start = start
        self.minutes = minutes
        self.kcal = kcal
    }
}
