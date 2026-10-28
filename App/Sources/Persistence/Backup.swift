import BodyPilotCore
import Foundation
import SwiftData

/// Sauvegarde complète des données de l'app dans un fichier que l'utilisateur range où il veut
/// (Fichiers, AirDrop, Mail). Rien ne part automatiquement dans iCloud : la règle 5.1.3(ii) de
/// l'App Store interdit d'y stocker des données de santé, et la synchronisation passera par le
/// backend. Les données lues dans Santé y sont aussi : Santé les garde de son côté.
struct BackupArchive: Codable {
    /// Format du fichier : une version suivante saura relire les anciennes.
    var format = 1
    var exportedAt = Date.now
    var profiles: [Profile] = []
    var weights: [Weight] = []
    var waists: [Waist] = []
    var weekPlans: [WeekPlan] = []
    var dayLogs: [DayLog] = []
    var lifts: [Lift] = []
    var cardioTests: [CardioTest] = []

    struct Profile: Codable {
        var entityID: UUID
        var createdAt: Date
        var sexRaw: String
        var birthDate: Date
        var heightCm: Double
        var startWeightKg: Double
        var targetWeightKg: Double?
        var activityRaw: String
        var goalRaw: String
        var trainingDaysPerWeek: Int
        var trainingWeekdaysRaw: [Int]
        var sessionMinutes: Int
        var equipmentRaw: String
        var calorieAdjustmentKcal: Double
        var lastCheckInAt: Date?
        var strengthTestResetAt: Date?
        var cycleProgramRaw: String?
        var cycleStartDate: Date?
        var cycleSessionsPerWeek: Int
        var cycleSessionsWeekStart: Date?
        // Questionnaire de santé : absents des sauvegardes plus anciennes.
        var screeningYesRaw: [String]?
        var screeningSituationsRaw: [String]?
        var screeningAnsweredAt: Date?
        var medicalClearance: Bool?
        // Semaine à l'équilibre : absente des sauvegardes plus anciennes.
        var maintenanceWeekUntil: Date?
        var maintenanceOfferDismissedAt: Date?
    }

    struct Weight: Codable {
        var date: Date
        var kg: Double
        var sourceRaw: String
        var externalID: String?
    }

    struct Waist: Codable {
        var date: Date
        var cm: Double
        var isScan: Bool
    }

    struct WeekPlan: Codable {
        var weekStart: Date
        var weekdaysRaw: [Int]
    }

    struct DayLog: Codable {
        var day: Date
        var adjustmentsRaw: [String]
        var availableMinutes: Int?
        var eatingOutSlotRaw: String?
        var exerciseSwapsRaw: [String]
        var workoutDone: Bool
        var doneWorkoutTitle: String?
        var mealIntakesRaw: [String]
        var describedMealsData: Data?
        var trainingChoiceRaw: String?
        var benchmarkSeconds: Int?
        var sessionEditsData: Data?
        var loadShiftsData: Data?
        /// Absent des sauvegardes plus anciennes.
        var eatenKcal: Double?
    }

    struct Lift: Codable {
        var day: Date
        var exercise: String
        var kg: Double?
        var reps: Int
        var isTest: Bool
        /// Absent des sauvegardes plus anciennes.
        var effortRaw: String?
    }

    struct CardioTest: Codable {
        var day: Date
        var minutes: Double
        var heartRate: Int
        var vo2max: Double
    }

    var isEmpty: Bool { profiles.isEmpty }

    /// « 1 profil, 84 pesées, 120 jours, 56 séries »
    var summary: String {
        "\(weights.count) pesée\(weights.count > 1 ? "s" : ""), \(dayLogs.count) jour\(dayLogs.count > 1 ? "s" : ""), "
            + "\(lifts.count) série\(lifts.count > 1 ? "s" : "") notée\(lifts.count > 1 ? "s" : "")"
    }
}

@MainActor
enum Backup {
    /// Toutes les données de la base, dans un fichier JSON lisible.
    static func archive(from context: ModelContext) throws -> BackupArchive {
        var archive = BackupArchive()
        archive.profiles = try context.fetch(FetchDescriptor<ProfileRecord>()).map {
            .init(
                entityID: $0.entityID, createdAt: $0.createdAt, sexRaw: $0.sexRaw, birthDate: $0.birthDate, heightCm: $0.heightCm,
                startWeightKg: $0.startWeightKg, targetWeightKg: $0.targetWeightKg, activityRaw: $0.activityRaw, goalRaw: $0.goalRaw,
                trainingDaysPerWeek: $0.trainingDaysPerWeek, trainingWeekdaysRaw: $0.trainingWeekdaysRaw, sessionMinutes: $0.sessionMinutes,
                equipmentRaw: $0.equipmentRaw, calorieAdjustmentKcal: $0.calorieAdjustmentKcal, lastCheckInAt: $0.lastCheckInAt,
                strengthTestResetAt: $0.strengthTestResetAt, cycleProgramRaw: $0.cycleProgramRaw, cycleStartDate: $0.cycleStartDate,
                cycleSessionsPerWeek: $0.cycleSessionsPerWeek, cycleSessionsWeekStart: $0.cycleSessionsWeekStart,
                screeningYesRaw: $0.screeningYesRaw, screeningSituationsRaw: $0.screeningSituationsRaw,
                screeningAnsweredAt: $0.screeningAnsweredAt, medicalClearance: $0.medicalClearance,
                maintenanceWeekUntil: $0.maintenanceWeekUntil, maintenanceOfferDismissedAt: $0.maintenanceOfferDismissedAt
            )
        }
        archive.weights = try context.fetch(FetchDescriptor<WeightRecord>(sortBy: [SortDescriptor(\.date)])).map {
            .init(date: $0.date, kg: $0.kg, sourceRaw: $0.sourceRaw, externalID: $0.externalID)
        }
        archive.waists = try context.fetch(FetchDescriptor<WaistRecord>(sortBy: [SortDescriptor(\.date)])).map {
            .init(date: $0.date, cm: $0.cm, isScan: $0.isScan)
        }
        archive.weekPlans = try context.fetch(FetchDescriptor<WeekPlanRecord>()).map {
            .init(weekStart: $0.weekStart, weekdaysRaw: $0.weekdaysRaw)
        }
        archive.dayLogs = try context.fetch(FetchDescriptor<DayLogRecord>(sortBy: [SortDescriptor(\.day)])).map {
            .init(
                day: $0.day, adjustmentsRaw: $0.adjustmentsRaw, availableMinutes: $0.availableMinutes, eatingOutSlotRaw: $0.eatingOutSlotRaw,
                exerciseSwapsRaw: $0.exerciseSwapsRaw, workoutDone: $0.workoutDone, doneWorkoutTitle: $0.doneWorkoutTitle,
                mealIntakesRaw: $0.mealIntakesRaw, describedMealsData: $0.describedMealsData, trainingChoiceRaw: $0.trainingChoiceRaw,
                benchmarkSeconds: $0.benchmarkSeconds, sessionEditsData: $0.sessionEditsData, loadShiftsData: $0.loadShiftsData,
                eatenKcal: $0.eatenKcal
            )
        }
        archive.lifts = try context.fetch(FetchDescriptor<LiftRecord>(sortBy: [SortDescriptor(\.day)])).map {
            .init(day: $0.day, exercise: $0.exercise, kg: $0.kg, reps: $0.reps, isTest: $0.isTest, effortRaw: $0.effortRaw)
        }
        archive.cardioTests = try context.fetch(FetchDescriptor<CardioTestRecord>(sortBy: [SortDescriptor(\.day)])).map {
            .init(day: $0.day, minutes: $0.minutes, heartRate: $0.heartRate, vo2max: $0.vo2max)
        }
        return archive
    }

    static func encode(_ archive: BackupArchive) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(archive)
    }

    static func decode(_ data: Data) throws -> BackupArchive {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(BackupArchive.self, from: data)
    }

    /// Nom proposé : « BodyPilot-2026-10-28.json ».
    static func fileName(on date: Date = .now) -> String {
        "BodyPilot-\(date.formatted(.iso8601.year().month().day())).json"
    }

    /// Remplace toutes les données par celles de la sauvegarde. Rien n'est effacé si le fichier
    /// est vide ou si l'écriture échoue : les changements sont annulés avant d'être enregistrés.
    static func restore(_ archive: BackupArchive, into context: ModelContext) throws {
        guard !archive.isEmpty else { throw BackupError.empty }
        try context.save()
        do {
            func deleteAll<Model: PersistentModel>(_: Model.Type) throws {
                for record in try context.fetch(FetchDescriptor<Model>()) { context.delete(record) }
            }
            try deleteAll(WeightRecord.self)
            try deleteAll(WaistRecord.self)
            try deleteAll(WeekPlanRecord.self)
            try deleteAll(DayLogRecord.self)
            try deleteAll(LiftRecord.self)
            try deleteAll(CardioTestRecord.self)

            // Le profil affiché est mis à jour plutôt que remplacé : l'écran Aujourd'hui le tient,
            // et un profil effacé sous ses yeux ferait planter l'app.
            var profiles = try context.fetch(FetchDescriptor<ProfileRecord>(sortBy: [SortDescriptor(\.createdAt)]))
            for item in archive.profiles {
                let record: ProfileRecord
                if profiles.isEmpty {
                    record = ProfileRecord(entityID: item.entityID)
                    context.insert(record)
                } else {
                    record = profiles.removeFirst()
                    record.entityID = item.entityID
                }
                record.createdAt = item.createdAt
                record.sexRaw = item.sexRaw
                record.birthDate = item.birthDate
                record.heightCm = item.heightCm
                record.startWeightKg = item.startWeightKg
                record.targetWeightKg = item.targetWeightKg
                record.activityRaw = item.activityRaw
                record.goalRaw = item.goalRaw
                record.trainingDaysPerWeek = item.trainingDaysPerWeek
                record.trainingWeekdaysRaw = item.trainingWeekdaysRaw
                record.sessionMinutes = item.sessionMinutes
                record.equipmentRaw = item.equipmentRaw
                record.calorieAdjustmentKcal = item.calorieAdjustmentKcal
                record.lastCheckInAt = item.lastCheckInAt
                record.strengthTestResetAt = item.strengthTestResetAt
                record.cycleProgramRaw = item.cycleProgramRaw
                record.cycleStartDate = item.cycleStartDate
                record.cycleSessionsPerWeek = item.cycleSessionsPerWeek
                record.cycleSessionsWeekStart = item.cycleSessionsWeekStart
                record.screeningYesRaw = item.screeningYesRaw ?? []
                record.screeningSituationsRaw = item.screeningSituationsRaw ?? []
                record.screeningAnsweredAt = item.screeningAnsweredAt
                record.medicalClearance = item.medicalClearance ?? false
                record.maintenanceWeekUntil = item.maintenanceWeekUntil
                record.maintenanceOfferDismissedAt = item.maintenanceOfferDismissedAt
            }
            for extra in profiles { context.delete(extra) }
            for item in archive.weights {
                let record = WeightRecord(date: item.date, kg: item.kg)
                record.sourceRaw = item.sourceRaw
                record.externalID = item.externalID
                context.insert(record)
            }
            for item in archive.waists {
                context.insert(WaistRecord(date: item.date, cm: item.cm, isScan: item.isScan))
            }
            for item in archive.weekPlans {
                context.insert(WeekPlanRecord(weekStart: item.weekStart, weekdays: item.weekdaysRaw))
            }
            for item in archive.dayLogs {
                let record = DayLogRecord(day: item.day)
                record.adjustmentsRaw = item.adjustmentsRaw
                record.availableMinutes = item.availableMinutes
                record.eatingOutSlotRaw = item.eatingOutSlotRaw
                record.exerciseSwapsRaw = item.exerciseSwapsRaw
                record.workoutDone = item.workoutDone
                record.doneWorkoutTitle = item.doneWorkoutTitle
                record.mealIntakesRaw = item.mealIntakesRaw
                record.describedMealsData = item.describedMealsData
                record.trainingChoiceRaw = item.trainingChoiceRaw
                record.benchmarkSeconds = item.benchmarkSeconds
                record.sessionEditsData = item.sessionEditsData
                record.loadShiftsData = item.loadShiftsData
                record.eatenKcal = item.eatenKcal
                context.insert(record)
            }
            for item in archive.lifts {
                context.insert(LiftRecord(LiftEntry(exercise: item.exercise, date: item.day, kg: item.kg, reps: item.reps, isTest: item.isTest, effort: item.effortRaw.flatMap(SetEffort.init(rawValue:)))))
            }
            for item in archive.cardioTests {
                context.insert(CardioTestRecord(day: item.day, minutes: item.minutes, heartRate: item.heartRate, vo2max: item.vo2max))
            }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}

enum BackupError: LocalizedError {
    case empty

    var errorDescription: String? {
        switch self {
        case .empty: "Ce fichier ne contient pas de profil BodyPilot."
        }
    }
}
