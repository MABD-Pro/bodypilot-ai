import AIRouter
import BodyPilotCore
import Foundation

/// Débrief du soir en une phrase : « séance faite, pizza ce soir, je suis crevé ». Le coach en tire
/// ce qui a été mangé, si la séance est faite, et de quoi partir demain. Rien n'est enregistré
/// sans que l'utilisateur le confirme.
public struct EveningDebrief: Sendable, Equatable {
    /// `true` séance faite, `false` séance ratée, `nil` non mentionnée.
    public var workoutDone: Bool?
    /// Repas mentionnés (ou tous les repas restants pour « comme prévu »).
    public var meals: [MealSlot: MealIntake]
    /// Ressenti qui servira de point de départ demain : fatigue, courbatures, genou.
    public var tomorrow: Set<QuickAdjustment>
    public var tier: AITier

    public var isUnderstood: Bool { workoutDone != nil || !meals.isEmpty || !tomorrow.isEmpty }

    public init(workoutDone: Bool? = nil, meals: [MealSlot: MealIntake] = [:], tomorrow: Set<QuickAdjustment> = [], tier: AITier = .deterministic) {
        self.workoutDone = workoutDone
        self.meals = meals
        self.tomorrow = tomorrow
        self.tier = tier
    }

    /// Le débrief s'ouvre à 18 h (avant, la journée n'est pas finie) et reste ouvert jusqu'à 4 h :
    /// après minuit, c'est encore la veille qu'on raconte.
    public static let opensAtHour = 18
    public static let closesAtHour = 4

    /// Jour raconté par un débrief fait à `date`, ou `nil` hors de la plage 18 h – 4 h.
    public static func day(for date: Date, calendar: Calendar) -> Date? {
        let hour = calendar.component(.hour, from: date)
        if hour >= opensAtHour { return calendar.startOfDay(for: date) }
        if hour < closesAtHour { return calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: date)) }
        return nil
    }

    /// Ce qui a été compris, en morceaux courts à confirmer.
    public var understoodLines: [String] { understoodLines(nextDay: "Demain") }

    /// - Parameter nextDay: « Demain », ou « Aujourd'hui » quand on raconte la veille après minuit.
    public func understoodLines(nextDay: String) -> [String] {
        var lines: [String] = []
        switch workoutDone {
        case true?: lines.append("Séance faite")
        case false?: lines.append("Séance pas faite")
        case nil: break
        }
        for slot in MealSlot.allCases {
            guard let intake = meals[slot] else { continue }
            lines.append("\(Self.slotName(slot)) : \(Self.intakeName(intake))")
        }
        if !tomorrow.isEmpty {
            let names = QuickAdjustment.allCases.filter(tomorrow.contains).map(Self.tomorrowName)
            lines.append("\(nextDay) : \(names.joined(separator: ", "))")
        }
        return lines
    }

    /// Réponse du coach en une phrase, sans reproche.
    public var coachReply: String {
        var parts: [String] = []
        if workoutDone == true { parts.append("Séance faite, c'est ce qui compte le plus.") }
        if workoutDone == false { parts.append("Pas de séance aujourd'hui : demain, le coach te propose la suivante, sans rattrapage.") }
        let generous = meals.values.contains { $0 == .hearty || $0 == .veryHearty }
        if generous {
            parts.append("Un repas copieux ne change rien à la tendance : demain, on reprend simplement le plan, sans compenser.")
        } else if !meals.isEmpty, meals.values.allSatisfy({ $0 == .asPlanned }) {
            parts.append("Repas tenus, belle journée.")
        } else if meals.values.contains(where: { $0 == .light || $0 == .skipped }) {
            parts.append("Repas plus léger : pense à tes protéines au prochain, sans forcer.")
        }
        if tomorrow.contains(.kneePain) {
            parts.append("Prochaine séance : on ménage ton genou.")
        } else if tomorrow.contains(.tired) || tomorrow.contains(.sore) {
            parts.append("Prochaine séance : elle tiendra compte de ton état.")
        }
        return parts.isEmpty ? "Noté. Bonne soirée." : parts.joined(separator: " ")
    }

    static func slotName(_ slot: MealSlot) -> String {
        switch slot {
        case .breakfast: "Petit-déjeuner"
        case .lunch: "Déjeuner"
        case .snack: "Collation"
        case .dinner: "Dîner"
        }
    }

    static func intakeName(_ intake: MealIntake) -> String {
        switch intake {
        case .skipped: "sauté"
        case .light: "léger"
        case .asPlanned: "comme prévu"
        case .hearty: "copieux"
        case .veryHearty: "très copieux"
        }
    }

    static func tomorrowName(_ adjustment: QuickAdjustment) -> String {
        switch adjustment {
        case .tired: "fatigué"
        case .sore: "courbatures"
        case .kneePain: "genou à ménager"
        default: adjustment.phrase.lowercased()
        }
    }
}

/// Analyse du débrief par mots-clés, comme `CommandInterpreter` : local et instantané.
public enum EveningDebriefParser {
    /// - Parameter pendingSlots: repas pas encore notés aujourd'hui, ceux que « comme prévu » coche.
    public static func parse(_ text: String, pendingSlots: Set<MealSlot>) -> EveningDebrief {
        let normalized = KeywordParser.normalize(text)
        func has(_ pattern: String) -> Bool { normalized.range(of: pattern, options: .regularExpression) != nil }

        var debrief = EveningDebrief()

        // Séance : la négation d'abord (« pas fait ma séance » contient « fait ma séance »).
        let sport = #"(seance|entrainement|sport|muscu|salle|footing|course|velo|cardio)"#
        if has(#"pas (fait|eu le temps|pu)[^.,]*"# + sport) || has(#"\b(rate|loupe|saute|zappe)[^.,]*"# + sport) || has(#"pas de "# + sport) {
            debrief.workoutDone = false
        } else if has(#"\b(fait|fini|termine|boucle|reussi)[^.,]*"# + sport) || has(sport + #"[^.,]* (faite?|finie?|terminee?|ok)\b"#)
            || has(#"\b(couru|nage|pedale)\b"#) || has(#"je me suis (bien )?entraine"#) {
            debrief.workoutDone = true
        }

        // Repas : un écart nommé l'emporte sur « comme prévu » pour son repas.
        if has(#"comme prevu|suivi le plan|tout suivi|repas ok|bien mange|mange (correct|normal)"#) {
            for slot in pendingSlots { debrief.meals[slot] = .asPlanned }
        }
        let slot = mentionedSlot(in: normalized)
        if has(#"pas (dine|mange ce soir|dejeune)|saute (le |mon )?(diner|dejeuner|repas|petit.?dej)|rien mange"#) {
            debrief.meals[slot] = .skipped
        } else if has(#"(enorme|beaucoup trop|trop trop|gros(se)? (craquage|exces))"#) {
            debrief.meals[slot] = .veryHearty
        } else if has(#"\b(craque|ecart|exces|trop mange|copieux|pizza|burger|kebab|tacos|fast.?food|apero|restau|resto|buffet|raclette|fondue|frites)"#) {
            debrief.meals[slot] = .hearty
        } else if has(#"\b(leger|legerement|peu mange|pas beaucoup mange|petite faim|grignote)"#) {
            debrief.meals[slot] = .light
        }

        // Pour demain : seulement ce qui change la séance.
        let feelings = KeywordParser.parse(text).adjustments
        debrief.tomorrow = feelings.intersection([.tired, .sore, .kneePain])
        return debrief
    }

    /// Repas nommé dans la phrase ; le dîner par défaut, le soir étant le moment du débrief.
    static func mentionedSlot(in normalized: String) -> MealSlot {
        func has(_ pattern: String) -> Bool { normalized.range(of: pattern, options: .regularExpression) != nil }
        if has(#"petit.?dej"#) { return .breakfast }
        if has(#"\b(midi|dejeuner|dejeune)\b"#) { return .lunch }
        if has(#"\b(collation|gouter|encas)\b"#) { return .snack }
        return .dinner
    }
}
