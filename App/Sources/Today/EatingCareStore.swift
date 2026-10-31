import Foundation
import ProgressInsights

/// État du garde-fou alimentaire, sur l'iPhone seulement : pause du déficit, carte écartée,
/// jours où une phrase a parlé de culpabilité ou de vomissement (jamais le texte).
enum EatingCareStore {
    private static var defaults: UserDefaults { .standard }
    private static let pauseKey = "eatingCarePauseUntil"
    private static let snoozeKey = "eatingCareSnoozedAt"
    private static let distressKey = "eatingCareDistressDays"
    private static let purgingKey = "eatingCarePurgingDays"

    static var pauseUntil: Date? {
        get { defaults.object(forKey: pauseKey) as? Date }
        set { defaults.set(newValue, forKey: pauseKey) }
    }

    static var snoozedAt: Date? {
        get { defaults.object(forKey: snoozeKey) as? Date }
        set { defaults.set(newValue, forKey: snoozeKey) }
    }

    static var distressDays: [Date] { dates(distressKey) }
    static var purgingDays: [Date] { dates(purgingKey) }

    static func startPause(on date: Date, calendar: Calendar = .current) {
        pauseUntil = calendar.date(byAdding: .day, value: EatingCare.pauseDays, to: calendar.startOfDay(for: date))
    }

    /// Lit une phrase écrite dans l'app ; seule la date d'une mention est gardée, 14 jours.
    static func note(_ text: String, on date: Date = .now, calendar: Calendar = .current) {
        guard let mention = EatingCare.mention(in: text) else { return }
        let key = mention == .purging ? purgingKey : distressKey
        let start = calendar.date(byAdding: .day, value: -EatingCare.windowDays, to: date) ?? date
        defaults.set((dates(key) + [date]).filter { $0 >= start }, forKey: key)
    }

    /// Carte à montrer : un signal, pas de pause en cours, pas écartée depuis moins de 30 jours,
    /// sauf un vomissement mentionné après qu'elle a été écartée.
    static func shows(_ signals: Set<EatingCareSignal>, on date: Date, calendar: Calendar = .current) -> Bool {
        guard !signals.isEmpty, (pauseUntil.map { date >= $0 } ?? true) else { return false }
        guard let snoozedAt else { return true }
        if let retry = calendar.date(byAdding: .day, value: EatingCare.snoozeDays, to: snoozedAt), date >= retry { return true }
        return signals.contains(.purging) && purgingDays.contains { $0 > snoozedAt }
    }

    private static func dates(_ key: String) -> [Date] {
        defaults.array(forKey: key) as? [Date] ?? []
    }
}
