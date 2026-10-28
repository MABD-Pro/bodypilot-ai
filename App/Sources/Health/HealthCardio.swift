import BodyPilotCore
import Foundation
import HealthKit

/// Lecture de la forme cardio dans Santé : la VO2max que l'Apple Watch estime pendant les marches
/// et courses en extérieur, et le pouls au repos, qui personnalise la zone de cardio modéré.
enum HealthCardio {
    static var vo2MaxType: HKQuantityType { HKQuantityType(.vo2Max) }
    static var restingHeartRateType: HKQuantityType { HKQuantityType(.restingHeartRate) }

    /// Dernière VO2max enregistrée ; `nil` sans Watch, sans mesure ou si la lecture est refusée.
    static func latestVO2max() async throws -> CardioMeasure? {
        guard let sample = try await latest(vo2MaxType, since: nil) else { return nil }
        let unit = HKUnit.literUnit(with: .milli).unitDivided(by: .gramUnit(with: .kilo).unitMultiplied(by: .minute()))
        return CardioMeasure(vo2max: sample.quantity.doubleValue(for: unit), date: sample.startDate, source: .watch)
    }

    /// Pouls au repos le plus récent des 30 derniers jours.
    static func restingHeartRate(now: Date = .now) async throws -> Double? {
        let start = Calendar.current.date(byAdding: .day, value: -30, to: now)
        guard let sample = try await latest(restingHeartRateType, since: start) else { return nil }
        return sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
    }

    private static func latest(_ type: HKQuantityType, since start: Date?) async throws -> HKQuantitySample? {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: HKQuery.predicateForSamples(withStart: start, end: nil))],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: 1
        )
        return try await descriptor.result(for: HKHealthStore()).first
    }
}
