import BodyPilotCore
import Foundation
import SwiftData

/// Schéma de la base, figé par version. Une prochaine modification d'un modèle ajoute un
/// `SchemaV2` (copie des modèles modifiés) et une étape de migration dans `BodyPilotMigrationPlan`,
/// au lieu de laisser SwiftData échouer à l'ouverture d'une base existante.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [ProfileRecord.self, WeightRecord.self, DayLogRecord.self, WeekPlanRecord.self, WaistRecord.self, LiftRecord.self, CardioTestRecord.self]
    }
}

enum BodyPilotMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

/// Jours enregistrés à minuit par les versions précédentes, ramenés à midi (voir
/// `Calendar.storedDay`) : en voyage vers l'ouest, minuit tombait la veille.
@MainActor
enum StoredDayMigration {
    private static let doneKey = "storedDayMigrationDone"

    static func run(in context: ModelContext, calendar: Calendar = .current, defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: doneKey) else { return }
        func moved(_ date: Date) -> Date? {
            calendar.isStoredAtMidnight(date) ? calendar.storedDay(for: date) : nil
        }
        for log in (try? context.fetch(FetchDescriptor<DayLogRecord>())) ?? [] {
            if let day = moved(log.day) { log.day = day }
        }
        for lift in (try? context.fetch(FetchDescriptor<LiftRecord>())) ?? [] {
            if let day = moved(lift.day) { lift.day = day }
        }
        for test in (try? context.fetch(FetchDescriptor<CardioTestRecord>())) ?? [] {
            if let day = moved(test.day) { test.day = day }
        }
        for profile in (try? context.fetch(FetchDescriptor<ProfileRecord>())) ?? [] {
            if let start = profile.cycleStartDate, let day = moved(start) { profile.cycleStartDate = day }
        }
        // Sans sauvegarde réussie, la migration sera retentée au prochain lancement.
        do {
            try context.save()
            defaults.set(true, forKey: doneKey)
        } catch {}
    }
}
