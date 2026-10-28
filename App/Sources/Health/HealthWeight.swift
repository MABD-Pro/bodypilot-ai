import BodyPilotCore
import Foundation
import HealthKit

/// Lecture seule du poids dans Santé : la balance connectée remplit le suivi, sans saisie.
///
/// Chaque appel crée son propre `HKHealthStore` (objet léger) pour rester hors de tout acteur.
enum HealthWeight {
    /// Profondeur de l'import : de quoi tracer la tendance dès la connexion.
    static let lookbackDays = 90

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private static var bodyMass: HKQuantityType { HKQuantityType(.bodyMass) }

    /// Affiche la feuille d'autorisation de Santé : lecture du poids, des pas et des entraînements, écriture des repas.
    /// Une seule fois par type ; ensuite, sans effet. Le suivi de cycle n'est demandé qu'aux femmes.
    static func requestAccess(includeCycle: Bool = false) async throws {
        var read = Set<HKObjectType>([bodyMass, HealthWorkouts.workoutType, HealthSleep.sleepType, HealthCardio.vo2MaxType, HealthCardio.restingHeartRateType, HealthSteps.stepType])
            .union(HealthProfile.readTypes)
            .union(HealthBodyComposition.readTypes)
        if includeCycle { read.insert(HealthCycle.menstrualFlowType) }
        try await HKHealthStore().requestAuthorization(toShare: HealthMeals.writtenTypes, read: read)
    }

    /// Pesées enregistrées depuis une date. Santé ne dit pas si la lecture est refusée :
    /// dans ce cas la liste est simplement vide.
    static func samples(since start: Date) async throws -> [WeightSample] {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: bodyMass, predicate: HKQuery.predicateForSamples(withStart: start, end: nil))],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let results = try await descriptor.result(for: HKHealthStore())
        return results.map {
            WeightSample(id: $0.uuid.uuidString, date: $0.startDate, kg: $0.quantity.doubleValue(for: .gramUnit(with: .kilo)))
        }
    }
}
