import BodyPilotCore
import Foundation

/// Comment la semaine a été vécue, en une touche.
public enum WeekMood: String, Sendable, CaseIterable, Codable {
    case hard
    case soso
    case good
    case great

    public var label: String {
        switch self {
        case .hard: "Difficile"
        case .soso: "Moyenne"
        case .good: "Bonne"
        case .great: "Excellente"
        }
    }

    public var symbol: String {
        switch self {
        case .hard: "cloud.rain.fill"
        case .soso: "cloud.sun.fill"
        case .good: "sun.max.fill"
        case .great: "sparkles"
        }
    }
}

/// Ce qui a coincé dans la semaine. L'ordre des cas est l'ordre de priorité.
public enum WeekObstacle: String, Sendable, CaseIterable, Codable {
    case pain
    case fatigue
    case hunger
    case motivation
    case time
    case eatingOut

    public var label: String {
        switch self {
        case .pain: "Douleurs"
        case .fatigue: "Fatigue"
        case .hunger: "Faim"
        case .motivation: "Motivation"
        case .time: "Manque de temps"
        case .eatingOut: "Repas dehors"
        }
    }

    public var symbol: String {
        switch self {
        case .pain: "bandage.fill"
        case .fatigue: "battery.25percent"
        case .hunger: "fork.knife"
        case .motivation: "flame"
        case .time: "clock.fill"
        case .eatingOut: "wineglass.fill"
        }
    }
}

/// Le ressenti d'une semaine du calendrier.
public struct WeekFeeling: Sendable, Equatable, Codable {
    public var mood: WeekMood
    public var obstacles: Set<WeekObstacle>

    public init(mood: WeekMood, obstacles: Set<WeekObstacle> = []) {
        self.mood = mood
        self.obstacles = obstacles
    }
}

/// Sujet d'un conseil de la semaine : deux conseils sur le même sujet ne se cumulent pas.
public enum AdviceTopic: Sendable, Hashable {
    case strength
    case logging
    case protein
    case kcalOver
    case kcalUnder
    case fiber
    case endurance
    case steps
    case none
    case obstacle(WeekObstacle)
    case mood
}

public struct WeekAdvice: Sendable, Equatable {
    public var topic: AdviceTopic
    public var text: String

    public init(_ topic: AdviceTopic, _ text: String) {
        self.topic = topic
        self.text = text
    }
}

extension WeekReviewer {
    static let maxPriorities = 3
    /// Au plus deux priorités tirées du ressenti : la troisième vient des chiffres de la semaine.
    static let maxObstaclePriorities = 2

    /// Les 3 priorités de la semaine qui vient : d'abord ce qui a coincé (ressenti), puis ce que
    /// montrent les chiffres. Sans ressenti, ce sont les conseils de la semaine.
    public func priorities(_ review: WeekReview, feeling: WeekFeeling?) -> [WeekAdvice] {
        guard let feeling else { return Array(review.weekAdvice.prefix(Self.maxPriorities)) }
        var result: [WeekAdvice] = WeekObstacle.allCases
            .filter(feeling.obstacles.contains)
            .prefix(Self.maxObstaclePriorities)
            .map { WeekAdvice(.obstacle($0), Self.priority(for: $0)) }
        if result.isEmpty, feeling.mood == .hard {
            result.append(WeekAdvice(.mood, "Semaine difficile : on vise le minimum qui compte. Deux séances de force, même courtes, et tes repas notés d'une touche. Le reste est du bonus."))
        }
        // Les sujets déjà couverts par le ressenti ne reviennent pas sous une autre forme.
        let covered = Set(result.flatMap { Self.covers($0.topic) })
        let rest = review.weekAdvice.filter { $0.topic != .none && !covered.contains($0.topic) }
        result += rest.prefix(Self.maxPriorities - result.count)
        if result.isEmpty, let first = review.weekAdvice.first {
            result.append(first)
        }
        return result
    }

    static func priority(for obstacle: WeekObstacle) -> String {
        switch obstacle {
        case .pain:
            "Douleurs : dis-le au coach (« mal au genou ») pour adapter les exercices. Une douleur qui dure plus d'une semaine ou qui augmente mérite l'avis d'un professionnel de santé."
        case .fatigue:
            "Fatigue : vise au moins 7 h de sommeil, le minimum recommandé aux adultes par l'American Academy of Sleep Medicine. Les jours sans énergie, touche « Fatigué » : la séance s'allège au lieu de sauter."
        case .hunger:
            "Faim : commence chaque repas par la protéine et une grosse portion de légumes, et garde la collation. Si la faim reste forte, le bilan de poids dira si le déficit est trop serré."
        case .motivation:
            "Motivation : un seul objectif cette semaine, deux séances de force, même de 20 min. Une séance courte faite vaut mieux qu'une longue repoussée."
        case .time:
            "Temps : indique le matin le temps dont tu disposes (« 20 min ») ; le coach garde l'essentiel de la séance. Les jours chargés, une marche de 10 min après un repas compte aussi."
        case .eatingOut:
            "Repas dehors : dis-le le matin (« ce soir resto »), les autres repas s'ajustent. Au restaurant, une protéine en plat principal et des légumes en accompagnement."
        }
    }

    /// Sujets de conseils que remplace une priorité du ressenti.
    static func covers(_ topic: AdviceTopic) -> [AdviceTopic] {
        switch topic {
        case .obstacle(.motivation), .mood: [.strength]
        case .obstacle(.hunger): [.protein]
        case .obstacle(.time): [.steps]
        default: []
        }
    }
}
