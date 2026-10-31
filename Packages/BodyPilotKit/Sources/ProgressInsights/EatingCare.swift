import BodyPilotCore
import Foundation

/// Signaux qui accompagnent souvent un trouble alimentaire, observables dans l'app. Aucun ne
/// pose de diagnostic : un seul suffit à proposer de l'aide et une pause du déficit. Seuils
/// choisis par BodyPilot, prudents (voir le doc « Garde-fou troubles alimentaires »).
public enum EatingCareSignal: String, CaseIterable, Sendable {
    /// Au moins 5 journées complètes sur 14 sous 70 % de l'objectif ou sous le plancher.
    case restriction
    /// Au moins 6 repas sautés sur 14 jours.
    case skippedMeals
    /// Plus de 1 % du poids perdu par semaine sur les 3 dernières semaines.
    case rapidLoss
    /// 3 pesées à la main ou plus dans la journée, au moins 3 jours sur 14.
    case frequentWeighing
    /// Culpabilité, honte, compensation dans les phrases, au moins 2 jours sur 14.
    case distressWords
    /// Vomissement provoqué mentionné : message immédiat.
    case purging
}

/// Une journée vue par le garde-fou.
public struct EatingCareDay: Sendable, Equatable {
    public var day: Date
    /// Calories mangées, seulement si les quatre repas sont notés.
    public var completeKcal: Double?
    public var skippedMeals: Int

    public init(day: Date, completeKcal: Double? = nil, skippedMeals: Int = 0) {
        self.day = day
        self.completeKcal = completeKcal
        self.skippedMeals = skippedMeals
    }
}

public enum EatingCare {
    public static let windowDays = 14
    static let restrictionRatio = 0.7
    static let restrictionDays = 5
    static let skippedMeals = 6
    static let rapidLossRatio = 0.01
    static let weighingsPerDay = 3
    static let frequentWeighingDays = 3
    static let distressDaysNeeded = 2
    /// « Ça va, merci » : la carte ne revient pas avant 30 jours.
    public static let snoozeDays = 30
    /// Durée de la pause du déficit.
    public static let pauseDays = 28

    /// - Parameters:
    ///   - targetKcal: objectif du jour, servant de repère pour toutes les journées.
    ///   - floorKcal: plancher de sécurité (1 200 ou 1 500 kcal, ou le métabolisme de base).
    ///   - manualWeighIns: pesées saisies à la main (une balance connectée pèse seule).
    ///   - distressDays / purgingDays: jours où une phrase en a parlé.
    public static func signals(
        days: [EatingCareDay],
        targetKcal: Double,
        floorKcal: Double,
        trend: WeightTrend,
        manualWeighIns: [Date],
        distressDays: [Date],
        purgingDays: [Date],
        on date: Date,
        calendar: Calendar = .current
    ) -> Set<EatingCareSignal> {
        let today = calendar.startOfDay(for: date)
        let start = calendar.date(byAdding: .day, value: -(windowDays - 1), to: today) ?? today
        func inWindow(_ day: Date) -> Bool { let d = calendar.startOfDay(for: day); return d >= start && d <= today }
        let recent = days.filter { inWindow($0.day) }

        var found: Set<EatingCareSignal> = []
        let low = recent.compactMap(\.completeKcal).filter { $0 < max(targetKcal * restrictionRatio, floorKcal) }
        if low.count >= restrictionDays { found.insert(.restriction) }
        if recent.reduce(0, { $0 + $1.skippedMeals }) >= skippedMeals { found.insert(.skippedMeals) }
        if let weekly = trend.weeklyChangeKg, let weight = trend.currentTrendKg, weight > 0, -weekly / weight > rapidLossRatio {
            found.insert(.rapidLoss)
        }
        let perDay = Dictionary(grouping: manualWeighIns.filter(inWindow), by: { calendar.startOfDay(for: $0) })
        if perDay.values.filter({ $0.count >= weighingsPerDay }).count >= frequentWeighingDays { found.insert(.frequentWeighing) }
        if Set(distressDays.filter(inWindow).map { calendar.startOfDay(for: $0) }).count >= distressDaysNeeded { found.insert(.distressWords) }
        if purgingDays.contains(where: inWindow) { found.insert(.purging) }
        return found
    }

    /// Ce qu'une phrase écrite dans l'app laisse entendre. Le texte n'est jamais gardé : seule
    /// la date compte.
    public enum Mention: Sendable, Equatable { case distress, purging }

    public static func mention(in text: String) -> Mention? {
        let normalized = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "fr_FR"))
            .replacingOccurrences(of: "’", with: "'").lowercased()
        func has(_ pattern: String) -> Bool { normalized.range(of: pattern, options: .regularExpression) != nil }
        if has(#"(fait|fais|faire) vomir|me suis fait vomir|vomi expres|me faire vomir"#) { return .purging }
        if has(#"culpabilis|\bhonte\b|me degoute|compenser|me punir|me priver|pas merite"#) { return .distress }
        return nil
    }
}

/// Textes du garde-fou, relus avec Mounaïm (2026-10-31). Ton : fiche HAS « Comment en parler »,
/// sans jugement, sans chiffre, sans poids.
public enum EatingCareText {
    public static let title = "Prenons soin de toi"
    public static let purgingOpening = "Tu as parlé de te faire vomir. Ce que tu vis compte, et ton corps aussi."
    public static let opening = "Ces derniers temps, ton alimentation semble très serrée, ou tu sembles vivre les repas avec difficulté. Ce n'est pas un reproche, et ce n'est pas un diagnostic."
    public static let help = "Si manger, te peser ou compter devient une source de stress, tu n'as pas à le gérer sans aide. En parler à ton médecin, ou à une ligne d'écoute spécialisée, est un bon premier pas."
    public static let pause = "En attendant, je peux mettre ton déficit en pause : tes repas visent ta dépense, sans perte de poids. Tu reprends quand tu veux."

    public static func paragraphs(for signals: Set<EatingCareSignal>) -> [String] {
        [signals.contains(.purging) ? purgingOpening : opening, help, pause]
    }
}
