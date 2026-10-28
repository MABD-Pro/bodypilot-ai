import BodyPilotCore
import Foundation
import HealthKit

/// Lecture des pas dans Santé (iPhone et Apple Watch, sans doublon : Santé les fusionne) : ils
/// remplacent le niveau d'activité déclaré et donnent l'objectif de pas du jour.
enum HealthSteps {
    static var stepType: HKQuantityType { HKQuantityType(.stepCount) }

    /// Pas par jour, des 14 jours précédents jusqu'à aujourd'hui ; vide si la lecture est refusée.
    static func daily(now: Date = .now, calendar: Calendar = .current) async throws -> [DailySteps] {
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -StepActivity.windowDays, to: today) else { return [] }
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: stepType, predicate: HKQuery.predicateForSamples(withStart: start, end: nil)),
            options: .cumulativeSum,
            anchorDate: start,
            intervalComponents: DateComponents(day: 1)
        )
        let collection = try await descriptor.result(for: HKHealthStore())
        return collection.statistics().compactMap { statistics in
            guard let sum = statistics.sumQuantity() else { return nil }
            return DailySteps(day: statistics.startDate, steps: Int(sum.doubleValue(for: .count()).rounded()))
        }
    }
}
