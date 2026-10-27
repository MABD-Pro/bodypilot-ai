import Foundation
import HealthKit

/// Lecture du sommeil dans Santé (Apple Watch, iPhone ou autre app) : une nuit courte pèse
/// dans la proposition du jour.
enum HealthSleep {
    static var sleepType: HKCategoryType { HKCategoryType(.sleepAnalysis) }

    /// Heures dormies la nuit passée (de 18 h la veille à midi), plages superposées fusionnées
    /// (montre et iPhone peuvent noter la même nuit) ; `nil` sans donnée ou si la lecture est refusée.
    static func lastNightHours(now: Date = .now, calendar: Calendar = .current) async throws -> Double? {
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .hour, value: -6, to: today),
              let end = calendar.date(byAdding: .hour, value: 12, to: today) else { return nil }
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: sleepType, predicate: HKQuery.predicateForSamples(withStart: start, end: end))],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let asleep = try await descriptor.result(for: HKHealthStore()).filter {
            HKCategoryValueSleepAnalysis(rawValue: $0.value).map(HKCategoryValueSleepAnalysis.allAsleepValues.contains) ?? false
        }
        let seconds = merged(asleep.map { DateInterval(start: $0.startDate, end: max($0.startDate, $0.endDate)) })
            .reduce(0) { $0 + $1.duration }
        return seconds > 0 ? seconds / 3600 : nil
    }

    static func merged(_ intervals: [DateInterval]) -> [DateInterval] {
        intervals.sorted { $0.start < $1.start }.reduce(into: []) { result, interval in
            if let last = result.last, interval.start <= last.end {
                result[result.count - 1] = DateInterval(start: last.start, end: max(last.end, interval.end))
            } else {
                result.append(interval)
            }
        }
    }
}
