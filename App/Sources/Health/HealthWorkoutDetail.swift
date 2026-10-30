import BodyPilotCore
import CoreLocation
import Foundation
import HealthKit
import ProgressInsights

/// Ce que Santé sait d'un entraînement passé, au-delà de sa durée et de ses calories.
struct WorkoutDetail: Sendable {
    var start: Date
    var end: Date
    /// App ou appareil qui a enregistré l'entraînement (« Apple Watch de … », Strava…).
    var source: String?
    var indoor: Bool?
    var distanceKm: Double?
    var elevationGainM: Double?
    var temperatureC: Double?
    var averageHeartRate: Double?
    var maxHeartRate: Double?
    var heartRates: [HeartRatePoint] = []
    var route: [RoutePoint] = []

    var minutes: Double { end.timeIntervalSince(start) / 60 }
}

/// Lecture du détail d'un entraînement Santé : parcours GPS, pouls, distance, dénivelé.
enum HealthWorkoutDetail {
    private static var heartRateType: HKQuantityType { HKQuantityType(.heartRate) }
    private static var distanceTypes: [HKQuantityType] {
        [HKQuantityType(.distanceWalkingRunning), HKQuantityType(.distanceCycling), HKQuantityType(.distanceSwimming)]
    }
    private static let bpm = HKUnit.count().unitDivided(by: .minute())

    static var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [heartRateType, HKSeriesType.workoutRoute()]
        for type in distanceTypes { types.insert(type) }
        return types
    }

    /// Demandés à l'ouverture d'un détail : les utilisateurs reliés à Santé avant cette version
    /// n'ont pas encore vu ces types. Sans effet s'ils ont déjà été proposés.
    static func requestAccess() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        try? await HKHealthStore().requestAuthorization(toShare: [], read: readTypes)
    }

    /// `nil` si l'entraînement n'existe plus ou si sa lecture est refusée.
    static func load(id: String) async throws -> WorkoutDetail? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        let store = HKHealthStore()
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(HKQuery.predicateForObject(with: uuid))],
            sortDescriptors: [],
            limit: 1
        )
        guard let workout = try await descriptor.result(for: store).first else { return nil }

        // Pouls ou parcours illisible : le reste du détail s'affiche quand même.
        let points = (try? await heartRates(during: workout, store: store)) ?? []
        let path = (try? await route(of: workout, store: store)) ?? []

        let heartStatistics = workout.statistics(for: heartRateType)
        let measuredKm = distanceTypes.lazy
            .compactMap { workout.statistics(for: $0)?.sumQuantity()?.doubleValue(for: .meterUnit(with: .kilo)) }
            .first { $0 > 0 }
        let metadata = workout.metadata ?? [:]
        return WorkoutDetail(
            start: workout.startDate,
            end: workout.endDate,
            source: workout.sourceRevision.source.name,
            indoor: metadata[HKMetadataKeyIndoorWorkout] as? Bool,
            distanceKm: measuredKm ?? (path.count >= 2 ? WorkoutDetails.distanceKm(path) : nil),
            elevationGainM: (metadata[HKMetadataKeyElevationAscended] as? HKQuantity)?.doubleValue(for: .meter()),
            temperatureC: (metadata[HKMetadataKeyWeatherTemperature] as? HKQuantity)?.doubleValue(for: .degreeCelsius()),
            averageHeartRate: heartStatistics?.averageQuantity()?.doubleValue(for: bpm)
                ?? (points.isEmpty ? nil : points.map(\.bpm).reduce(0, +) / Double(points.count)),
            maxHeartRate: heartStatistics?.maximumQuantity()?.doubleValue(for: bpm) ?? points.map(\.bpm).max(),
            heartRates: points,
            route: path
        )
    }

    private static func heartRates(during workout: HKWorkout, store: HKHealthStore) async throws -> [HeartRatePoint] {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(
                type: heartRateType,
                predicate: HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate)
            )],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        return try await descriptor.result(for: store).map {
            HeartRatePoint(time: $0.startDate, bpm: $0.quantity.doubleValue(for: bpm))
        }
    }

    private static func route(of workout: HKWorkout, store: HKHealthStore) async throws -> [RoutePoint] {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.sample(type: HKSeriesType.workoutRoute(), predicate: HKQuery.predicateForObjects(from: workout))],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        var points: [RoutePoint] = []
        for case let route as HKWorkoutRoute in try await descriptor.result(for: store) {
            points += try await locations(of: route, store: store).map {
                RoutePoint(
                    latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude,
                    altitude: $0.verticalAccuracy >= 0 ? $0.altitude : nil, time: $0.timestamp
                )
            }
        }
        return points
    }

    /// Santé livre le parcours par lots, jusqu'au dernier.
    private static func locations(of route: HKWorkoutRoute, store: HKHealthStore) async throws -> [CLLocation] {
        let buffer = LocationBuffer()
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKWorkoutRouteQuery(route: route) { _, batch, done, error in
                if let error {
                    buffer.finish { continuation.resume(throwing: error) }
                    return
                }
                buffer.append(batch ?? [])
                if done { buffer.finish { continuation.resume(returning: buffer.locations) } }
            }
            store.execute(query)
        }
    }
}

/// Lots du parcours reçus sur la file de Santé ; la suite ne reprend qu'une fois.
private final class LocationBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [CLLocation] = []
    private var finished = false

    var locations: [CLLocation] { lock.withLock { items } }

    func append(_ batch: [CLLocation]) {
        lock.withLock { items += batch }
    }

    func finish(_ resume: () -> Void) {
        let first = lock.withLock {
            defer { finished = true }
            return !finished
        }
        if first { resume() }
    }
}
