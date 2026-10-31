import BodyPilotCore
import Foundation

/// Heure à laquelle l'utilisateur s'entraîne d'habitude, apprise des séances enregistrées dans
/// Santé (Watch, autres apps). Une séance cochée dans BodyPilot n'a pas d'heure : elle ne compte pas.
public enum TrainingRhythm {
    /// Fenêtre d'apprentissage.
    public static let windowDays = 28
    /// Jours avec une séance qu'il faut au minimum pour parler d'habitude.
    public static let minimumDays = 4
    /// Une séance plus courte (ou une marche) n'est pas une séance (même règle que la régularité).
    public static let minimumMinutes = 20.0
    /// Habitude : au moins 60 % des jours à moins d'une heure de la médiane (choix BodyPilot).
    public static let toleranceMinutes = 60
    public static let regularShare = 0.6

    /// Minute de la journée (0 à 1 439) de l'heure habituelle de début, arrondie au quart d'heure.
    /// `nil` sans assez de séances ou si les heures sont trop dispersées.
    public static func usualStartMinute(_ samples: [ActivitySample], before date: Date, calendar: Calendar) -> Int? {
        let today = calendar.startOfDay(for: date)
        guard let since = calendar.date(byAdding: .day, value: -windowDays, to: today) else { return nil }
        let sessions = samples.filter { $0.kind != .walking && $0.minutes >= minimumMinutes && $0.start >= since && $0.start < today }
        // Première séance de chaque jour.
        let firstPerDay = Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.start) }
            .compactMapValues { $0.min { $0.start < $1.start } }
        let minutes = firstPerDay.values.map { sample -> Int in
            let parts = calendar.dateComponents([.hour, .minute], from: sample.start)
            return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        }.sorted()
        guard minutes.count >= minimumDays else { return nil }
        let median = minutes.count.isMultiple(of: 2)
            ? (minutes[minutes.count / 2 - 1] + minutes[minutes.count / 2]) / 2
            : minutes[minutes.count / 2]
        let close = minutes.filter { abs($0 - median) <= toleranceMinutes }.count
        guard Double(close) >= Double(minutes.count) * regularShare else { return nil }
        return Int((Double(median) / 15).rounded()) * 15 % (24 * 60)
    }

    /// « 18 h 30 ».
    public static func label(minute: Int) -> String {
        let hour = minute / 60, rest = minute % 60
        return rest == 0 ? "\(hour)\u{00A0}h" : "\(hour)\u{00A0}h\u{00A0}\(String(format: "%02d", rest))"
    }
}
