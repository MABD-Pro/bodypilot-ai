import BodyPilotCore
import Coach
import Foundation
import SwiftData

// Persistance locale (source de vérité). Toutes les propriétés ont une valeur par défaut
// pour rester compatibles avec une future synchronisation.

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
    var goalRaw: String = Goal.loseFat.rawValue
    var trainingDaysPerWeek: Int = 3
    var sessionMinutes: Int = 45
    var equipmentRaw: String = Equipment.bodyweight.rawValue

    init(_ profile: UserProfile) {
        entityID = profile.id.rawValue
        update(from: profile)
    }

    func update(from profile: UserProfile) {
        sexRaw = profile.sex.rawValue
        birthDate = profile.birthDate
        heightCm = profile.heightCm
        startWeightKg = profile.startWeightKg
        targetWeightKg = profile.targetWeightKg
        activityRaw = profile.activity.rawValue
        goalRaw = profile.goal.rawValue
        trainingDaysPerWeek = profile.trainingDaysPerWeek
        sessionMinutes = profile.sessionMinutes
        equipmentRaw = profile.equipment.rawValue
    }

    var profile: UserProfile {
        UserProfile(
            id: EntityID(entityID),
            sex: BiologicalSex(rawValue: sexRaw) ?? .male,
            birthDate: birthDate,
            heightCm: heightCm,
            startWeightKg: startWeightKg,
            targetWeightKg: targetWeightKg,
            activity: ActivityLevel(rawValue: activityRaw) ?? .light,
            goal: Goal(rawValue: goalRaw) ?? .loseFat,
            trainingDaysPerWeek: trainingDaysPerWeek,
            sessionMinutes: sessionMinutes,
            equipment: Equipment(rawValue: equipmentRaw) ?? .bodyweight
        )
    }
}

@Model
final class WeightRecord {
    var date: Date = Date.now
    var kg: Double = 0

    init(date: Date, kg: Double) {
        self.date = date
        self.kg = kg
    }

    var entry: WeightEntry { WeightEntry(date: date, kg: kg) }
}

/// Ajustements déclarés pour une journée : la mémoire des décisions du coach.
@Model
final class DayLogRecord {
    var day: Date = Date.now
    var adjustmentsRaw: [String] = []
    /// Temps précis annoncé en phrase libre (« j'ai 15 min »).
    var availableMinutes: Int?

    init(day: Date) {
        self.day = day
    }

    var adjustments: Set<QuickAdjustment> {
        get { Set(adjustmentsRaw.compactMap(QuickAdjustment.init(rawValue:))) }
        set { adjustmentsRaw = newValue.map(\.rawValue).sorted() }
    }
}
