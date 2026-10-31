import BodyPilotCore
import Foundation

/// Un rappel local à programmer. Rare et sans reproche : au plus un par situation.
public struct PlannedReminder: Sendable, Hashable {
    public var id: String
    public var date: Date
    public var title: String
    public var body: String
}

/// Rappels du coach (feuille de route, lot 3) : un message quand on décroche, un autre pendant
/// la semaine plancher si les séances manquent. Jamais de rappel quotidien ni de série perdue :
/// le reste du temps, l'app ne notifie rien (choix BodyPilot).
public enum CoachReminders {
    public static let comebackID = "coach.comeback"
    public static let floorWeekID = "coach.floorWeek"
    public static let sessionID = "coach.session"
    public static let allIDs = [comebackID, floorWeekID, sessionID]
    /// Le rappel de séance part ce temps avant l'heure habituelle.
    public static let sessionLeadMinutes = 20

    /// - Parameters:
    ///   - lastActivity: dernier jour où quelque chose a été noté (repas, séance, série, pesée).
    ///   - floorWeekUntil: fin de la semaine plancher, si elle a été lancée.
    ///   - floorStrengthSessions: séances de force déjà faites pendant la semaine plancher.
    /// - Returns: les rappels encore à venir, à reprogrammer à chaque changement.
    public static func plan(
        lastActivity: Date?,
        floorWeekUntil: Date?,
        floorStrengthSessions: Int,
        now: Date,
        calendar: Calendar = .current
    ) -> [PlannedReminder] {
        if let end = floorWeekUntil, now < end {
            // Semaine plancher : un seul rappel, le jour 5 à 18 h, si les deux séances ne sont pas faites.
            guard floorStrengthSessions < FloorWeek.strengthSessions else { return [] }
            let start = calendar.date(byAdding: .day, value: -FloorWeek.days, to: end) ?? end
            guard let date = at(hour: 18, minute: 0, daysAfter: 4, from: start, calendar: calendar), date > now else { return [] }
            let missing = FloorWeek.strengthSessions - floorStrengthSessions
            return [PlannedReminder(
                id: floorWeekID,
                date: date,
                title: "Semaine plancher",
                body: missing == FloorWeek.strengthSessions
                    ? "Encore trois jours pour tes deux séances. \(FloorWeek.sessionMinutes)\u{00A0}min chacune suffisent."
                    : "Une séance de \(FloorWeek.sessionMinutes)\u{00A0}min et ta semaine plancher est tenue côté force."
            )]
        }
        // Décrochage : le 4e jour sans rien noter à 18 h 30, quand la carte « On repart » apparaît.
        let reference = calendar.startOfDay(for: lastActivity ?? now)
        guard let date = at(hour: 18, minute: 30, daysAfter: Comeback.minimumQuietDays + 1, from: reference, calendar: calendar), date > now else { return [] }
        return [PlannedReminder(
            id: comebackID,
            date: date,
            title: "On repart quand tu veux",
            body: "Pas de rattrapage à faire. Une semaine plancher : deux séances de \(FloorWeek.sessionMinutes)\u{00A0}min, tes protéines et une pesée."
        )]
    }

    /// Rappel de séance, seulement si l'utilisateur l'a demandé (réglage coupé par défaut) :
    /// 20 min avant son heure habituelle, si la séance du jour n'est ni faite ni remplacée par
    /// le repos. Jamais pendant un décrochage : c'est le rappel « On repart » qui parle.
    /// - Parameter usualStartMinute: heure habituelle (`TrainingRhythm.usualStartMinute`).
    public static func session(
        usualStartMinute: Int?,
        sessionTitle: String?,
        isDone: Bool,
        now: Date,
        calendar: Calendar = .current
    ) -> PlannedReminder? {
        guard let usual = usualStartMinute, let title = sessionTitle, !isDone else { return nil }
        let minute = usual - sessionLeadMinutes
        guard minute >= 0,
              let date = calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: now),
              date > now else { return nil }
        return PlannedReminder(
            id: sessionID,
            date: date,
            title: title,
            body: "Tu t'entraînes d'habitude vers \(TrainingRhythm.label(minute: usual)). Ta séance est prête, sinon dis-moi ce qui change."
        )
    }

    private static func at(hour: Int, minute: Int, daysAfter days: Int, from start: Date, calendar: Calendar) -> Date? {
        guard let day = calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: start)) else { return nil }
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
    }
}
