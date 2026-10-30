import BodyPilotCore
import Foundation

/// Force rapportée au poids de corps, comparée d'une période de 4 semaines à la précédente.
///
/// En recomposition, la balance seule trompe : des charges qui tiennent pendant que le poids
/// baisse montrent que le muscle est gardé. Pas de barème « débutant / avancé » : les tables
/// publiées ne sont pas validées scientifiquement, seule ta propre évolution compte.
public struct RelativeStrength: Sendable, Equatable {
    /// Exercices comparés : notés avec charge dans les deux périodes.
    public var exercises: Int
    /// Variation de la force par kilo de poids de corps, en %.
    public var ratioChangePercent: Double
    /// Variation des charges (1RM estimés), en %.
    public var strengthChangePercent: Double
    /// Variation du poids de corps moyen, en %.
    public var weightChangePercent: Double
    /// Une phrase pour l'écran Progresser et le bilan.
    public var message: String

    public static let windowDays = 28
    /// En deçà, la variation est du bruit (forme du jour, arrondi des charges) : « stable ».
    static let meaningfulPercent = 2.0

    /// « 1,25 × ton poids ».
    public static func bodyweightMultiple(oneRepMax: Double, bodyweightKg: Double) -> String? {
        guard oneRepMax > 0, bodyweightKg > 0 else { return nil }
        let ratio = ((oneRepMax / bodyweightKg) * 100).rounded() / 100
        let text = String(format: "%.2f", ratio).replacingOccurrences(of: ".", with: ",")
        return "\(text) × ton poids"
    }

    /// `nil` sans exercice noté avec charge dans les deux périodes, ou sans pesée dans chacune.
    public static func compute(
        history: [LiftEntry],
        weights: [WeightEntry],
        on date: Date,
        calendar: Calendar = .current
    ) -> RelativeStrength? {
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date
        guard let middle = calendar.date(byAdding: .day, value: -windowDays, to: end),
              let start = calendar.date(byAdding: .day, value: -windowDays, to: middle) else { return nil }
        let recent = DateInterval(start: middle, end: end)
        let earlier = DateInterval(start: start, end: middle)

        func averageWeight(in interval: DateInterval) -> Double? {
            let values = weights.filter { $0.kg > 0 && interval.contains($0.date) && $0.date < interval.end }.map(\.kg)
            return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
        }
        guard let weightNow = averageWeight(in: recent), let weightBefore = averageWeight(in: earlier) else { return nil }

        func best(_ exercise: String, in interval: DateInterval) -> Double? {
            history
                .filter { $0.exercise == exercise && ($0.kg ?? 0) > 0 && interval.contains($0.date) && $0.date < interval.end }
                .map(StrengthProgress.score)
                .max()
        }
        let pairs: [(now: Double, before: Double)] = Set(history.map(\.exercise)).sorted().compactMap { exercise in
            guard let now = best(exercise, in: recent), let before = best(exercise, in: earlier), before > 0 else { return nil }
            return (now, before)
        }
        guard !pairs.isEmpty else { return nil }

        let count = Double(pairs.count)
        let strength = pairs.reduce(0) { $0 + ($1.now / $1.before - 1) } / count * 100
        let ratio = pairs.reduce(0) { $0 + (($1.now / weightNow) / ($1.before / weightBefore) - 1) } / count * 100
        let weight = (weightNow / weightBefore - 1) * 100
        return RelativeStrength(
            exercises: pairs.count,
            ratioChangePercent: ratio,
            strengthChangePercent: strength,
            weightChangePercent: weight,
            message: message(ratio: ratio, strength: strength, weight: weight)
        )
    }

    static func message(ratio: Double, strength: Double, weight: Double) -> String {
        let detail = "charges \(signedPercent(strength)), poids \(signedPercent(weight))"
        if ratio >= meaningfulPercent {
            return weight <= -1
                ? "Force par kilo : \(signedPercent(ratio)) en 4 semaines (\(detail)). Tu perds du poids sans perdre de force : le muscle est gardé."
                : "Force par kilo : \(signedPercent(ratio)) en 4 semaines (\(detail)). Tu deviens plus fort pour ton poids."
        }
        if ratio > -meaningfulPercent {
            return "Force par kilo stable sur 4 semaines (\(detail))."
        }
        return "Force par kilo : \(signedPercent(ratio)) en 4 semaines (\(detail)). Regarde tes protéines et ton sommeil ; une semaine chargée suffit parfois à l'expliquer."
    }

    /// « +6 % », « −3 % », « 0 % ».
    static func signedPercent(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        return rounded > 0 ? "+\(rounded) %" : rounded < 0 ? "−\(abs(rounded)) %" : "0 %"
    }
}
