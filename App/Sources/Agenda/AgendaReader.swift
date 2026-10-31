import Coach
import EventKit
import Foundation

/// Événements du jour lus dans le calendrier de l'iPhone. Lecture seule, sur l'appareil : rien
/// n'est enregistré ni envoyé, le coach en tire seulement des propositions.
enum AgendaReader {
    static var isAuthorized: Bool { EKEventStore.authorizationStatus(for: .event) == .fullAccess }

    /// Demandée seulement quand l'utilisateur active la lecture de l'agenda.
    static func requestAccess() async -> Bool {
        (try? await EKEventStore().requestFullAccessToEvents()) ?? false
    }

    static func today(now: Date = .now, calendar: Calendar = .current) -> [AgendaEvent] {
        guard isAuthorized else { return [] }
        let store = EKEventStore()
        let start = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
            // Un événement marqué « disponible » ne bloque pas la journée.
            .filter { $0.availability != .free || $0.isAllDay }
            .map { AgendaEvent(title: $0.title ?? "", start: $0.startDate, end: $0.endDate, location: $0.location, isAllDay: $0.isAllDay) }
    }
}

/// Réglages de l'agenda, sur l'iPhone seulement.
enum AgendaStore {
    private static var defaults: UserDefaults { .standard }
    private static let enabledKey = "agendaEnabled"
    private static let inviteKey = "agendaInviteDismissed"
    private static let dismissedKey = "agendaDismissedDay"

    /// L'utilisateur a choisi de laisser le coach lire son agenda.
    static var isEnabled: Bool {
        get { defaults.bool(forKey: enabledKey) }
        set { defaults.set(newValue, forKey: enabledKey) }
    }

    /// « Non merci » à l'invitation : elle ne revient pas (le menu du profil reste).
    static var inviteDismissed: Bool {
        get { defaults.bool(forKey: inviteKey) }
        set { defaults.set(newValue, forKey: inviteKey) }
    }

    /// « Pas aujourd'hui » : la carte se tait jusqu'à demain.
    static func isDismissed(on date: Date, calendar: Calendar = .current) -> Bool {
        (defaults.object(forKey: dismissedKey) as? Date).map { calendar.isDate($0, inSameDayAs: date) } ?? false
    }

    static func dismiss(on date: Date) {
        defaults.set(date, forKey: dismissedKey)
    }
}
