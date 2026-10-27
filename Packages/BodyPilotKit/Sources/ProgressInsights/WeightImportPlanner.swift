import BodyPilotCore
import Foundation

/// Choisit les pesées externes à importer, sans jamais écraser ce que l'utilisateur a saisi.
///
/// - une seule pesée par jour : la première, prise le plus souvent le matin à jeun ;
/// - un jour déjà renseigné (saisie manuelle ou import précédent) n'est pas touché ;
/// - les valeurs aberrantes (erreur de balance, enfant monté dessus) sont écartées.
public struct WeightImportPlanner: Sendable {
    public var calendar: Calendar

    static let plausibleKg = 25.0...350.0

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func samplesToImport(_ samples: [WeightSample], recordedDays: Set<Date>, knownIDs: Set<String> = []) -> [WeightSample] {
        var firstPerDay: [Date: WeightSample] = [:]
        for sample in samples where Self.plausibleKg.contains(sample.kg) && !knownIDs.contains(sample.id) {
            let day = calendar.startOfDay(for: sample.date)
            guard !recordedDays.contains(day) else { continue }
            if let current = firstPerDay[day], current.date <= sample.date { continue }
            firstPerDay[day] = sample
        }
        return firstPerDay.values.sorted { $0.date < $1.date }
    }
}
