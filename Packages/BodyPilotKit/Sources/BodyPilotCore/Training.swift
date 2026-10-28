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
    /// Charge visée en part du max estimé, fixée par la semaine du cycle ; `nil` : surcharge progressive.
    public var percentOfMax: Double? = nil

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
    /// Séance de test des charges : chaque exercice monte par paliers jusqu'à une série de 5.
    public var isStrengthTest = false
    /// Test de cardio : marche la plus rapide possible sur 1,6 km, temps et pouls notés à l'arrivée.
    public var isCardioTest = false

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
    /// Repos complet.
    case rest
}

/// Ce que l'utilisateur peut faire aujourd'hui : chaque jour, 2 ou 3 activités plus le repos.
public enum TrainingChoice: String, Sendable, Codable, CaseIterable {
    /// Force lourde en full body (ou test de force), si la dernière date d'au moins 48 h.
    case strength
    /// Cardio modéré puis marche inclinée.
    case conditioning
    /// Marche tranquille.
    case light
    case rest
}

/// Une proposition du jour, prête à suivre.
public struct TrainingOption: Sendable, Equatable {
    public var choice: TrainingChoice
    public var day: TrainingDay

    public init(choice: TrainingChoice, day: TrainingDay) {
        self.choice = choice
        self.day = day
    }
}

/// Les propositions du jour et celle que le coach recommande, avec sa raison en clair.
public struct TrainingOptions: Sendable, Equatable {
    public var options: [TrainingOption]
    public var recommended: TrainingChoice
    public var reason: String

    public init(options: [TrainingOption], recommended: TrainingChoice, reason: String) {
        self.options = options
        self.recommended = recommended
        self.reason = reason
    }

    public func option(_ choice: TrainingChoice) -> TrainingOption? {
        options.first { $0.choice == choice }
    }
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
    /// Exercices dont une charge est déjà notée. Les mouvements de référence absents sont
    /// d'abord testés ; `nil` : pas de calibrage.
    public var calibratedLifts: Set<String>?
    /// Courbatures déclarées le matin.
    public var sore: Bool
    /// Sommeil de la nuit passée, lu dans Santé.
    public var sleepHours: Double?
    /// Jours (début de journée) avec une séance faite, dans l'app ou enregistrée dans Santé.
    public var activeDays: Set<Date>
    /// Activités enregistrées dans Santé ces derniers jours (cours collectif, course…).
    public var recentActivities: [ActivitySample]
    /// Proposition choisie par l'utilisateur ; `nil` : celle que le coach recommande.
    public var choice: TrainingChoice?
    /// Forme cardio : test à faire, zone de cardio modéré.
    public var cardio: CardioStatus
    /// Semaine du cycle de 12 semaines en cours ; `nil` : pas de cycle.
    public var cycleWeek: CycleWeek?
    /// Séances faites depuis le début de la semaine du cycle (titres), pour placer le fractionné.
    public var cycleWorkoutsThisWeek: [String]
    /// Séances prévues cette semaine du cycle ; `nil` : le coach décide au jour le jour.
    public var cyclePlan: CycleSessionPlan?

    public init(
        availableMinutes: Int? = nil,
        lowEnergy: Bool = false,
        missedToday: Bool = false,
        kneePain: Bool = false,
        traveling: Bool = false,
        exerciseSwaps: [String: Int] = [:],
        lastWorkoutTitle: String? = nil,
        lastStrengthDay: Date? = nil,
        calibratedLifts: Set<String>? = nil,
        sore: Bool = false,
        sleepHours: Double? = nil,
        activeDays: Set<Date> = [],
        recentActivities: [ActivitySample] = [],
        choice: TrainingChoice? = nil,
        cardio: CardioStatus = CardioStatus(),
        cycleWeek: CycleWeek? = nil,
        cycleWorkoutsThisWeek: [String] = [],
        cyclePlan: CycleSessionPlan? = nil
    ) {
        self.availableMinutes = availableMinutes
        self.lowEnergy = lowEnergy
        self.missedToday = missedToday
        self.kneePain = kneePain
        self.traveling = traveling
        self.exerciseSwaps = exerciseSwaps
        self.lastWorkoutTitle = lastWorkoutTitle
        self.lastStrengthDay = lastStrengthDay
        self.calibratedLifts = calibratedLifts
        self.sore = sore
        self.sleepHours = sleepHours
        self.activeDays = activeDays
        self.recentActivities = recentActivities
        self.choice = choice
        self.cardio = cardio
        self.cycleWeek = cycleWeek
        self.cycleWorkoutsThisWeek = cycleWorkoutsThisWeek
        self.cyclePlan = cyclePlan
    }
}

/// D'où vient une mesure de forme cardio.
public enum CardioSource: String, Sendable, Codable {
    /// « Forme cardio » estimée par l'Apple Watch pendant les marches et courses en extérieur.
    case watch
    /// Test de marche de 1,6 km fait dans l'app.
    case walkTest
}

/// Forme cardio mesurée : VO2max en ml/kg/min.
public struct CardioMeasure: Sendable, Equatable {
    public var vo2max: Double
    public var date: Date
    public var source: CardioSource

    public init(vo2max: Double, date: Date, source: CardioSource) {
        self.vo2max = vo2max
        self.date = date
        self.source = source
    }
}

/// Ce que le coach sait de la forme cardio pour proposer la séance du jour.
public struct CardioStatus: Sendable, Equatable {
    /// Aucune mesure récente : un jour de cardio devient le test de marche.
    public var testDue: Bool
    /// Fréquence cardiaque du cardio modéré (battements par minute), si l'âge est connu.
    public var moderateHeartRate: ClosedRange<Int>?

    public init(testDue: Bool = false, moderateHeartRate: ClosedRange<Int>? = nil) {
        self.testDue = testDue
        self.moderateHeartRate = moderateHeartRate
    }
}

public protocol TrainingPlanning: Sendable {
    /// Les propositions du jour, la recommandée en tête.
    func options(for profile: UserProfile, on date: Date, constraints: DayConstraints) -> TrainingOptions
    /// La séance retenue : le choix de l'utilisateur, sinon la recommandation.
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
    /// Série de test (calibrage) : une série de 5 au maximum, plus lourde que les charges de travail.
    public var isTest: Bool

    public init(exercise: String, date: Date, kg: Double?, reps: Int, isTest: Bool = false) {
        self.exercise = exercise
        self.date = date
        self.kg = kg
        self.reps = reps
        self.isTest = isTest
    }
}
