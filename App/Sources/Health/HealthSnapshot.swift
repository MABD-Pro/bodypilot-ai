import BodyPilotCore
import Foundation
import ProgressInsights

/// Dernières lectures Santé, gardées sur l'iPhone : au lancement, l'écran part de ce que Santé
/// disait la dernière fois au lieu de rien. Sans elles, le premier calcul ignore les pas, les
/// séances de la Watch et la composition, puis l'objectif change quand Santé répond.
struct HealthSnapshot: Codable, Equatable {
    var savedAt: Date
    var activities: [ActivitySample]
    var sleepHours: Double?
    var averageSleepHours: Double?
    var watchCardio: CardioMeasure?
    var restingHeartRate: Double?
    var periodStarts: [Date]
    var compositions: [BodyCompositionEntry]
    var dailySteps: [DailySteps]
    /// VFC et pouls au repos sur 28 jours ; absents des relevés plus anciens.
    var hrvReadings: [DatedValue]? = nil
    var restingReadings: [DatedValue]? = nil
}

@MainActor
enum HealthSnapshotStore {
    private static var url: URL {
        URL.applicationSupportDirectory.appending(path: "health-snapshot.json")
    }

    private static var cached: HealthSnapshot?? = nil

    /// Le dernier relevé, sauf en démo. Le sommeil de la nuit n'est repris que le jour même.
    static func last(calendar: Calendar = .current) -> HealthSnapshot? {
        guard !LaunchOptions.demoData else { return nil }
        if cached == nil {
            cached = .some((try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(HealthSnapshot.self, from: $0) })
        }
        guard var snapshot = cached ?? nil else { return nil }
        if !calendar.isDateInToday(snapshot.savedAt) { snapshot.sleepHours = nil }
        return snapshot
    }

    static func save(_ snapshot: HealthSnapshot) {
        guard !LaunchOptions.demoData else { return }
        cached = .some(snapshot)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(snapshot).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    /// Santé déconnectée : plus rien de Santé ne reste dans l'app.
    static func clear() {
        cached = .some(nil)
        try? FileManager.default.removeItem(at: url)
    }
}
