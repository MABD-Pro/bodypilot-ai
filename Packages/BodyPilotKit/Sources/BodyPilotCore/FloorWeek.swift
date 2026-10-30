import Foundation

/// Semaine plancher : quand tout déraille, un minimum atteignable plutôt qu'un plan complet
/// abandonné. Deux séances de force courtes, les protéines du jour, une pesée. Le coach compte
/// ce qui est tenu, jamais ce qui manque (choix BodyPilot, voir la feuille de route, lot 3).
public enum FloorWeek {
    public static let days = 7
    /// Durée des séances proposées pendant la semaine, sauf temps déclaré le matin.
    public static let sessionMinutes = 20
    public static let strengthSessions = 2
    /// Jours où les protéines doivent être atteintes (à 90 %, comme dans le bilan).
    public static let proteinDays = 4
    /// Protéines atteintes à 90 % de l'objectif : les repas notés d'une touche sont des estimations.
    public static let proteinReached = 0.9

    /// Fin d'une semaine plancher commencée ce jour-là.
    public static func end(startingOn date: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: date)) ?? date
    }
}

extension UserProfile {
    /// Semaine plancher en cours.
    public func isOnFloorWeek(on date: Date) -> Bool {
        floorWeekUntil.map { date < $0 } ?? false
    }
}
