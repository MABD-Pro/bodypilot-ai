import BodyPilotCore
import Foundation

/// Décrochage : plusieurs jours sans rien noter (repas, séance, pesée). Le coach propose de
/// repartir avec une semaine plancher, sans rattrapage ni reproche.
public struct Comeback: Sendable, Equatable {
    /// Jours pleins sans rien noter, aujourd'hui exclu.
    public var quietDays: Int
    public var title: String
    public var message: String

    /// À partir de 3 jours sans rien noter (choix BodyPilot : un week-end sans app n'est pas un
    /// décrochage, trois jours commencent à l'être).
    public static let minimumQuietDays = 3

    /// - Parameters:
    ///   - activityDays: jours où quelque chose a été noté (repas, séance cochée, série, pesée).
    ///   - since: début du suivi (création du profil) : un nouvel utilisateur n'a pas décroché.
    /// - Returns: `nil` si quelque chose a été noté récemment, ou aujourd'hui.
    public static func detect(activityDays: [Date], since start: Date, on date: Date, calendar: Calendar = .current) -> Comeback? {
        let today = calendar.startOfDay(for: date)
        let days = activityDays.map { calendar.startOfDay(for: $0) }
        if days.contains(today) { return nil }
        let reference = days.filter { $0 < today }.max() ?? calendar.startOfDay(for: start)
        let quiet = (calendar.dateComponents([.day], from: reference, to: today).day ?? 0) - 1
        guard quiet >= minimumQuietDays else { return nil }
        if quiet >= 14 {
            return Comeback(
                quietDays: quiet,
                title: "Content de te revoir",
                message: "Pas de rattrapage à faire : on repart de là où tu es. Une semaine plancher, deux séances de 20\u{00A0}min, tes protéines et une pesée, suffit pour relancer la machine."
            )
        }
        return Comeback(
            quietDays: quiet,
            title: "\(quiet) jours sans nouvelles",
            message: "Ça arrive à tout le monde. Plutôt que de tout reprendre d'un coup, une semaine plancher : deux séances de 20\u{00A0}min, tes protéines et une pesée. Le reste est du bonus."
        )
    }
}

/// Où en est la semaine plancher : ce qui est tenu, sans compter ce qui manque.
public struct FloorWeekProgress: Sendable, Equatable {
    public var day: Int
    public var strengthSessions: Int
    public var proteinDays: Int
    public var weighedIn: Bool
    public var isHeld: Bool { strengthSessions >= FloorWeek.strengthSessions && proteinDays >= FloorWeek.proteinDays && weighedIn }
    public var message: String

    /// - Parameters:
    ///   - until: fin de la semaine plancher.
    ///   - strengthDays: jours avec une séance de force (cochée ou lue dans Santé).
    ///   - proteinReachedDays: jours où les protéines ont été atteintes.
    ///   - weighIns: dates des pesées.
    public static func evaluate(
        until end: Date,
        strengthDays: [Date],
        proteinReachedDays: [Date],
        weighIns: [Date],
        on date: Date,
        calendar: Calendar = .current
    ) -> FloorWeekProgress {
        let start = calendar.date(byAdding: .day, value: -FloorWeek.days, to: end) ?? end
        let week = DateInterval(start: start, end: end)
        func count(_ dates: [Date]) -> Int {
            Set(dates.filter { week.contains($0) && $0 < end }.map { calendar.startOfDay(for: $0) }).count
        }
        let elapsed = (calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: date)).day ?? 0) + 1
        var progress = FloorWeekProgress(
            day: min(max(elapsed, 1), FloorWeek.days),
            strengthSessions: count(strengthDays),
            proteinDays: count(proteinReachedDays),
            weighedIn: count(weighIns) > 0,
            message: ""
        )
        progress.message = progress.isHeld
            ? "Plancher tenu. C'est exactement ce qui fait tenir sur des mois : tu peux reprendre le plan complet quand tu veux."
            : progress.strengthSessions + progress.proteinDays + (progress.weighedIn ? 1 : 0) == 0
                ? "Une seule chose aujourd'hui : une séance de 20\u{00A0}min, ou tes protéines, ou une pesée."
                : "Chaque case compte. Continue à ton rythme, rien d'autre n'est demandé cette semaine."
        return progress
    }
}
