import BodyPilotCore
import Foundation
import HealthKit

/// Lecture des entraînements enregistrés dans Santé : Apple Watch, apps de course, de vélo…
enum HealthWorkouts {
    /// De quoi juger la régularité des semaines passées, pas seulement la semaine en cours.
    static let lookbackWeeks = 12

    static var workoutType: HKWorkoutType { HKObjectType.workoutType() }

    /// Santé ne dit pas si la lecture est refusée : dans ce cas la liste est simplement vide.
    static func samples(since start: Date) async throws -> [ActivitySample] {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(HKQuery.predicateForSamples(withStart: start, end: nil))],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let energy = HKQuantityType(.activeEnergyBurned)
        return try await descriptor.result(for: HKHealthStore()).map { workout in
            ActivitySample(
                id: workout.uuid.uuidString,
                kind: ActivityKind(workout.workoutActivityType),
                start: workout.startDate,
                minutes: workout.duration / 60,
                kcal: workout.statistics(for: energy)?.sumQuantity()?.doubleValue(for: .kilocalorie())
            )
        }
    }
}

extension ActivityKind {
    init(_ type: HKWorkoutActivityType) {
        switch type {
        case .traditionalStrengthTraining, .functionalStrengthTraining, .coreTraining, .crossTraining: self = .strength
        case .running: self = .running
        case .cycling, .handCycling: self = .cycling
        case .walking, .hiking: self = .walking
        case .swimming, .waterFitness: self = .swimming
        case .highIntensityIntervalTraining, .mixedCardio: self = .intervals
        case .yoga, .pilates, .flexibility, .mindAndBody, .cooldown, .preparationAndRecovery: self = .mobility
        case .soccer, .basketball, .tennis, .handball, .volleyball, .rugby, .badminton, .tableTennis, .squash, .racquetball, .pickleball:
            self = .sport
        case .boxing, .kickboxing, .martialArts, .wrestling: self = .combat
        case .elliptical, .rowing, .stairClimbing, .stairs, .stepTraining, .jumpRope, .dance, .cardioDance: self = .cardio
        default: self = .other
        }
    }

    var symbol: String {
        switch self {
        case .strength: "dumbbell.fill"
        case .running: "figure.run"
        case .cycling: "figure.outdoor.cycle"
        case .walking: "figure.walk"
        case .swimming: "figure.pool.swim"
        case .intervals: "figure.highintensity.intervaltraining"
        case .mobility: "figure.yoga"
        case .sport: "sportscourt.fill"
        case .combat: "figure.boxing"
        case .cardio: "figure.elliptical"
        case .other: "figure.mixed.cardio"
        }
    }
}
