import BodyPilotCore
import Foundation

/// Test de cardio : la « Forme cardio » de l'Apple Watch quand elle existe, sinon le test de
/// marche de Rockport (1,6 km le plus vite possible en marchant), validé et sans danger pour
/// un débutant. Il fixe la zone de cardio modéré et suit la forme dans le temps.
public enum CardioTest {
    public static let distanceKm = 1.6
    /// Une mesure (Watch ou test) reste valable 8 semaines ; au-delà, le test revient.
    public static let validityDays = 56
    /// Temps qu'il faut devant soi : échauffement, 1,6 km de marche rapide, retour au calme.
    public static let minimumMinutes = 25
    static let walkSeconds = 15 * 60

    public static let title = "Test de cardio : 1,6 km de marche"

    /// Le test est à faire quand aucune mesure ne date de moins de 8 semaines.
    public static func isDue(lastMeasured: Date?, on date: Date, calendar: Calendar = .current) -> Bool {
        guard let lastMeasured else { return true }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: lastMeasured), to: calendar.startOfDay(for: date)).day ?? 0
        return days >= validityDays
    }

    /// VO2max estimée par l'équation du test de marche de Rockport (Kline et al., 1987),
    /// à partir du temps sur 1,6 km et du pouls à l'arrivée.
    public static func vo2max(minutes: Double, heartRate: Int, weightKg: Double, age: Int, sex: BiologicalSex) -> Double {
        let pounds = weightKg * 2.20462
        let value = 132.853 - 0.0769 * pounds - 0.3877 * Double(age) + (sex == .male ? 6.315 : 0)
            - 3.2649 * minutes - 0.1565 * Double(heartRate)
        return (max(value, 10) * 10).rounded() / 10
    }

    /// Fréquence cardiaque maximale estimée (Tanaka et al., 2001) : 208 − 0,7 × âge.
    public static func maxHeartRate(age: Int) -> Double {
        208 - 0.7 * Double(age)
    }

    /// Cardio modéré selon l'ACSM : 40 à 59 % de la réserve cardiaque (Karvonen) quand le pouls
    /// au repos est connu, sinon 64 à 76 % de la fréquence maximale.
    public static func moderateZone(age: Int, restingHeartRate: Double?) -> ClosedRange<Int> {
        let max = maxHeartRate(age: age)
        if let rest = restingHeartRate, rest > 30, rest < max {
            let reserve = max - rest
            return Int((rest + 0.40 * reserve).rounded())...Int((rest + 0.59 * reserve).rounded())
        }
        return Int((0.64 * max).rounded())...Int((0.76 * max).rounded())
    }

    /// La mesure la plus récente, de la Watch ou d'un test fait dans l'app.
    public static func latest(_ measures: [CardioMeasure]) -> CardioMeasure? {
        measures.max { $0.date < $1.date }
    }

    public static func workout() -> Workout {
        var workout = Workout(
            title: title, warmupMinutes: 5, cooldownMinutes: 3,
            exercises: [WorkoutExercise(name: "Marche la plus rapide possible, sans courir", sets: 1, volume: .seconds(walkSeconds), restSeconds: 0, priority: 4)],
            intensityCue: "Sur terrain plat, 1,6 km à allure régulière, aussi vite que possible sans courir. À l'arrivée, note ton temps et ton pouls tout de suite."
        )
        workout.isCardioTest = true
        return workout
    }
}
