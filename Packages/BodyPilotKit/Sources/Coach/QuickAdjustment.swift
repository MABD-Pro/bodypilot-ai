import BodyPilotCore

/// Ajustements déclarés en une touche. D'autres suivront (restaurant, douleur, déplacement…).
public enum QuickAdjustment: String, CaseIterable, Sendable, Codable {
    case shortOnTime
    case tired
    case missedWorkout

    /// Temps disponible quand l'utilisateur déclare manquer de temps.
    public static let shortOnTimeMinutes = 20

    /// La phrase telle que l'utilisateur la dirait.
    public var phrase: String {
        switch self {
        case .shortOnTime: "Je n'ai que \(Self.shortOnTimeMinutes) minutes"
        case .tired: "Je suis fatigué"
        case .missedWorkout: "J'ai raté ma séance"
        }
    }
}

extension DayConstraints {
    public init(today: Set<QuickAdjustment>, yesterday: Set<QuickAdjustment> = []) {
        self.init(
            availableMinutes: today.contains(.shortOnTime) ? QuickAdjustment.shortOnTimeMinutes : nil,
            lowEnergy: today.contains(.tired),
            missedToday: today.contains(.missedWorkout),
            missedYesterday: yesterday.contains(.missedWorkout)
        )
    }
}
