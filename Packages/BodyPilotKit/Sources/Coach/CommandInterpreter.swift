import AIRouter
import BodyPilotCore
import Foundation

/// Ce que le coach a compris d'une phrase libre.
public struct InterpretedCommand: Sendable, Equatable {
    public var adjustments: Set<QuickAdjustment>
    /// Temps annoncé (« j'ai 15 min »), s'il y en a un.
    public var availableMinutes: Int?
    /// Repas précisé pour le restaurant (« ce soir », « ce midi »).
    public var eatingOutSlot: MealSlot?
    /// Niveau de traitement utilisé, pour mesurer le coût.
    public var tier: AITier

    public var isUnderstood: Bool { !adjustments.isEmpty }

    public init(adjustments: Set<QuickAdjustment>, availableMinutes: Int? = nil, eatingOutSlot: MealSlot? = nil, tier: AITier) {
        self.adjustments = adjustments
        self.availableMinutes = availableMinutes
        self.eatingOutSlot = eatingOutSlot
        self.tier = tier
    }
}

/// Proposition brute d'un modèle de langage, avant contrôle par les règles du coach.
public struct CommandDraft: Sendable, Equatable {
    public var adjustments: Set<QuickAdjustment>
    public var availableMinutes: Int?
    public var eatingOutSlot: MealSlot?

    public init(adjustments: Set<QuickAdjustment>, availableMinutes: Int? = nil, eatingOutSlot: MealSlot? = nil) {
        self.adjustments = adjustments
        self.availableMinutes = availableMinutes
        self.eatingOutSlot = eatingOutSlot
    }
}

/// Modèle de langage capable de lire une phrase libre (Foundation Models sur l'iPhone).
/// Implémenté dans l'app : le package reste indépendant du fournisseur.
public protocol CommandLanguageModel: Sendable {
    func draft(for text: String) async throws -> CommandDraft
}

/// Transforme « je mange au resto ce soir et j'ai mal au genou » en ajustements.
///
/// Passe par l'AIRouter : le niveau déterministe (mots-clés) couvre les phrases courantes,
/// gratuitement et hors ligne. Si rien n'est reconnu, un modèle embarqué prend le relais,
/// jamais le cloud ; sa réponse repasse par les mêmes bornes que les mots-clés.
public struct CommandInterpreter: Sendable {
    public static let feature = "command-parsing"
    /// Au-delà, la phrase n'est pas un ajustement du jour : inutile de solliciter le modèle.
    static let maxModelInputLength = 280

    public var router: AIRouter
    public var model: (any CommandLanguageModel)?

    public init(router: AIRouter = AIRouter(availableTiers: [.deterministic]), model: (any CommandLanguageModel)? = nil) {
        self.router = router
        self.model = model
    }

    /// Mots-clés seuls : instantané, sans modèle.
    public func interpret(_ text: String) -> InterpretedCommand? {
        let request = AIRequest(feature: Self.feature, minimumTier: .deterministic)
        guard case .route(let tier) = router.route(request, usage: AIUsageSnapshot()), tier == .deterministic else {
            return nil
        }
        return KeywordParser.parse(text)
    }

    /// Mots-clés d'abord, puis le modèle embarqué pour les tournures qu'ils ne couvrent pas.
    public func understand(_ text: String) async -> InterpretedCommand? {
        let keywords = interpret(text)
        if let keywords, keywords.isUnderstood { return keywords }
        guard let model, text.count <= Self.maxModelInputLength,
              case .route(let tier) = router.route(AIRequest(feature: Self.feature, minimumTier: .onDevice), usage: AIUsageSnapshot()),
              tier == .onDevice,
              let draft = try? await model.draft(for: text)
        else { return keywords }
        return Self.checked(draft, tier: tier)
    }

    /// Mêmes bornes que les mots-clés : temps entre 5 et 120 min, repas seulement si restaurant.
    static func checked(_ draft: CommandDraft, tier: AITier) -> InterpretedCommand {
        var adjustments = draft.adjustments
        let minutes = draft.availableMinutes.flatMap { (5...120).contains($0) ? $0 : nil }
        if minutes != nil { adjustments.insert(.shortOnTime) }
        let slot = adjustments.contains(.eatingOut) ? draft.eatingOutSlot.flatMap { $0 == .lunch || $0 == .dinner ? $0 : nil } : nil
        return InterpretedCommand(adjustments: adjustments, availableMinutes: minutes, eatingOutSlot: slot, tier: tier)
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
        Rule(.sore, [#"courbatu"#, #"mal aux (jambes|cuisses|bras|pecs|muscles)"#]),
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
        var slot: MealSlot?
        if found.contains(.eatingOut) {
            if matches(#"\bsoir\b|\bdiner\b|\bdine\b"#, in: normalized) {
                slot = .dinner
            } else if matches(#"\bmidi\b|\bdejeuner\b|\bdejeune\b"#, in: normalized) {
                slot = .lunch
            }
        }
        return InterpretedCommand(adjustments: found, availableMinutes: minutes, eatingOutSlot: slot, tier: .deterministic)
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
