import BodyPilotCore
import Foundation

/// Une activité de la semaine, qu'elle vienne de Santé ou d'une séance cochée dans l'app.
public struct WeekActivityEntry: Sendable, Equatable, Identifiable {
    public var id: String
    public var kind: ActivityKind
    public var title: String
    public var start: Date
    public var minutes: Double
    public var kcal: Double?
    /// Lue dans Santé (Watch ou autre app) plutôt que cochée dans BodyPilot.
    public var fromHealth: Bool
}

/// « Ma semaine » : ce qui a vraiment été fait, jour par jour.
public struct WeekActivity: Sendable, Equatable {
    /// Début de chaque jour de la semaine, dans l'ordre du calendrier (lundi d'abord en France).
    public var days: [Date]
    /// Minutes bougées par jour, alignées sur `days`.
    public var minutesPerDay: [Double]
    /// Les plus récentes d'abord.
    public var entries: [WeekActivityEntry]
    public var totalMinutes: Double
    public var totalKcal: Double
    public var summary: String
}

public struct WeekActivityAnalyzer: Sendable {
    public var calendar: Calendar

    /// Une activité de Santé compte comme une séance dans la régularité à partir de cette durée.
    static let sessionMinutes = 20.0

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// Une vraie séance : assez longue, et pas une simple marche (comptée à part comme récupération active).
    public func countsAsSession(_ sample: ActivitySample) -> Bool {
        sample.kind != .walking && sample.minutes >= Self.sessionMinutes
    }

    /// Jours où une séance a été faite : cochée dans l'app ou enregistrée dans Santé.
    /// Famille d'une séance BodyPilot d'après son titre : « Cardio et marche… », « Marche… », sinon force.
    static func kind(ofSession title: String?) -> ActivityKind {
        guard let title else { return .strength }
        if title.hasPrefix("Cardio") { return .cardio }
        if title.hasPrefix("Marche") || title.hasPrefix("Test de cardio") { return .walking }
        return .strength
    }

    public func sessionDays(completedDays: [Date], samples: [ActivitySample]) -> [Date] {
        let days = completedDays.map { calendar.startOfDay(for: $0) }
            + samples.filter(countsAsSession).map { calendar.startOfDay(for: $0.start) }
        return Set(days).sorted()
    }

    /// - Parameters:
    ///   - completedDays: jours où la séance BodyPilot a été cochée, avec son titre s'il est connu.
    ///   - sessionMinutes: durée prévue d'une séance, pour une séance cochée sans trace dans Santé.
    public func week(
        of date: Date,
        samples: [ActivitySample],
        completed: [(day: Date, title: String?)],
        sessionMinutes: Int
    ) -> WeekActivity {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else {
            return WeekActivity(days: [], minutesPerDay: [], entries: [], totalMinutes: 0, totalKcal: 0, summary: "")
        }
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
        let inWeek = samples.filter { interval.contains($0.start) && $0.start <= date }
        var entries = inWeek.map {
            WeekActivityEntry(id: $0.id, kind: $0.kind, title: $0.kind.title, start: $0.start, minutes: $0.minutes, kcal: $0.kcal, fromHealth: true)
        }
        // Une séance cochée sans renforcement enregistré le même jour (montre restée au vestiaire) s'affiche aussi.
        for item in completed where interval.contains(item.day) && item.day <= date {
            let day = calendar.startOfDay(for: item.day)
            let kind = Self.kind(ofSession: item.title)
            let recorded = inWeek.contains { $0.kind == kind && calendar.isDate($0.start, inSameDayAs: day) }
            guard !recorded else { continue }
            entries.append(WeekActivityEntry(
                id: "bodypilot-\(Int(day.timeIntervalSince1970))",
                kind: kind,
                title: item.title ?? "Séance BodyPilot",
                start: day,
                minutes: Double(sessionMinutes),
                kcal: nil,
                fromHealth: false
            ))
        }
        entries.sort { $0.start > $1.start }

        let minutesPerDay = days.map { day in
            entries.filter { calendar.isDate($0.start, inSameDayAs: day) }.reduce(0) { $0 + $1.minutes }
        }
        let totalMinutes = entries.reduce(0) { $0 + $1.minutes }
        let totalKcal = entries.compactMap(\.kcal).reduce(0, +)
        return WeekActivity(
            days: days,
            minutesPerDay: minutesPerDay,
            entries: entries,
            totalMinutes: totalMinutes,
            totalKcal: totalKcal,
            summary: summary(count: entries.count, minutes: totalMinutes, kcal: totalKcal)
        )
    }

    func summary(count: Int, minutes: Double, kcal: Double) -> String {
        guard count > 0 else { return "Rien d'enregistré cette semaine pour l'instant." }
        var parts = ["\(count) activité\(count > 1 ? "s" : "")", Self.duration(minutes)]
        if kcal >= 1 { parts.append("\(kcal.frenchInteger) kcal") }
        return parts.joined(separator: " · ")
    }

    /// « 45 min », « 1 h 05 ».
    public static func duration(_ minutes: Double) -> String {
        let total = Int(minutes.rounded())
        guard total >= 60 else { return "\(total) min" }
        let rest = total % 60
        return rest == 0 ? "\(total / 60) h" : "\(total / 60) h \(rest < 10 ? "0" : "")\(rest)"
    }
}
