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
    /// 1 = essentiel, 3 = accessoire, 4 = cardio et marche inclinée (retirés en premier quand le temps manque).
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

    /// Contient de la force (et pas seulement du cardio et de la marche).
    public var hasStrength: Bool { exercises.contains { $0.priority < 4 } }
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
    /// Douleur au genou : aucun exercice qui le charge.
    public var kneePain: Bool
    /// En déplacement : pas de matériel, peu de temps.
    public var traveling: Bool
    /// Remplacements demandés : clé de l'exercice → nombre de demandes. Chaque demande passe
    /// à la variante suivante, puis revient à l'exercice d'origine.
    public var exerciseSwaps: [String: Int]
    /// Dernière séance de force faite, pour enchaîner sur la suivante (A puis B).
    public var lastWorkoutTitle: String?
    /// Jour de la dernière séance de force faite : 48 h de récupération avant la suivante.
    public var lastStrengthDay: Date?

    public init(
        availableMinutes: Int? = nil,
        lowEnergy: Bool = false,
        missedToday: Bool = false,
        kneePain: Bool = false,
        traveling: Bool = false,
        exerciseSwaps: [String: Int] = [:],
        lastWorkoutTitle: String? = nil,
        lastStrengthDay: Date? = nil
    ) {
        self.availableMinutes = availableMinutes
        self.lowEnergy = lowEnergy
        self.missedToday = missedToday
        self.kneePain = kneePain
        self.traveling = traveling
        self.exerciseSwaps = exerciseSwaps
        self.lastWorkoutTitle = lastWorkoutTitle
        self.lastStrengthDay = lastStrengthDay
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

/// Série notée par l'utilisateur : la meilleure série d'un exercice, une par séance.
public struct LiftEntry: Sendable, Equatable {
    /// Nom affiché de l'exercice (après remplacement ou adaptation) : chaque variante a ses records.
    public var exercise: String
    public var date: Date
    /// Charge en kg ; `nil` au poids du corps.
    public var kg: Double?
    public var reps: Int

    public init(exercise: String, date: Date, kg: Double?, reps: Int) {
        self.exercise = exercise
        self.date = date
        self.kg = kg
        self.reps = reps
    }
}
