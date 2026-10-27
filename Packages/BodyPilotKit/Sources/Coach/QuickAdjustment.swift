import BodyPilotCore
import Foundation

/// Ajustements déclarés en une touche ou en une phrase.
public enum QuickAdjustment: String, CaseIterable, Sendable, Codable {
    case shortOnTime
    case tired
    case missedWorkout
    case eatingOut
    case notHungry
    case kneePain
    case traveling

    /// Temps disponible par défaut quand l'utilisateur déclare manquer de temps.
    public static let shortOnTimeMinutes = 20

    /// La phrase telle que l'utilisateur la dirait.
    public var phrase: String {
        switch self {
        case .shortOnTime: "Je n'ai que \(Self.shortOnTimeMinutes) minutes"
        case .tired: "Je suis fatigué"
        case .missedWorkout: "J'ai raté ma séance"
        case .eatingOut: "Je mange au restaurant"
        case .notHungry: "Je n'ai pas faim"
        case .kneePain: "J'ai mal au genou"
        case .traveling: "Je pars en déplacement"
        }
    }
}

extension DayConstraints {
    /// - Parameter availableMinutes: temps précis annoncé (« j'ai 15 minutes »), prioritaire sur les 20 minutes par défaut.
    public init(
        today: Set<QuickAdjustment>,
        yesterday: Set<QuickAdjustment> = [],
        availableMinutes: Int? = nil,
        exerciseSwaps: [String: Int] = [:]
    ) {
        self.init(
            availableMinutes: today.contains(.shortOnTime) ? (availableMinutes ?? QuickAdjustment.shortOnTimeMinutes) : nil,
            lowEnergy: today.contains(.tired),
            missedToday: today.contains(.missedWorkout),
            missedYesterday: yesterday.contains(.missedWorkout),
            kneePain: today.contains(.kneePain),
            traveling: today.contains(.traveling),
            exerciseSwaps: exerciseSwaps
        )
    }
}

extension MealConstraints {
    /// Le restaurant concerne le repas précisé, sinon le prochain repas principal :
    /// le déjeuner le matin, le dîner ensuite.
    public init(today: Set<QuickAdjustment>, at date: Date, calendar: Calendar, eatingOutSlot: MealSlot? = nil, eaten: [MealSlot: MealIntake] = [:], described: [MealSlot: DescribedMeal] = [:]) {
        let hour = calendar.component(.hour, from: date)
        self.init(
            eatingOut: today.contains(.eatingOut) ? (eatingOutSlot ?? (hour < 15 ? .lunch : .dinner)) : nil,
            lowAppetite: today.contains(.notHungry),
            eaten: eaten,
            described: described
        )
    }
}
