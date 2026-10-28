import BodyPilotCore
import Foundation
import HealthKit

/// Taux de gras et masse maigre écrits dans Santé par une balance à impédance (Withings, Eufy…).
/// Lecture seule ; une mesure par jour, la première (le plus souvent le matin à jeun).
enum HealthBodyComposition {
    static var fatType: HKQuantityType { HKQuantityType(.bodyFatPercentage) }
    static var leanType: HKQuantityType { HKQuantityType(.leanBodyMass) }
    static var readTypes: Set<HKObjectType> { [fatType, leanType] }
    static let lookbackDays = 90

    /// Mesures des 90 derniers jours ; vide sans balance compatible ou si la lecture est refusée.
    static func entries(now: Date = .now, calendar: Calendar = .current) async -> [BodyCompositionEntry] {
        let start = calendar.date(byAdding: .day, value: -lookbackDays, to: now)
        let fat = (try? await samples(fatType, since: start)) ?? []
        let lean = (try? await samples(leanType, since: start)) ?? []
        var byDay: [Date: BodyCompositionEntry] = [:]
        for sample in fat {
            let day = calendar.startOfDay(for: sample.startDate)
            guard byDay[day]?.fatPercent == nil else { continue }
            byDay[day, default: BodyCompositionEntry(date: sample.startDate)].fatPercent = sample.quantity.doubleValue(for: .percent()) * 100
        }
        for sample in lean {
            let day = calendar.startOfDay(for: sample.startDate)
            guard byDay[day]?.leanKg == nil else { continue }
            byDay[day, default: BodyCompositionEntry(date: sample.startDate)].leanKg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
        }
        // Valeurs aberrantes (saisie erronée, balance mal réglée) écartées.
        return byDay.values
            .filter { ($0.fatPercent.map { (3...70).contains($0) } ?? true) && ($0.leanKg.map { (20...150).contains($0) } ?? true) }
            .sorted { $0.date < $1.date }
    }

    private static func samples(_ type: HKQuantityType, since start: Date?) async throws -> [HKQuantitySample] {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: HKQuery.predicateForSamples(withStart: start, end: nil))],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        return try await descriptor.result(for: HKHealthStore())
    }
}
