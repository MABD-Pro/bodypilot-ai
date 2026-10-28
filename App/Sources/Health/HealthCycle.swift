import Foundation
import HealthKit
import ProgressInsights

/// Lecture du suivi de cycle dans Santé (app Santé, Apple Watch ou autre app), pour les femmes
/// seulement : la rétention d'eau autour des règles ne doit pas faire baisser les calories.
enum HealthCycle {
    static var menstrualFlowType: HKCategoryType { HKCategoryType(.menstrualFlow) }
    /// Trois cycles et demi : de quoi estimer la durée moyenne et prévoir les prochaines règles.
    static let lookbackDays = 120

    /// Premiers jours de règles récents ; vide sans suivi de cycle ou si la lecture est refusée.
    static func periodStarts(now: Date = .now, calendar: Calendar = .current) async throws -> [Date] {
        let start = calendar.date(byAdding: .day, value: -lookbackDays, to: now)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: menstrualFlowType, predicate: HKQuery.predicateForSamples(withStart: start, end: now))],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let flowDays = try await descriptor.result(for: HKHealthStore())
            .filter { $0.value != HKCategoryValueVaginalBleeding.none.rawValue }
            .map(\.startDate)
        return MenstrualCycle.starts(fromFlowDays: flowDays, calendar: calendar)
    }
}
