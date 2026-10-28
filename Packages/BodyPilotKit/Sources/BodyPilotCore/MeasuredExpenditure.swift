import Foundation

/// Dépense réelle déduite des repas notés et de la tendance du poids : ce qu'on mange en
/// moyenne, moins l'énergie stockée ou perdue (Hall et al., 2011). Elle corrige l'équation,
/// qui peut se tromper de plusieurs centaines de kcal pour une personne donnée.
public struct MeasuredExpenditure: Sendable, Equatable, Codable {
    /// Dépense moyenne par jour (kcal).
    public var kcal: Double
    /// Jours complets (les quatre repas notés) qui ont servi au calcul.
    public var days: Int
    /// Variation du poids sur la période (kg/semaine).
    public var weeklyChangeKg: Double

    /// Avec autant de jours complets, la mesure remplace entièrement l'équation ; avant, les
    /// deux se mêlent au prorata.
    public static let fullConfidenceDays = 21
    /// La mesure reste dans ±25 % de l'équation : au-delà, c'est plus probablement un oubli de
    /// saisie qu'un métabolisme hors norme (choix BodyPilot).
    public static let maxDeviation = 0.25

    public init(kcal: Double, days: Int, weeklyChangeKg: Double) {
        self.kcal = kcal
        self.days = days
        self.weeklyChangeKg = weeklyChangeKg
    }

    /// Part de la mesure dans la dépense retenue (0 à 1).
    public var confidence: Double { min(Double(days) / Double(Self.fullConfidenceDays), 1) }
}
