import BodyPilotCore
import Foundation
import HealthKit
import ProgressInsights

/// Lecture des pas dans Santé (iPhone et Apple Watch, sans doublon : Santé les fusionne) : ils
/// remplacent le niveau d'activité déclaré et donnent l'objectif de pas du jour.
enum HealthSteps {
    static var stepType: HKQuantityType { HKQuantityType(.stepCount) }

    /// Pas par jour, des 90 jours précédents jusqu'à aujourd'hui (l'historique des pas ; la moyenne
    /// du coach ne garde que ses 14 jours) ; vide si la lecture est refusée.
    static func daily(now: Date = .now, calendar: Calendar = .current) async throws -> [DailySteps] {
        let today = calendar.startOfDay(for: now)
        let days = max(StepHistory.historyDays, StepActivity.windowDays)
        guard let start = calendar.date(byAdding: .day, value: -days, to: today) else { return [] }
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
