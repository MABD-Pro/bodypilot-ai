import BodyPilotCore
import Foundation
import Testing
@testable import ProgressInsights

/// Parcours vers le nord : 0,001° de latitude ≈ 111,2 m.
private func northRoute(points: Int, secondsPerPoint: Double, altitudeStep: Double? = nil) -> [RoutePoint] {
    let start = Date(timeIntervalSince1970: 0)
    return (0..<points).map { index in
        RoutePoint(
            latitude: 48.8 + Double(index) * 0.001, longitude: 2.3,
            altitude: altitudeStep.map { 30 + Double(index) * $0 },
            time: start.addingTimeInterval(Double(index) * secondsPerPoint)
        )
    }
}

@Test func distanceFollowsTheRoute() {
    let route = northRoute(points: 11, secondsPerPoint: 30)
    #expect(abs(WorkoutDetails.distanceKm(route) - 1.112) < 0.005)
}

@Test func splitsCutEachKilometerAndKeepTheRest() {
    // 20 segments de ~111 m à 30 s chacun : ~2,22 km à ~4'30" /km.
    let splits = WorkoutDetails.splits(northRoute(points: 21, secondsPerPoint: 30, altitudeStep: 1))
    #expect(splits.map(\.number) == [1, 2, 3])
    #expect(splits[0].km == 1)
    #expect(abs(splits[0].seconds - 270) < 2)
    #expect(abs(splits[1].secondsPerKm - 270) < 2)
    #expect(abs(splits[2].km - 0.224) < 0.005)
    #expect(abs((splits[0].climbM ?? 0) - 9) < 1.01)
}

@Test func shortRestIsNotASplit() {
    // ~1,05 km : un kilomètre, le reste de 50 m n'est pas montré.
    let route = [
        RoutePoint(latitude: 48.8, longitude: 2.3, time: Date(timeIntervalSince1970: 0)),
        RoutePoint(latitude: 48.8 + 0.00945, longitude: 2.3, time: Date(timeIntervalSince1970: 315)),
    ]
    let splits = WorkoutDetails.splits(route)
    #expect(splits.count == 1)
    #expect(splits[0].km == 1)
    #expect(splits[0].climbM == nil)
}

@Test func zonesWeightEachSampleUntilTheNextOne() {
    let start = Date(timeIntervalSince1970: 0)
    // Fréquence max 190 : 110 → zone 1, 125 → zone 2, 160 → zone 4, 180 → zone 5.
    let points = [(0, 110.0), (20, 125), (40, 160), (100, 180)].map { HeartRatePoint(time: start.addingTimeInterval(Double($0.0)), bpm: $0.1) }
    let minutes = WorkoutDetails.zoneMinutes(points, maxHeartRate: 190, end: start.addingTimeInterval(110))
    #expect(minutes[.recovery] == 20.0 / 60)
    #expect(minutes[.endurance] == 20.0 / 60)
    // Trou de 60 s entre deux mesures : seules 30 s comptent.
    #expect(minutes[.threshold] == 30.0 / 60)
    #expect(minutes[.maximal] == 10.0 / 60)
    #expect(minutes[.tempo] == nil)
}

@Test func paceSpeedAndDurationLabels() {
    #expect(WorkoutDetails.paceLabel(minutes: 40, km: 7.2) == "5'33\" /km")
    #expect(WorkoutDetails.paceLabel(minutes: 40, km: 0) == nil)
    #expect(WorkoutDetails.speedLabel(minutes: 75, km: 30.4) == "24,3 km/h")
    #expect(WorkoutDetails.durationLabel(minutes: 42.4) == "42 min")
    #expect(WorkoutDetails.durationLabel(minutes: 65) == "1 h 05")
    #expect(WorkoutDetails.readsAsSpeed(.cycling))
    #expect(!WorkoutDetails.readsAsSpeed(.running))
}
