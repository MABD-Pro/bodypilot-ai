import BodyPilotCore
import Foundation

/// Un palier de montée en charge pendant un test.
public struct RampStep: Sendable, Equatable {
    public var reps: Int
    public var kg: Double

    public init(reps: Int, kg: Double) {
        self.reps = reps
        self.kg = kg
    }
}

/// Calibrage des charges à la salle : les six mouvements de référence sont testés une fois
/// (montée par paliers jusqu'à une série de 5 lourde et propre), puis toutes les charges de
/// travail se calculent à partir du 1RM estimé. Protocole de test : NSCA (Haff et Triplett, 2016).
public enum StrengthCalibration {
    /// Deux séances de test espacées de 48 h : squat et soulevé de terre lourds ne se testent
    /// pas le même jour, sinon les derniers mouvements testés seraient sous-estimés.
    public static let testGroups: [[String]] = [
        ["Squat à la barre", "Développé couché", "Rowing barre"],
        ["Soulevé de terre", "Développé militaire", "Tirage vertical lourd"],
    ]

    public static var referenceLifts: [String] { testGroups.flatMap { $0 } }

    /// Répétitions de la série de test.
    public static let testReps = 5
    /// Paliers d'échauffement (puis 2 ou 3 essais), repos de 2 min 30 entre deux séries lourdes.
    static let testSets = 5
    static let testRestSeconds = 150
    /// Répétitions gardées en réserve sur les séries de travail.
    static let repsInReserve = 2

    /// Charge d'un exercice dérivé : fraction du 1RM d'un mouvement de référence. Repères
    /// prudents, pas des résultats d'étude : la première série notée sur l'exercice les remplace.
    static let derived: [String: (reference: String, ratio: Double)] = [
        "Squat goblet lourd": ("Squat à la barre", 0.35),
        "Presse à cuisses": ("Squat à la barre", 1.5),
        "Fentes bulgares haltères": ("Squat à la barre", 0.25),
        "Fentes marchées haltères": ("Squat à la barre", 0.25),
        "Step-ups haltères": ("Squat à la barre", 0.2),
        "Développé couché haltères": ("Développé couché", 0.4),
        "Développé à la machine": ("Développé couché", 0.9),
        "Soulevé de terre roumain": ("Soulevé de terre", 0.65),
        "Soulevé de terre roumain haltères": ("Soulevé de terre", 0.3),
        "Soulevé de terre à la trap bar": ("Soulevé de terre", 1.0),
        "Hip thrust": ("Soulevé de terre", 0.8),
        "Développé militaire haltères": ("Développé militaire", 0.4),
        "Développé épaules à la machine": ("Développé militaire", 0.9),
        "Rowing haltère": ("Rowing barre", 0.45),
        "Tirage horizontal à la poulie": ("Rowing barre", 0.9),
        "Tirage vertical prise serrée": ("Tirage vertical lourd", 1.0),
    ]

    /// Mouvements de référence sans charge notée, dans l'ordre des tests.
    public static func pending(calibrated: Set<String>) -> [String] {
        referenceLifts.filter { !calibrated.contains($0) }
    }

    /// Séance de test : les mouvements restants du premier groupe incomplet, autant que le temps le permet.
    public static func testWorkout(calibrated: Set<String>, budget: Int) -> Workout? {
        guard let index = testGroups.firstIndex(where: { $0.contains { !calibrated.contains($0) } }) else { return nil }
        var workout = Workout(
            title: "Test de force \(index + 1)/\(testGroups.count)",
            warmupMinutes: 5,
            cooldownMinutes: 2,
            exercises: [],
            intensityCue: "Série de test : 5 répétitions propres, la dernière difficile. Arrête dès que la technique se dégrade."
        )
        workout.isStrengthTest = true
        for name in testGroups[index] where !calibrated.contains(name) {
            var next = workout
            next.exercises.append(WorkoutExercise(
                name: name, sets: testSets, volume: .reps(testReps), restSeconds: testRestSeconds, priority: 1,
                loadsKnee: name == "Squat à la barre"
            ))
            guard next.estimatedMinutes <= budget || workout.exercises.isEmpty else { break }
            workout = next
        }
        return workout
    }

    /// Paliers d'échauffement avant la première série de test : 10 × 50 %, 5 × 70 %, 3 × 85 %.
    public static func ramp(for exercise: String, firstAttemptKg: Double) -> [RampStep] {
        let floor = usesBarbell(exercise) ? 20.0 : StrengthProgress.loadStep(for: firstAttemptKg)
        let warmups = [(10, 0.5), (5, 0.7), (3, 0.85)].map { reps, share in
            RampStep(reps: reps, kg: max(floor, nearest(firstAttemptKg * share)))
        }
        return warmups + [RampStep(reps: testReps, kg: firstAttemptKg)]
    }

    /// Hausse entre deux essais : environ 10 % pour les jambes, 5 % pour le haut du corps.
    public static func attemptIncrement(for exercise: String, from kg: Double) -> Double {
        let lowerBody = ["Squat à la barre", "Soulevé de terre"].contains(exercise)
        let step = lowerBody ? 5.0 : 2.5
        return max(step, (kg * (lowerBody ? 0.1 : 0.05) / 2.5).rounded() * 2.5)
    }

    /// Charge de travail pour `reps` répétitions en gardant 2 répétitions en réserve
    /// (Epley inversé sur reps + 2), arrondie vers le bas.
    public static func workingLoad(oneRepMax: Double, reps: Int) -> Double {
        let raw = oneRepMax / (1 + Double(reps + repsInReserve) / 30)
        return roundDown(raw)
    }

    /// Charge proposée pour un exercice jamais noté, tirée du test de son mouvement de référence.
    public static func derivedLoad(
        for exercise: String,
        plannedReps: Int,
        history: [LiftEntry],
        lastStrengthDay: Date? = nil,
        on date: Date? = nil,
        calendar: Calendar = .current
    ) -> Double? {
        guard let link = derived[exercise],
              let reference = StrengthProgress.referenceOneRepMax(
                  for: link.reference, history: history, lastStrengthDay: lastStrengthDay, on: date, calendar: calendar
              ) else { return nil }
        let load = workingLoad(oneRepMax: reference * link.ratio, reps: plannedReps)
        return load > 0 ? load : nil
    }

    static func usesBarbell(_ exercise: String) -> Bool {
        exercise != "Tirage vertical lourd"
    }

    static func nearest(_ kg: Double) -> Double {
        let step = StrengthProgress.loadStep(for: kg)
        return (kg / step).rounded() * step
    }

    static func roundDown(_ kg: Double) -> Double {
        let step = StrengthProgress.loadStep(for: kg)
        return (kg / step).rounded(.down) * step
    }
}
