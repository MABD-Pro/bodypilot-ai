import BodyPilotCore
import Foundation

/// Dépense des séances faites, ajoutée à la vie quotidienne dans le calcul des besoins.
/// Moyenne des 14 jours précédents : une séance de plus ou de moins ne fait pas sauter
/// les calories d'un jour à l'autre.
public enum ExerciseEnergy {
    public static let windowDays = 14
    /// Au-delà, l'estimation devient peu fiable (et la montre surestime souvent) : plafond prudent.
    public static let maxDailyKcal = 600.0
    /// Durée retenue pour une marche tranquille cochée sans enregistrement dans Santé.
    static let lightWalkMinutes = 30.0

    /// Dépense moyenne par jour. Un jour avec des entraînements dans Santé (Watch, autre app)
    /// compte leurs calories actives ; un jour avec seulement une séance cochée dans l'app,
    /// une estimation par équivalent métabolique (MET).
    public static func dailyAverage(
        samples: [ActivitySample],
        completed: [(day: Date, title: String?)],
        sessionMinutes: Int,
        weightKg: Double,
        on date: Date,
        calendar: Calendar = .current
    ) -> Double {
        let end = calendar.startOfDay(for: date)
        guard let start = calendar.date(byAdding: .day, value: -windowDays, to: end) else { return 0 }
        let inWindow = { (day: Date) in day >= start && day < end }

        var perDay: [Date: Double] = [:]
        for sample in samples where inWindow(sample.start) {
            let kcal = sample.kcal ?? estimate(kind: sample.kind, minutes: sample.minutes, weightKg: weightKg)
            perDay[calendar.startOfDay(for: sample.start), default: 0] += kcal
        }
        for session in completed {
            let day = calendar.startOfDay(for: session.day)
            guard inWindow(day), perDay[day] == nil else { continue }
            let kind = WeekActivityAnalyzer.kind(ofSession: session.title)
            let minutes = session.title == "Marche tranquille" ? lightWalkMinutes : Double(sessionMinutes)
            perDay[day] = estimate(kind: kind, minutes: minutes, weightKg: weightKg)
        }
        let average = perDay.values.reduce(0, +) / Double(windowDays)
        return min((average / 10).rounded() * 10, maxDailyKcal)
    }

    /// Calories actives : (MET − 1) × poids × heures, le métabolisme de base étant déjà compté.
    static func estimate(kind: ActivityKind, minutes: Double, weightKg: Double) -> Double {
        (met(kind) - 1) * weightKg * minutes / 60
    }

    /// Valeurs moyennes du Compendium des activités physiques (Ainsworth et al., 2011).
    static func met(_ kind: ActivityKind) -> Double {
        switch kind {
        case .strength: 5.0
        case .running: 9.0
        case .cycling: 7.0
        case .walking: 3.5
        case .swimming: 7.0
        case .intervals: 8.0
        case .mobility: 2.5
        case .sport: 7.0
        case .combat: 7.0
        case .cardio: 6.0
        case .other: 4.0
        }
    }
}
