import Foundation

/// Les 7 questions générales posées avant de reprendre une activité physique, d'après le PAR-Q+
/// (Warburton et al., 2011) et le dépistage simplifié de l'ACSM (Riebe et al., 2015).
public enum ScreeningQuestion: String, CaseIterable, Sendable, Codable {
    case heartCondition
    case chestPain
    case dizziness
    case chronicCondition
    case medication
    case boneOrJoint
    case supervisedOnly

    public var text: String {
        switch self {
        case .heartCondition: "Un médecin t'a-t-il déjà dit que tu as un problème cardiaque ou de l'hypertension ?"
        case .chestPain: "Ressens-tu une douleur à la poitrine au repos, dans la vie de tous les jours ou pendant un effort ?"
        case .dizziness: "As-tu perdu l'équilibre à cause d'un vertige, ou perdu connaissance, ces 12 derniers mois ? (Réponds non si c'était seulement un essoufflement à l'effort.)"
        case .chronicCondition: "As-tu une autre maladie chronique diagnostiquée (diabète, asthme, maladie rénale…) ?"
        case .medication: "Prends-tu un traitement prescrit pour une maladie chronique ?"
        case .boneOrJoint: "As-tu, ou as-tu eu ces 12 derniers mois, un problème d'os, d'articulation, de muscle ou de tendon qu'un effort pourrait aggraver ?"
        case .supervisedOnly: "Un médecin t'a-t-il dit de ne faire du sport que sous surveillance médicale ?"
        }
    }
}

/// Situations où le coach ne fixe jamais de déficit calorique.
public enum NoDeficitSituation: String, CaseIterable, Sendable, Codable {
    /// Grossesse ou allaitement.
    case pregnancy
    /// Trouble du comportement alimentaire, actuel ou passé.
    case eatingDisorder

    public var title: String {
        switch self {
        case .pregnancy: "Enceinte ou allaitante"
        case .eatingDisorder: "Trouble alimentaire, actuel ou passé"
        }
    }
}

/// Réponses au questionnaire de santé. Un « oui » ne bloque pas l'app : il retire les efforts
/// maximaux (tests, fractionné, séries au maximum) jusqu'à l'accord d'un médecin.
public struct HealthScreening: Sendable, Equatable, Codable {
    /// `nil` : jamais répondu (profil créé avant le questionnaire).
    public var answeredAt: Date?
    /// Questions auxquelles la réponse est oui.
    public var yes: Set<ScreeningQuestion>
    public var situations: Set<NoDeficitSituation>
    /// Un médecin a donné son accord pour une activité sans restriction.
    public var medicalClearance: Bool

    /// En dessous, le coach ne fixe pas de déficit : la croissance passe avant.
    public static let adultAge = 18

    public init(answeredAt: Date? = nil, yes: Set<ScreeningQuestion> = [], situations: Set<NoDeficitSituation> = [], medicalClearance: Bool = false) {
        self.answeredAt = answeredAt
        self.yes = yes
        self.situations = situations
        self.medicalClearance = medicalClearance
    }

    public var isAnswered: Bool { answeredAt != nil }

    /// Au moins un oui, sans accord médical : effort modéré seulement.
    public var restrictsIntensity: Bool { !yes.isEmpty && !medicalClearance }
}

extension UserProfile {
    /// Pas de déficit pendant une grossesse ou un allaitement, avec un trouble alimentaire, ni
    /// avant 18 ans : le coach vise l'équilibre et renvoie vers un professionnel de santé.
    public func forbidsDeficit(on date: Date, calendar: Calendar) -> Bool {
        !screening.situations.isEmpty || age(on: date, calendar: calendar) < HealthScreening.adultAge
    }

    /// Pourquoi il n'y a pas de déficit, en quelques mots.
    public func noDeficitReason(on date: Date, calendar: Calendar) -> String? {
        if screening.situations.contains(.pregnancy) { return "grossesse ou allaitement" }
        if screening.situations.contains(.eatingDisorder) { return "trouble alimentaire" }
        if age(on: date, calendar: calendar) < HealthScreening.adultAge { return "moins de 18 ans" }
        return nil
    }
}
