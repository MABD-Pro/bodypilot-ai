import BodyPilotCore
import Foundation
import SwiftData

/// Schéma de la base, figé par version. Toute modification d'un modèle ajoute une version
/// (copie figée des modèles modifiés dans la version précédente) et une étape de migration dans
/// `BodyPilotMigrationPlan`, au lieu de laisser SwiftData échouer à l'ouverture d'une base existante.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [SchemaV1.ProfileRecord.self, WeightRecord.self, SchemaV2.DayLogRecord.self, WeekPlanRecord.self, WaistRecord.self, SchemaV3.LiftRecord.self, CardioTestRecord.self]
    }

    /// Profil tel qu'il était avant le questionnaire de santé.
    @Model
    final class ProfileRecord {
        var entityID: UUID = UUID()
        var createdAt: Date = Date.now
        var sexRaw: String = BiologicalSex.male.rawValue
        var birthDate: Date = Date.now
        var heightCm: Double = 175
        var startWeightKg: Double = 75
        var targetWeightKg: Double?
        var activityRaw: String = ActivityLevel.light.rawValue
        var goalRaw: String = Goal.recomposition.rawValue
        var trainingDaysPerWeek: Int = 3
        var trainingWeekdaysRaw: [Int] = []
        var sessionMinutes: Int = 45
        var equipmentRaw: String = Equipment.bodyweight.rawValue
        var calorieAdjustmentKcal: Double = 0
        var lastCheckInAt: Date?
        var strengthTestResetAt: Date?
        var cycleProgramRaw: String?
        var cycleStartDate: Date?
        var cycleSessionsPerWeek: Int = 0
        var cycleSessionsWeekStart: Date?

        init() {}
    }
}

/// V2 : questionnaire de santé dans le profil (`ProfileRecord.screening…`).
enum SchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [SchemaV3.ProfileRecord.self, WeightRecord.self, SchemaV2.DayLogRecord.self, WeekPlanRecord.self, WaistRecord.self, SchemaV3.LiftRecord.self, CardioTestRecord.self]
    }

    /// Journal du jour tel qu'il était avant les calories mangées (V1 et V2).
    @Model
    final class DayLogRecord {
        var day: Date = Date.now
        var adjustmentsRaw: [String] = []
        var availableMinutes: Int?
        var eatingOutSlotRaw: String?
        var exerciseSwapsRaw: [String] = []
        var workoutDone = false
        var doneWorkoutTitle: String?
        var mealIntakesRaw: [String] = []
        var describedMealsData: Data?
        var trainingChoiceRaw: String?
        var benchmarkSeconds: Int?
        var sessionEditsData: Data?
        var loadShiftsData: Data?

        init() {}
    }
}

/// V3 : calories mangées des journées complètes (`DayLogRecord.eatenKcal`), base de la dépense mesurée.
enum SchemaV3: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(3, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [SchemaV3.ProfileRecord.self, WeightRecord.self, DayLogRecord.self, WeekPlanRecord.self, WaistRecord.self, SchemaV3.LiftRecord.self, CardioTestRecord.self]
    }

    /// Profil tel qu'il était avant la semaine à l'équilibre (V2 et V3).
    @Model
    final class ProfileRecord {
        var entityID: UUID = UUID()
        var createdAt: Date = Date.now
        var sexRaw: String = BiologicalSex.male.rawValue
        var birthDate: Date = Date.now
        var heightCm: Double = 175
        var startWeightKg: Double = 75
        var targetWeightKg: Double?
        var activityRaw: String = ActivityLevel.light.rawValue
        var goalRaw: String = Goal.recomposition.rawValue
        var trainingDaysPerWeek: Int = 3
        var trainingWeekdaysRaw: [Int] = []
        var sessionMinutes: Int = 45
        var equipmentRaw: String = Equipment.bodyweight.rawValue
        var calorieAdjustmentKcal: Double = 0
        var lastCheckInAt: Date?
        var strengthTestResetAt: Date?
        var cycleProgramRaw: String?
        var cycleStartDate: Date?
        var cycleSessionsPerWeek: Int = 0
        var cycleSessionsWeekStart: Date?
        var screeningYesRaw: [String] = []
        var screeningSituationsRaw: [String] = []
        var screeningAnsweredAt: Date?
        var medicalClearance: Bool = false

        init() {}
    }

    /// Série notée telle qu'elle était avant l'effort ressenti (V1 à V3).
    @Model
    final class LiftRecord {
        var day: Date = Date.now
        var exercise: String = ""
        var kg: Double?
        var reps: Int = 0
        var isTest: Bool = false

        init() {}
    }
}

/// V4 : effort ressenti sur les séries (`LiftRecord.effortRaw`) et semaine à l'équilibre
/// (`ProfileRecord.maintenanceWeekUntil`, `maintenanceOfferDismissedAt`).
enum SchemaV4: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(4, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [SchemaV5.ProfileRecord.self, WeightRecord.self, DayLogRecord.self, WeekPlanRecord.self, WaistRecord.self, LiftRecord.self, CardioTestRecord.self]
    }
}

/// V5 : ressenti de la semaine (`WeekFeelingRecord`), nouveau modèle sans toucher aux autres.
enum SchemaV5: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(5, 0, 0) }

    static var models: [any PersistentModel.Type] {
        SchemaV4.models + [WeekFeelingRecord.self]
    }

    /// Profil tel qu'il était avant la semaine plancher (V4 et V5).
    @Model
    final class ProfileRecord {
        var entityID: UUID = UUID()
        var createdAt: Date = Date.now
        var sexRaw: String = BiologicalSex.male.rawValue
        var birthDate: Date = Date.now
        var heightCm: Double = 175
        var startWeightKg: Double = 75
        var targetWeightKg: Double?
        var activityRaw: String = ActivityLevel.light.rawValue
        var goalRaw: String = Goal.recomposition.rawValue
        var trainingDaysPerWeek: Int = 3
        var trainingWeekdaysRaw: [Int] = []
        var sessionMinutes: Int = 45
        var equipmentRaw: String = Equipment.bodyweight.rawValue
        var calorieAdjustmentKcal: Double = 0
        var lastCheckInAt: Date?
        var strengthTestResetAt: Date?
        var cycleProgramRaw: String?
        var cycleStartDate: Date?
        var cycleSessionsPerWeek: Int = 0
        var cycleSessionsWeekStart: Date?
        var screeningYesRaw: [String] = []
        var screeningSituationsRaw: [String] = []
        var screeningAnsweredAt: Date?
        var medicalClearance: Bool = false
        var maintenanceWeekUntil: Date?
        var maintenanceOfferDismissedAt: Date?

        init() {}
    }
}

/// V6 : semaine plancher après un décrochage (`ProfileRecord.floorWeekUntil`, `comebackDismissedAt`,
/// `floorProteinDays`).
enum SchemaV6: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(6, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [SchemaV6.ProfileRecord.self, WeightRecord.self, DayLogRecord.self, WeekPlanRecord.self, WaistRecord.self, LiftRecord.self, CardioTestRecord.self, WeekFeelingRecord.self]
    }

    /// Profil tel qu'il était avant les préférences alimentaires (V6).
    @Model
    final class ProfileRecord {
        var entityID: UUID = UUID()
        var createdAt: Date = Date.now
        var sexRaw: String = BiologicalSex.male.rawValue
        var birthDate: Date = Date.now
        var heightCm: Double = 175
        var startWeightKg: Double = 75
        var targetWeightKg: Double?
        var activityRaw: String = ActivityLevel.light.rawValue
        var goalRaw: String = Goal.recomposition.rawValue
        var trainingDaysPerWeek: Int = 3
        var trainingWeekdaysRaw: [Int] = []
        var sessionMinutes: Int = 45
        var equipmentRaw: String = Equipment.bodyweight.rawValue
        var calorieAdjustmentKcal: Double = 0
        var lastCheckInAt: Date?
        var strengthTestResetAt: Date?
        var cycleProgramRaw: String?
        var cycleStartDate: Date?
        var cycleSessionsPerWeek: Int = 0
        var cycleSessionsWeekStart: Date?
        var screeningYesRaw: [String] = []
        var screeningSituationsRaw: [String] = []
        var screeningAnsweredAt: Date?
        var medicalClearance: Bool = false
        var maintenanceWeekUntil: Date?
        var maintenanceOfferDismissedAt: Date?
        var floorWeekUntil: Date?
        var comebackDismissedAt: Date?
        var floorProteinDays: [Date] = []

        init() {}
    }
}

/// V7 : aliments à éviter dans les repas proposés (`ProfileRecord.avoidedFoodsRaw`).
enum SchemaV7: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(7, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [ProfileRecord.self, WeightRecord.self, DayLogRecord.self, WeekPlanRecord.self, WaistRecord.self, LiftRecord.self, CardioTestRecord.self, WeekFeelingRecord.self]
    }
}

enum BodyPilotMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self, SchemaV3.self, SchemaV4.self, SchemaV5.self, SchemaV6.self, SchemaV7.self] }
    /// Champs ou modèles ajoutés avec une valeur par défaut : migrations légères, sans perte.
    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self),
            .lightweight(fromVersion: SchemaV2.self, toVersion: SchemaV3.self),
            .lightweight(fromVersion: SchemaV3.self, toVersion: SchemaV4.self),
            .lightweight(fromVersion: SchemaV4.self, toVersion: SchemaV5.self),
            .lightweight(fromVersion: SchemaV5.self, toVersion: SchemaV6.self),
            .lightweight(fromVersion: SchemaV6.self, toVersion: SchemaV7.self),
        ]
    }
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
