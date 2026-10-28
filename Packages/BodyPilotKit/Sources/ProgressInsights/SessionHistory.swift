import BodyPilotCore
import Foundation

/// Une séance passée : cochée dans l'app ou enregistrée dans Santé (Watch, autre app).
public struct SessionEntry: Sendable, Equatable {
    public var title: String
    public var minutes: Double?
    public var kcal: Double?
    public var fromHealth: Bool

    public init(title: String, minutes: Double? = nil, kcal: Double? = nil, fromHealth: Bool) {
        self.title = title
        self.minutes = minutes
        self.kcal = kcal
        self.fromHealth = fromHealth
    }
}

public struct SessionDay: Sendable, Equatable, Identifiable {
    public var day: Date
    public var entries: [SessionEntry]
    public var id: Date { day }

    public init(day: Date, entries: [SessionEntry]) {
        self.day = day
        self.entries = entries
    }
}

/// Historique des séances, jour par jour, le plus récent d'abord.
public enum SessionHistory {
    public static func days(
        completed: [(day: Date, title: String?)],
        samples: [ActivitySample],
        calendar: Calendar = .current
    ) -> [SessionDay] {
        var byDay: [Date: [SessionEntry]] = [:]
        for session in completed {
            byDay[calendar.startOfDay(for: session.day), default: []].append(SessionEntry(title: session.title ?? "Séance", fromHealth: false))
        }
        for sample in samples.sorted(by: { $0.start < $1.start }) {
            byDay[calendar.startOfDay(for: sample.start), default: []].append(
                SessionEntry(title: sample.kind.title, minutes: sample.minutes, kcal: sample.kcal, fromHealth: true)
            )
        }
        return byDay.map { SessionDay(day: $0.key, entries: $0.value) }.sorted { $0.day > $1.day }
    }
}
