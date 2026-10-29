import BodyPilotCore
import Foundation
import HealthKit
import Nutrition

/// Écriture des repas mangés dans Santé (rubrique Nutrition) : calories, protéines, glucides, lipides.
///
/// Chaque repas donne quatre valeurs nommées d'après le repas, repérées par un identifiant stable
/// (jour + repas) : une modification remplace les valeurs, une annulation les supprime. Les envois passent
/// un par un, pour ne jamais créer de doublon quand l'utilisateur touche vite.
actor HealthMeals {
    static let shared = HealthMeals()

    /// Clé de métadonnée propre à BodyPilot, posée sur chaque valeur envoyée.
    static let mealIDKey = "BodyPilotMealID"

    private static let energy = HKQuantityType(.dietaryEnergyConsumed)
    private static let protein = HKQuantityType(.dietaryProtein)
    private static let carbs = HKQuantityType(.dietaryCarbohydrates)
    private static let fat = HKQuantityType(.dietaryFatTotal)

    private static let types = [energy, protein, carbs, fat]
    static var writtenTypes: Set<HKSampleType> { Set(types) }

    private var pending: Task<Void, Never>?

    /// Met Santé en accord avec les repas du jour : `entries` mangés, les autres `ids` retirés.
    func sync(_ entries: [HealthMealEntry], ids: [String]) {
        let previous = pending
        pending = Task {
            await previous?.value
            await Self.apply(entries, ids: ids)
        }
    }

    private static func apply(_ entries: [HealthMealEntry], ids: [String]) async {
        let store = HKHealthStore()
        // Santé autorise chaque valeur à part : seules les autorisées partent.
        // Aucune autorisée : rien à faire, l'app marche sans.
        let allowed = types.filter { store.authorizationStatus(for: $0) == .sharingAuthorized }
        guard !allowed.isEmpty else { return }
        // Une autorisation ajoutée plus tard renvoie les repas avec la valeur manquante.
        let allowedKey = allowed.map(\.identifier).joined(separator: ",")
        let defaults = UserDefaults.standard
        for id in ids {
            let wanted = entries.first { $0.id == id }
            let sentKey = "healthMeal.\(id)"
            let sent = defaults.string(forKey: sentKey)
            let fingerprint = wanted.map { "\($0.fingerprint)#\(allowedKey)" }
            guard fingerprint != sent else { continue }
            do {
                // Même sans trace d'envoi (app réinstallée) : jamais de doublon.
                try await delete(id, in: store, types: allowed)
                if let wanted {
                    try await store.save(samples(for: wanted).filter { allowed.contains($0.quantityType) })
                    defaults.set(fingerprint, forKey: sentKey)
                } else {
                    defaults.removeObject(forKey: sentKey)
                }
            } catch {
                // Réessayé au prochain changement ou au prochain retour dans l'app.
                AppLog.health.error("Repas non envoyé à Santé : \(error.localizedDescription, privacy: .public)")
                continue
            }
        }
    }

    private static func samples(for entry: HealthMealEntry) -> [HKQuantitySample] {
        let metadata: [String: Any] = [mealIDKey: entry.id, HKMetadataKeyFoodType: entry.title]
        let values: [(HKQuantityType, HKUnit, Double)] = [
            (energy, .kilocalorie(), entry.macros.kcal),
            (protein, .gram(), entry.macros.proteinG),
            (carbs, .gram(), entry.macros.carbsG),
            (fat, .gram(), entry.macros.fatG),
        ]
        return values.map { type, unit, value in
            HKQuantitySample(
                type: type,
                quantity: HKQuantity(unit: unit, doubleValue: max(0, value)),
                start: entry.date,
                end: entry.date,
                metadata: metadata
            )
        }
    }

    /// Retire les quatre valeurs envoyées pour ce repas.
    private static func delete(_ id: String, in store: HKHealthStore, types: [HKQuantityType]) async throws {
        let predicate = HKQuery.predicateForObjects(withMetadataKey: mealIDKey, allowedValues: [id])
        for type in types {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                store.deleteObjects(of: type, predicate: predicate) { _, _, error in
                    // Rien à supprimer n'est pas une erreur.
                    if let error, (error as? HKError)?.code != .errorNoData {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
    }
}
