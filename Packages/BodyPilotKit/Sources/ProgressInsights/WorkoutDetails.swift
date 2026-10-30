import BodyPilotCore
import Foundation

/// Point du parcours d'un entraînement (GPS de la Watch ou de l'iPhone).
public struct RoutePoint: Sendable, Equatable {
    public var latitude: Double
    public var longitude: Double
    /// Altitude en mètres ; `nil` si le GPS ne la donne pas.
    public var altitude: Double?
    public var time: Date

    public init(latitude: Double, longitude: Double, altitude: Double? = nil, time: Date) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.time = time
    }
}

/// Mesure du pouls pendant un entraînement.
public struct HeartRatePoint: Sendable, Equatable {
    public var time: Date
    public var bpm: Double

    public init(time: Date, bpm: Double) {
        self.time = time
        self.bpm = bpm
    }
}

/// Kilomètre parcouru : le dernier peut être partiel.
public struct KilometerSplit: Sendable, Equatable, Identifiable {
    /// Numéro du kilomètre, à partir de 1.
    public var number: Int
    public var km: Double
    public var seconds: Double
    /// Dénivelé positif du kilomètre, en mètres ; `nil` sans altitude.
    public var climbM: Double?
    public var id: Int { number }

    /// Secondes par kilomètre.
    public var secondsPerKm: Double { seconds / km }
}

/// Zones de fréquence cardiaque en pourcentage de la fréquence maximale (ACSM).
public enum HeartRateZone: Int, Sendable, CaseIterable, Identifiable {
    case recovery = 1, endurance, tempo, threshold, maximal
    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .recovery: "Très léger"
        case .endurance: "Endurance"
        case .tempo: "Tempo"
        case .threshold: "Seuil"
        case .maximal: "Maximal"
        }
    }

    /// Bornes en part de la fréquence maximale ; la zone 1 inclut tout ce qui est en dessous.
    public var range: Range<Double> {
        switch self {
        case .recovery: 0..<0.6
        case .endurance: 0.6..<0.7
        case .tempo: 0.7..<0.8
        case .threshold: 0.8..<0.9
        case .maximal: 0.9..<Double.infinity
        }
    }

    public static func zone(bpm: Double, maxHeartRate: Double) -> HeartRateZone {
        let share = bpm / maxHeartRate
        return allCases.first { $0.range.contains(share) } ?? .recovery
    }
}

/// Lecture d'un entraînement passé : distance, kilomètres, allure, temps par zone de pouls.
/// Déterministe et local : rien ne part dans le cloud.
public enum WorkoutDetails {
    /// Au-delà, deux mesures de pouls sont trop espacées : le trou ne compte dans aucune zone.
    static let maxHeartRateGap: TimeInterval = 30

    /// Distance entre deux points, formule de haversine (rayon terrestre moyen).
    public static func meters(from a: RoutePoint, to b: RoutePoint) -> Double {
        let radius = 6_371_000.0
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLat = lat2 - lat1
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * radius * asin(min(1, sqrt(h)))
    }

    public static func distanceKm(_ route: [RoutePoint]) -> Double {
        zip(route, route.dropFirst()).reduce(0) { $0 + meters(from: $1.0, to: $1.1) } / 1000
    }

    /// Temps de chaque kilomètre, interpolé au passage de la borne. Un reste de moins de 100 m
    /// n'est pas montré : son allure n'aurait pas de sens.
    public static func splits(_ route: [RoutePoint]) -> [KilometerSplit] {
        guard route.count >= 2 else { return [] }
        var splits: [KilometerSplit] = []
        var covered = 0.0
        var splitStart = route[0].time
        var splitStartMeters = 0.0
        var climb = 0.0
        var hasAltitude = false
        for (a, b) in zip(route, route.dropFirst()) {
            let step = meters(from: a, to: b)
            if let up = a.altitude, let down = b.altitude {
                hasAltitude = true
                climb += max(0, down - up)
            }
            let stepStart = covered
            covered += step
            while covered - splitStartMeters >= 1000, step > 0 {
                let border = splitStartMeters + 1000
                let fraction = (border - stepStart) / step
                let time = a.time.addingTimeInterval(b.time.timeIntervalSince(a.time) * fraction)
                splits.append(KilometerSplit(
                    number: splits.count + 1, km: 1, seconds: time.timeIntervalSince(splitStart), climbM: hasAltitude ? climb : nil
                ))
                splitStart = time
                splitStartMeters = border
                climb = 0
            }
        }
        let rest = covered - splitStartMeters
        if rest >= 100, let last = route.last {
            splits.append(KilometerSplit(
                number: splits.count + 1, km: rest / 1000, seconds: last.time.timeIntervalSince(splitStart), climbM: hasAltitude ? climb : nil
            ))
        }
        return splits
    }

    /// Minutes passées dans chaque zone : chaque mesure vaut jusqu'à la suivante (30 s au plus).
    public static func zoneMinutes(_ heartRates: [HeartRatePoint], maxHeartRate: Double, end: Date) -> [HeartRateZone: Double] {
        guard maxHeartRate > 0 else { return [:] }
        let sorted = heartRates.sorted { $0.time < $1.time }
        var seconds: [HeartRateZone: Double] = [:]
        for (index, point) in sorted.enumerated() {
            let next = index + 1 < sorted.count ? sorted[index + 1].time : end
            let duration = min(max(0, next.timeIntervalSince(point.time)), maxHeartRateGap)
            seconds[HeartRateZone.zone(bpm: point.bpm, maxHeartRate: maxHeartRate), default: 0] += duration
        }
        return seconds.mapValues { $0 / 60 }
    }

    /// Allure en minutes et secondes par kilomètre : « 5'32" /km ».
    public static func paceLabel(secondsPerKm: Double) -> String? {
        guard secondsPerKm.isFinite, secondsPerKm > 0, secondsPerKm < 3600 else { return nil }
        let total = Int(secondsPerKm.rounded())
        return "\(total / 60)'\(String(format: "%02d", total % 60))\" /km"
    }

    public static func paceLabel(minutes: Double, km: Double) -> String? {
        guard km > 0 else { return nil }
        return paceLabel(secondsPerKm: minutes * 60 / km)
    }

    /// Vitesse moyenne : « 24,3 km/h ».
    public static func speedLabel(minutes: Double, km: Double) -> String? {
        guard minutes > 0, km > 0 else { return nil }
        return "\((km / (minutes / 60)).frenchOneDecimal) km/h"
    }

    /// Le vélo se lit en vitesse, la course, la marche et la natation en allure.
    public static func readsAsSpeed(_ kind: ActivityKind?) -> Bool {
        kind == .cycling
    }

    /// Durée lisible : « 42 min », « 1 h 05 ».
    public static func durationLabel(minutes: Double) -> String {
        let total = Int(minutes.rounded())
        guard total >= 60 else { return "\(total) min" }
        return "\(total / 60) h \(String(format: "%02d", total % 60))"
    }
}
