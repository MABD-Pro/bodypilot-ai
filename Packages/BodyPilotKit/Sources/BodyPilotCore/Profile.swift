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

    /// Multiplicateur appliqué au métabolisme de base pour estimer la dépense journalière.
    public var factor: Double {
        switch self {
        case .sedentary: 1.2
        case .light: 1.375
        case .moderate: 1.55
        case .active: 1.725
        }
    }
}

public enum Goal: String, CaseIterable, Sendable, Codable {
    case loseFat
    case maintain
    case buildMuscle
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
    public var trainingDaysPerWeek: Int
    public var sessionMinutes: Int
    public var equipment: Equipment

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
        sessionMinutes: Int,
        equipment: Equipment
    ) {
        self.id = id
        self.sex = sex
        self.birthDate = birthDate
        self.heightCm = heightCm
        self.startWeightKg = startWeightKg
        self.targetWeightKg = targetWeightKg
        self.activity = activity
        self.goal = goal
        self.trainingDaysPerWeek = trainingDaysPerWeek
        self.sessionMinutes = sessionMinutes
        self.equipment = equipment
    }

    public func age(on date: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.year], from: birthDate, to: date).year ?? 0
    }
}
