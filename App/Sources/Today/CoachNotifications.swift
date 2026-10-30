import ProgressInsights
import SwiftUI
import UserNotifications

/// Rappels locaux du coach (décrochage, semaine plancher). Programmés sur l'iPhone, rien ne part
/// sur un serveur. Coupables dans Mon profil > Confidentialité.
enum CoachNotifications {
    /// Réglage « Rappels du coach » (activé par défaut ; iOS demande l'autorisation à la première occasion).
    static let enabledKey = "coachReminders"

    static var isEnabled: Bool { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }

    /// Demande l'autorisation si iOS ne l'a pas encore demandée. Renvoie `true` si les rappels peuvent partir.
    @discardableResult
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        case .denied: return false
        default: return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        }
    }

    static func isDenied() async -> Bool {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied
    }

    /// Semaine plancher lancée : le moment où un rappel a du sens. iOS demande l'autorisation une
    /// seule fois, puis le rappel du jour 5 est programmé sans attendre le prochain passage dans l'app.
    static func floorWeekStarted(until end: Date?) {
        guard isEnabled, !LaunchOptions.demoData else { return }
        let reminders = CoachReminders.plan(lastActivity: nil, floorWeekUntil: end, floorStrengthSessions: 0, now: .now)
        Task {
            guard await requestAuthorization() else { return }
            await reschedule(reminders, enabled: true)
        }
    }

    /// Remplace les rappels du coach par ceux du plan. Sans autorisation, n'ajoute rien et ne demande rien.
    static func reschedule(_ reminders: [PlannedReminder], enabled: Bool) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: CoachReminders.allIDs)
        guard enabled else { return }
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: break
        default: return
        }
        for reminder in reminders {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
        }
    }
}
