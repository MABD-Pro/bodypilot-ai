import BodyPilotCore
import Foundation

/// Régularité des séances : combien sont faites cette semaine, et depuis combien de semaines
/// l'objectif est tenu. Le poids bouge lentement ; la régularité se voit tout de suite.
public struct WeeklyConsistency: Sendable, Equatable {
    /// Séances de force faites cette semaine.
    public var done: Int
    /// Séances prévues par semaine.
    public var planned: Int
    /// Semaines complètes d'affilée, celle en cours comprise si elle est déjà bouclée.
    public var streakWeeks: Int
    public var message: String
}

public struct ConsistencyAnalyzer: Sendable {
    public var calendar: Calendar

    /// On ne remonte pas plus loin pour compter la série.
    static let maxStreakWeeks = 52

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func consistency(completedDays: [Date], plannedPerWeek: Int, on date: Date) -> WeeklyConsistency {
        consistency(completedDays: completedDays, on: date) { _ in plannedPerWeek }
    }

    /// - Parameter plannedInWeek: séances prévues pour la semaine qui contient la date donnée.
    ///   Chaque semaine est jugée sur son propre planning : changer la semaine en cours ne casse pas la série.
    public func consistency(completedDays: [Date], on date: Date, plannedInWeek: (Date) -> Int) -> WeeklyConsistency {
        let planned = max(plannedInWeek(date), 1)
        let days = Set(completedDays.map { calendar.startOfDay(for: $0) }).filter { $0 <= date }
        let done = count(days, inWeekOf: date)

        var streak = 0
        var week = date
        for _ in 0..<Self.maxStreakWeeks {
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: week),
                  count(days, inWeekOf: previous) >= max(plannedInWeek(previous), 1)
            else { break }
            streak += 1
            week = previous
        }
        if done >= planned { streak += 1 }

        return WeeklyConsistency(
            done: done,
            planned: planned,
            streakWeeks: streak,
            message: message(done: done, planned: planned, streak: streak, hasHistory: !days.isEmpty)
        )
    }

    private func count(_ days: Set<Date>, inWeekOf date: Date) -> Int {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: date) else { return 0 }
        return days.filter { week.contains($0) }.count
    }

    func message(done: Int, planned: Int, streak: Int, hasHistory: Bool) -> String {
        guard hasHistory else {
            return "Coche ta séance une fois faite : ta régularité s'affichera ici."
        }
        let weeks = "\(streak) semaine\(streak > 1 ? "s" : "")"
        if done >= planned {
            return streak > 1
                ? "Semaine bouclée, \(weeks) d'affilée. C'est la régularité qui fait les résultats."
                : "Semaine bouclée : \(done) séance\(done > 1 ? "s" : "") sur \(planned). Bravo."
        }
        let left = planned - done
        let remaining = "Encore \(left) séance\(left > 1 ? "s" : "") pour boucler la semaine"
        return streak > 0 ? "\(remaining) et prolonger ta série de \(weeks)." : "\(remaining)."
    }
}
