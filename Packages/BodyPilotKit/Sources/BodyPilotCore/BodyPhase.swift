import Foundation

/// Phase choisie par le coach : l'utilisateur garde un seul objectif (perdre du gras, gagner du
/// muscle), le coach décide s'il faut un déficit, l'équilibre ou un léger surplus.
///
/// La recomposition en déficit marche surtout quand il y a du gras à perdre (Barakat et al.,
/// 2020) ; une personne mince progresse mieux avec un léger surplus et une prise lente de
/// 0,25 à 0,5 % du poids par semaine (Iraki et al., 2019).
public enum BodyPhase: String, Sendable, Equatable {
    case fatLoss
    case maintenance
    case leanGain

    /// IMC sous lequel le coach ne fixe jamais de déficit (maigreur, OMS).
    public static let underweightBMI = 18.5
    /// Rapport tour de taille / taille à partir duquel le gras abdominal pèse sur la santé
    /// (Ashwell et al., 2012).
    public static let waistToHeightLimit = 0.5
    /// Taux de gras au-delà duquel il reste du gras à perdre (choix BodyPilot, repères usuels).
    public static func fatPercentLimit(for sex: BiologicalSex) -> Double { sex == .male ? 25 : 32 }
    /// Écart au poids visé en dessous duquel on est arrivé.
    static let targetTolerance = 0.5

    /// Ce que vit le reste du coach : la recomposition en déficit, l'équilibre, ou une prise lente.
    public var goal: Goal {
        switch self {
        case .fatLoss: .recomposition
        case .maintenance: .maintain
        case .leanGain: .buildMuscle
        }
    }

    /// Nom court affiché dans Progresser.
    public var title: String {
        switch self {
        case .fatLoss: "Perte de gras"
        case .maintenance: "Équilibre"
        case .leanGain: "Légère prise"
        }
    }

    public static func bmi(weightKg: Double, heightCm: Double) -> Double {
        let meters = heightCm / 100
        return weightKg / (meters * meters)
    }

    /// - Parameters:
    ///   - waistCm: dernier tour de taille au ruban, s'il est connu.
    ///   - fatPercent: taux de gras de la balance (Santé), s'il est connu.
    public static func resolve(for profile: UserProfile, currentWeightKg: Double, waistCm: Double?, fatPercent: Double?, on date: Date, calendar: Calendar) -> BodyPhase {
        if profile.forbidsDeficit(on: date, calendar: calendar) || profile.isOnMaintenanceWeek(on: date) || profile.isOnDeficitPause(on: date) { return .maintenance }
        let bmi = bmi(weightKg: currentWeightKg, heightCm: profile.heightCm)
        if bmi < underweightBMI { return .leanGain }
        if let target = profile.targetWeightKg {
            if target > currentWeightKg + targetTolerance { return .leanGain }
            if target < currentWeightKg - targetTolerance { return .fatLoss }
            return .maintenance
        }
        // Sans poids visé : les mesures disent s'il reste du gras à perdre.
        if let waistCm { return waistCm / profile.heightCm >= waistToHeightLimit ? .fatLoss : .maintenance }
        if let fatPercent { return fatPercent >= fatPercentLimit(for: profile.sex) ? .fatLoss : .maintenance }
        return bmi >= 25 ? .fatLoss : .maintenance
    }

    /// Une phrase sur la phase, pour l'explication des besoins.
    public func reason(for profile: UserProfile, currentWeightKg: Double, on date: Date? = nil) -> String {
        let bmi = Self.bmi(weightKg: currentWeightKg, heightCm: profile.heightCm)
        switch self {
        case .fatLoss:
            return "Phase : perte de gras."
        case .maintenance where date.map { profile.isOnDeficitPause(on: $0) } == true:
            return "Phase : équilibre, déficit en pause. Tu le reprends quand tu veux, depuis Mon profil."
        case .maintenance where date.map { profile.isOnMaintenanceWeek(on: $0) } == true:
            return "Phase : semaine à l'équilibre, pour souffler après le déficit. La perte de gras reprend ensuite."
        case .maintenance:
            return "Phase : équilibre, la force et les protéines font progresser."
        case .leanGain where bmi < Self.underweightBMI:
            return "Phase : légère prise. Ton IMC est sous 18,5 : pas de déficit, on vise 0,25 à 0,5 % de poids en plus par semaine."
        case .leanGain:
            return "Phase : légère prise pour gagner du muscle, 0,25 à 0,5 % de poids en plus par semaine."
        }
    }
}

/// Semaine à l'équilibre proposée après un long déficit. Elle n'accélère pas la perte de gras
/// (ICECAP, Peos et al., 2021) mais calme la faim et aide à tenir : l'utilisateur choisit.
public enum MaintenanceWeek {
    /// Semaines de perte de gras sans pause avant de la proposer.
    public static let afterWeeks = 12
    public static let days = 7
    /// Refusée : proposée de nouveau 4 semaines plus tard.
    public static let retryWeeks = 4

    /// - Parameters:
    ///   - deficitSince: début du déficit en cours (création du profil, ou fin de la dernière semaine à l'équilibre).
    ///   - dismissedAt: dernier « Pas maintenant ».
    public static func isDue(deficitSince: Date, dismissedAt: Date?, on date: Date, calendar: Calendar) -> Bool {
        guard let due = calendar.date(byAdding: .day, value: 7 * afterWeeks, to: deficitSince), date >= due else { return false }
        guard let dismissedAt, let retry = calendar.date(byAdding: .day, value: 7 * retryWeeks, to: dismissedAt) else { return true }
        return date >= retry
    }
}

extension UserProfile {
    /// Semaine à l'équilibre en cours.
    public func isOnMaintenanceWeek(on date: Date) -> Bool {
        maintenanceWeekUntil.map { date < $0 } ?? false
    }

    /// Pause du déficit en cours (garde-fou alimentaire).
    public func isOnDeficitPause(on date: Date) -> Bool {
        deficitPauseUntil.map { date < $0 } ?? false
    }
}
