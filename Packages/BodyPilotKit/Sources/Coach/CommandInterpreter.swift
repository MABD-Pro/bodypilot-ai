import AIRouter
import Foundation

/// Ce que le coach a compris d'une phrase libre.
public struct InterpretedCommand: Sendable, Equatable {
    public var adjustments: Set<QuickAdjustment>
    /// Temps annoncé (« j'ai 15 min »), s'il y en a un.
    public var availableMinutes: Int?
    /// Niveau de traitement utilisé, pour mesurer le coût.
    public var tier: AITier

    public var isUnderstood: Bool { !adjustments.isEmpty }

    public init(adjustments: Set<QuickAdjustment>, availableMinutes: Int? = nil, tier: AITier) {
        self.adjustments = adjustments
        self.availableMinutes = availableMinutes
        self.tier = tier
    }
}

/// Transforme « je mange au resto ce soir et j'ai mal au genou » en ajustements.
///
/// Passe par l'AIRouter : le niveau déterministe (mots-clés) couvre les phrases courantes,
/// gratuitement et hors ligne. Un modèle embarqué pourra prendre le relais pour les autres.
public struct CommandInterpreter: Sendable {
    public static let feature = "command-parsing"

    public var router: AIRouter

    public init(router: AIRouter = AIRouter(availableTiers: [.deterministic])) {
        self.router = router
    }

    public func interpret(_ text: String) -> InterpretedCommand? {
        let request = AIRequest(feature: Self.feature, minimumTier: .deterministic)
        guard case .route(let tier) = router.route(request, usage: AIUsageSnapshot()), tier == .deterministic else {
            return nil
        }
        return KeywordParser.parse(text)
    }
}

/// Analyse par mots-clés, en français, insensible aux accents et à la casse.
enum KeywordParser {
    private struct Rule: Sendable {
        let adjustment: QuickAdjustment
        let patterns: [String]

        init(_ adjustment: QuickAdjustment, _ patterns: [String]) {
            self.adjustment = adjustment
            self.patterns = patterns
        }
    }

    private static let rules: [Rule] = [
        Rule(.shortOnTime, [#"\b\d{1,3} ?(min|minutes?|mn)\b"#, #"pas (le|beaucoup de) temps"#, #"peu de temps"#, #"\bpresse"#, #"journee chargee"#]),
        Rule(.tired, [#"fatigu"#, #"\bcreve"#, #"epuise"#, #"mal dormi"#, #"pas (beaucoup )?dormi"#, #"\bnaze"#, #"\bko\b"#, #"pas en forme"#, #"\bclaque"#]),
        Rule(.missedWorkout, [#"\brate"#, #"\bloupe"#, #"manque (ma|la|mon) (seance|entrainement|sport)"#, #"pas pu (faire|m'entrainer|aller)"#, #"saute (ma|la) seance"#]),
        Rule(.eatingOut, [#"\brestau"#, #"\bresto"#, #"\bbrasserie"#, #"\bpizzeria"#, #"\binvite"#, #"repas (d'affaires|de famille|entre amis)"#, #"mange dehors"#, #"\bfast.?food"#]),
        Rule(.notHungry, [#"pas faim"#, #"peu faim"#, #"pas d'appetit"#, #"aucun appetit"#, #"coupe.? l'appetit"#]),
        Rule(.kneePain, [#"genou"#]),
        Rule(.traveling, [#"deplacement"#, #"\bvoyage"#, #"\bhotel"#, #"\bvacances"#, #"je pars en\b"#, #"\bavion\b"#, #"\btrain\b"#, #"\bmission\b"#]),
    ]

    static func parse(_ text: String) -> InterpretedCommand {
        let normalized = normalize(text)
        var found: Set<QuickAdjustment> = []
        for rule in rules where rule.patterns.contains(where: { matches($0, in: normalized) }) {
            found.insert(rule.adjustment)
        }
        // « train » seul est ambigu (« en train de… ») : on l'ignore dans cette tournure.
        if found.contains(.traveling), matches(#"en train de"#, in: normalized), !matches(#"deplacement|voyage|hotel|avion|vacances|je pars en|mission"#, in: normalized) {
            found.remove(.traveling)
        }
        let minutes = firstMinutes(in: normalized)
        if minutes != nil { found.insert(.shortOnTime) }
        return InterpretedCommand(adjustments: found, availableMinutes: minutes, tier: .deterministic)
    }

    static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "fr_FR"))
            .replacingOccurrences(of: "’", with: "'")
            .lowercased()
    }

    private static func matches(_ pattern: String, in text: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }

    /// « 15 min », « 25 minutes » : borné entre 5 et 120 pour écarter les valeurs absurdes.
    private static func firstMinutes(in text: String) -> Int? {
        guard let range = text.range(of: #"\b\d{1,3} ?(min|minutes?|mn)\b"#, options: .regularExpression) else { return nil }
        let digits = text[range].prefix { $0.isNumber }
        guard let value = Int(digits), (5...120).contains(value) else { return nil }
        return value
    }
}
