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
    var goalRaw: String = Goal.recomposition.rawValue
    var trainingDaysPerWeek: Int = 3
    /// Jours de séance habituels (1 = dimanche … 7 = samedi). Vide : répartition par défaut.
    var trainingWeekdaysRaw: [Int] = []
    var sessionMinutes: Int = 45
    var equipmentRaw: String = Equipment.bodyweight.rawValue
    /// Correction issue des bilans hebdomadaires ; jamais écrasée par l'édition du profil.
    var calorieAdjustmentKcal: Double = 0
    /// Dernier bilan proposé (accepté ou non) : un seul par semaine.
    var lastCheckInAt: Date?
    /// « Refaire le test de force » : les charges notées avant cette date ne comptent plus comme calibrées.
    var strengthTestResetAt: Date?

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
        trainingWeekdaysRaw = profile.trainingWeekdays
        sessionMinutes = profile.sessionMinutes
        equipmentRaw = profile.equipment.rawValue
    }

    /// Le bilan revient au plus une fois par semaine.
    func isCheckInDue(at date: Date) -> Bool {
        guard let lastCheckInAt else { return true }
        return date.timeIntervalSince(lastCheckInAt) >= 7 * 86_400
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
            // Un seul objectif dans l'app : les anciens profils passent aussi en recomposition.
            goal: .recomposition,
            trainingDaysPerWeek: trainingDaysPerWeek,
            trainingWeekdays: trainingWeekdaysRaw.isEmpty ? nil : trainingWeekdaysRaw,
            sessionMinutes: sessionMinutes,
            equipment: Equipment(rawValue: equipmentRaw) ?? .bodyweight,
            calorieAdjustmentKcal: calorieAdjustmentKcal
        )
    }
}

enum WeightSource: String {
    case manual
    case health
}

@Model
final class WeightRecord {
    var date: Date = Date.now
    var kg: Double = 0
    var sourceRaw: String = WeightSource.manual.rawValue
    /// Identifiant de la mesure dans Santé, pour ne pas l'importer deux fois.
    var externalID: String?

    init(date: Date, kg: Double) {
        self.date = date
        self.kg = kg
    }

    init(_ sample: WeightSample) {
        date = sample.date
        kg = (sample.kg * 10).rounded() / 10
        sourceRaw = WeightSource.health.rawValue
        externalID = sample.id
    }

    var entry: WeightEntry { WeightEntry(date: date, kg: kg) }
}

/// Tour de taille, saisi à la main une fois par semaine.
@Model
final class WaistRecord {
    var date: Date = Date.now
    var cm: Double = 0

    init(date: Date, cm: Double) {
        self.date = date
        self.cm = cm
    }

    var entry: WaistEntry { WaistEntry(date: date, cm: cm) }
}

/// Jours de séance d'une semaine donnée, quand ils diffèrent des jours habituels.
@Model
final class WeekPlanRecord {
    /// Début de la semaine (selon le calendrier de l'appareil).
    var weekStart: Date = Date.now
    var weekdaysRaw: [Int] = []

    init(weekStart: Date, weekdays: [Int]) {
        self.weekStart = weekStart
        self.weekdaysRaw = weekdays
    }
}

/// Ajustements déclarés pour une journée : la mémoire des décisions du coach.
@Model
final class DayLogRecord {
    var day: Date = Date.now
    var adjustmentsRaw: [String] = []
    /// Temps précis annoncé en phrase libre (« j'ai 15 min »).
    var availableMinutes: Int?
    /// Repas pris au restaurant, s'il a été précisé (« ce soir »).
    var eatingOutSlotRaw: String?
    /// Une entrée par remplacement demandé, par clé d'exercice (le coach passe à la variante suivante).
    var exerciseSwapsRaw: [String] = []
    /// Séance du jour cochée comme faite : base de la régularité affichée dans Progresser.
    var workoutDone = false
    /// Séance cochée, pour que la prochaine séance en plus enchaîne sur la suivante.
    var doneWorkoutTitle: String?
    /// Repas déjà pris, au format « lunch=hearty ».
    var mealIntakesRaw: [String] = []
    /// Repas décrits en texte, encodés en JSON (aliments et estimations).
    var describedMealsData: Data?
    /// Proposition d'entraînement choisie ; `nil` : celle que le coach recommande.
    var trainingChoiceRaw: String?

    var trainingChoice: TrainingChoice? {
        get { trainingChoiceRaw.flatMap(TrainingChoice.init(rawValue:)) }
        set { trainingChoiceRaw = newValue?.rawValue }
    }

    var describedMeals: [MealSlot: DescribedMeal] {
        get {
            guard let describedMealsData,
                  let stored = try? JSONDecoder().decode([String: DescribedMeal].self, from: describedMealsData)
            else { return [:] }
            return Dictionary(uniqueKeysWithValues: stored.compactMap { key, meal in MealSlot(rawValue: key).map { ($0, meal) } })
        }
        set {
            let stored = Dictionary(uniqueKeysWithValues: newValue.map { ($0.key.rawValue, $0.value) })
            describedMealsData = stored.isEmpty ? nil : try? JSONEncoder().encode(stored)
        }
    }

    var mealIntakes: [MealSlot: MealIntake] {
        get {
            Dictionary(mealIntakesRaw.compactMap { entry -> (MealSlot, MealIntake)? in
                let parts = entry.split(separator: "=").map(String.init)
                guard parts.count == 2, let slot = MealSlot(rawValue: parts[0]), let intake = MealIntake(rawValue: parts[1]) else { return nil }
                return (slot, intake)
            }, uniquingKeysWith: { _, last in last })
        }
        set { mealIntakesRaw = newValue.map { "\($0.key.rawValue)=\($0.value.rawValue)" }.sorted() }
    }

    var exerciseSwaps: [String: Int] {
        exerciseSwapsRaw.reduce(into: [:]) { $0[$1, default: 0] += 1 }
    }

    var eatingOutSlot: MealSlot? {
        get { eatingOutSlotRaw.flatMap(MealSlot.init(rawValue:)) }
        set { eatingOutSlotRaw = newValue?.rawValue }
    }

    init(day: Date) {
        self.day = day
    }

    var adjustments: Set<QuickAdjustment> {
        get { Set(adjustmentsRaw.compactMap(QuickAdjustment.init(rawValue:))) }
        set { adjustmentsRaw = newValue.map(\.rawValue).sorted() }
    }
}

/// Meilleure série d'un exercice pour une séance : base des records et de la progression des charges.
@Model
final class LiftRecord {
    var day: Date = Date.now
    var exercise: String = ""
    /// `nil` au poids du corps.
    var kg: Double?
    var reps: Int = 0
    /// Série de test du calibrage.
    var isTest: Bool = false

    init(_ entry: LiftEntry) {
        day = entry.date
        exercise = entry.exercise
        kg = entry.kg
        reps = entry.reps
        isTest = entry.isTest
    }

    var entry: LiftEntry { LiftEntry(exercise: exercise, date: day, kg: kg, reps: reps, isTest: isTest) }
}
