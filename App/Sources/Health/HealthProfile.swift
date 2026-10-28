import BodyPilotCore
import Foundation
import HealthKit

/// Taille, date de naissance et sexe renseignés dans Santé : le profil les reprend pour que
/// les besoins caloriques restent justes sans rien ressaisir.
enum HealthProfile {
    static var heightType: HKQuantityType { HKQuantityType(.height) }
    static var readTypes: Set<HKObjectType> {
        [heightType, HKCharacteristicType(.dateOfBirth), HKCharacteristicType(.biologicalSex)]
    }

    struct Values: Equatable {
        var heightCm: Double?
        var birthDate: Date?
        var sex: BiologicalSex?
    }

    /// Ce que Santé connaît ; chaque valeur absente ou refusée reste `nil`.
    static func read(calendar: Calendar = .current) async -> Values {
        let store = HKHealthStore()
        var values = Values()
        if let components = try? store.dateOfBirthComponents() {
            // Santé donne la date de naissance dans le calendrier grégorien, quel que soit
            // celui de l'appareil (bouddhiste, japonais…).
            var gregorian = Calendar(identifier: .gregorian)
            gregorian.timeZone = calendar.timeZone
            values.birthDate = (components.calendar ?? gregorian).date(from: components)
        }
        switch (try? store.biologicalSex())?.biologicalSex {
        case .male: values.sex = .male
        case .female: values.sex = .female
        default: break
        }
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: heightType, predicate: nil)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: 1
        )
        if let sample = try? await descriptor.result(for: store).first {
            values.heightCm = (sample.quantity.doubleValue(for: .meterUnit(with: .centi))).rounded()
        }
        return values
    }
}
