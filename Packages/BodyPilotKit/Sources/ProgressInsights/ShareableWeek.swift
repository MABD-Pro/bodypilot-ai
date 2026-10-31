import BodyPilotCore
import Foundation

/// Ma semaine en une carte à partager (ami, coach, groupe) : ce qui a été fait, jamais le poids
/// lui-même. Poids et tour de taille n'y figurent qu'en variation, et seulement si l'utilisateur
/// le demande.
public struct ShareableWeek: Sendable, Equatable {
    public struct Stat: Sendable, Equatable, Identifiable {
        public var symbol: String
        public var value: String
        public var label: String
        public var id: String { label }

        public init(symbol: String, value: String, label: String) {
            self.symbol = symbol
            self.value = value
            self.label = label
        }
    }

    /// « 23 – 29 octobre ».
    public var period: String
    public var headline: String
    public var stats: [Stat]
    /// Une réussite de la semaine, s'il y en a une.
    public var highlight: String?
    /// La même chose en texte, pour un message.
    public var text: String
}

public enum ShareableWeekBuilder {
    /// Mois en toutes lettres, sans dépendre de la langue de l'appareil.
    static let months = ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre"]

    /// - Parameters:
    ///   - weeklyWeightChangeKg: variation hebdomadaire de la tendance du poids.
    ///   - waistChangeCm: variation du tour de taille sur 4 semaines.
    ///   - showsBody: poids et tour de taille ne figurent que si l'utilisateur l'a choisi.
    public static func make(
        review: WeekReview,
        headline: String,
        weeklyWeightChangeKg: Double?,
        waistChangeCm: Double?,
        showsBody: Bool,
        calendar: Calendar = .current
    ) -> ShareableWeek {
        var stats: [ShareableWeek.Stat] = []
        let sessions = review.sessions
        stats.append(.init(
            symbol: "figure.strengthtraining.traditional",
            value: "\(sessions)",
            label: (sessions > 1 ? "séances" : "séance") + (review.strengthSessions > 0 ? ", dont \(review.strengthSessions) de force" : "")
        ))
        stats.append(.init(
            symbol: "flame.fill",
            value: "\(Int(review.activeMinutes.rounded())) min",
            label: "d'activité (repère de l'OMS : \(Int(WeekReviewer.activeMinutesGoal)))"
        ))
        // La nutrition ne se juge qu'avec assez de journées notées en entier.
        if review.completeDays >= WeekReviewer.minimumCompleteDays {
            stats.append(.init(
                symbol: "fork.knife",
                value: "\(review.proteinDays)/\(review.completeDays)",
                label: "jours avec mes protéines"
            ))
        }
        if let steps = review.averageSteps {
            stats.append(.init(symbol: "shoeprints.fill", value: ((steps / 100).rounded() * 100).frenchInteger, label: "pas par jour en moyenne"))
        }
        if showsBody {
            if let weight = weeklyWeightChangeKg {
                stats.append(.init(symbol: "scalemass.fill", value: "\(weight.frenchSignedOneDecimal) kg", label: "par semaine (tendance du poids)"))
            }
            if let waist = waistChangeCm {
                stats.append(.init(symbol: "ruler.fill", value: "\(waist.frenchSignedOneDecimal) cm", label: "de tour de taille en 4 semaines"))
            }
        }
        let period = periodLabel(review.days.map(\.day), calendar: calendar)
        let highlight = review.wins.first
        var lines = ["Ma semaine avec BodyPilot (\(period))", headline]
        lines += stats.map { "• \($0.value) \($0.label)" }
        if let highlight { lines.append("✓ \(highlight)") }
        return ShareableWeek(period: period, headline: headline, stats: stats, highlight: highlight, text: lines.joined(separator: "\n"))
    }

    /// « 23 – 29 octobre », ou « 28 octobre – 3 novembre » à cheval sur deux mois.
    static func periodLabel(_ days: [Date], calendar: Calendar) -> String {
        guard let first = days.min(), let last = days.max() else { return "" }
        let start = calendar.dateComponents([.day, .month], from: first)
        let end = calendar.dateComponents([.day, .month], from: last)
        guard let startDay = start.day, let startMonth = start.month, let endDay = end.day, let endMonth = end.month else { return "" }
        let startMonthName = months[startMonth - 1]
        let endMonthName = months[endMonth - 1]
        if startMonth == endMonth {
            return "\(startDay) – \(endDay) \(endMonthName)"
        }
        return "\(startDay) \(startMonthName) – \(endDay) \(endMonthName)"
    }
}
