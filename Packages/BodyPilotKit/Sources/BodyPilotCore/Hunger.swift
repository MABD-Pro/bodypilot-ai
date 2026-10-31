import Foundation

/// Faim notée d'une touche, au moment où elle arrive.
public enum HungerLevel: Int, CaseIterable, Sendable, Codable {
    case peckish = 1
    case hungry = 2
    case starving = 3

    public var label: String {
        switch self {
        case .peckish: "Petite faim"
        case .hungry: "Faim"
        case .starving: "Très faim"
        }
    }
}

public struct HungerNote: Sendable, Equatable, Codable {
    public var date: Date
    public var level: HungerLevel

    public init(date: Date, level: HungerLevel) {
        self.date = date
        self.level = level
    }
}
