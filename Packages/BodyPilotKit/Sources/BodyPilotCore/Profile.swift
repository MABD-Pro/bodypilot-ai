import Foundation

public enum BiologicalSex: String, CaseIterable, Sendable, Codable {
    case female
    case male
}

/// Niveau d'activité quotidien, séances comprises.
public enum ActivityLevel: String, CaseIterable, Sendable, Codable {
    case sedentary
    case light
    case moderate
    case active

    /// Multiplicateur du métabolisme de base pour la vie quotidienne, hors sport : les séances
    /// s'ajoutent à part, d'après celles vraiment faites (`ExerciseEnergy`).
    public var factor: Double {
        switch self {
        case .sedentary: 1.2
        case .light: 1.3
        case .moderate: 1.4
        case .active: 1.55
        }
    }
}

public enum Goal: String, CaseIterable, Sendable, Codable {
    case loseFat
    case maintain
    case buildMuscle
    /// Perdre du gras et gagner du muscle en même temps : l'objectif par défaut.
    /// Le déficit dépend de l'écart au poids visé ; le progrès se lit aussi au tour de taille.
    case recomposition
}

public enum Equipment: String, CaseIterable, Sendable, Codable {
    /// Poids du corps, à la maison ou en déplacement.
    case bodyweight
    /// Salle de sport (haltères, poulies).
    case gym
}

/// Profil minimal nécessaire au coach. Tout le reste est déduit ou appris.
public struct UserProfile: Sendable, Equatable, Codable {
    public var id: EntityID
    public var sex: BiologicalSex
    public var birthDate: Date
    public var heightCm: Double
    /// Poids déclaré à l'inscription ; la tendance mesurée prend le relais ensuite.
    public var startWeightKg: Double
    public var targetWeightKg: Double?
    public var activity: ActivityLevel
    public var goal: Goal
    /// Jours de séance choisis (1 = dimanche … 7 = samedi, comme `Calendar`), triés.
    public var trainingWeekdays: [Int]
    public var sessionMinutes: Int
    public var equipment: Equipment
    /// Correction décidée lors des bilans hebdomadaires (kcal/jour), appliquée dans les limites de sécurité.
    public var calorieAdjustmentKcal: Double
    /// Questionnaire de santé : limite l'intensité ou le déficit si besoin.
    public var screening: HealthScreening
    /// Moyenne de pas mesurée dans Santé (14 jours) ; remplace le niveau déclaré pour la vie
    /// quotidienne. `nil` : pas assez de jours mesurés, ou Santé non relié.
    public var averageDailySteps: Double?

    /// Niveau d'activité retenu : celui des pas mesurés, sinon celui déclaré.
    public var dailyActivity: ActivityLevel {
        averageDailySteps.map(ActivityLevel.init(averageSteps:)) ?? activity
    }

    public init(
        id: EntityID = EntityID(),
        sex: BiologicalSex,
        birthDate: Date,
        heightCm: Double,
        startWeightKg: Double,
        targetWeightKg: Double? = nil,
        activity: ActivityLevel,
        goal: Goal,
        trainingDaysPerWeek: Int,
        trainingWeekdays: [Int]? = nil,
        sessionMinutes: Int,
        equipment: Equipment,
        calorieAdjustmentKcal: Double = 0,
        screening: HealthScreening = HealthScreening()
    ) {
        self.id = id
        self.sex = sex
        self.birthDate = birthDate
        self.heightCm = heightCm
        self.startWeightKg = startWeightKg
        self.targetWeightKg = targetWeightKg
        self.activity = activity
        self.goal = goal
        self.trainingWeekdays = Self.normalized(trainingWeekdays ?? Self.defaultTrainingWeekdays(count: trainingDaysPerWeek))
        self.sessionMinutes = sessionMinutes
        self.equipment = equipment
        self.calorieAdjustmentKcal = calorieAdjustmentKcal
        self.screening = screening
    }

    public var trainingDaysPerWeek: Int { trainingWeekdays.count }

    /// Répartition par défaut, avec des jours de récupération entre les séances.
    public static func defaultTrainingWeekdays(count: Int) -> [Int] {
        switch min(max(count, 1), 6) {
        case 1: [4]
        case 2: [2, 5]
        case 3: [2, 4, 6]
        case 4: [2, 3, 5, 6]
        case 5: [2, 3, 4, 6, 7]
        default: [2, 3, 4, 5, 6, 7]
        }
    }

    /// Jours valides, sans doublon. Le rythme habituel garde au moins un jour ; une semaine
    /// donnée peut n'en avoir aucun (vacances, semaine chargée).
    public static func normalized(_ weekdays: [Int], allowEmpty: Bool = false) -> [Int] {
        let valid = Set(weekdays.filter { (1...7).contains($0) }).sorted()
        return valid.isEmpty && !allowEmpty ? defaultTrainingWeekdays(count: 1) : valid
    }

    public func age(on date: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.year], from: birthDate, to: date).year ?? 0
    }
}
