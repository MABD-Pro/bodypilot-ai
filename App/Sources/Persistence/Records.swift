import BodyPilotCore
import Coach
import Foundation
import ProgressInsights
import SwiftData
import Training

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
    /// Cycle de 12 semaines en cours ; `nil` : séances au jour le jour, sans cycle.
    var cycleProgramRaw: String?
    var cycleStartDate: Date?
    /// Séances prévues par semaine du cycle (2 à 6) ; 0 : jamais répondu.
    var cycleSessionsPerWeek: Int = 0
    /// Premier jour de la semaine du cycle où ce nombre a été confirmé.
    var cycleSessionsWeekStart: Date?
    /// Questionnaire de santé (schéma V2) : questions répondues oui, situations sans déficit,
    /// date de réponse (`nil` : jamais répondu) et accord du médecin.
    var screeningYesRaw: [String] = []
    var screeningSituationsRaw: [String] = []
    var screeningAnsweredAt: Date?
    var medicalClearance: Bool = false
    /// Semaine à l'équilibre après un long déficit : fin prévue, et dernier « Pas maintenant ».
    var maintenanceWeekUntil: Date?
    var maintenanceOfferDismissedAt: Date?
    /// Semaine plancher après un décrochage (schéma V6) : fin prévue, et dernier « Plus tard ».
    var floorWeekUntil: Date?
    var comebackDismissedAt: Date?
    /// Jours de la semaine plancher où les protéines ont été atteintes (à midi, `Calendar.storedDay`).
    var floorProteinDays: [Date] = []

    init(_ profile: UserProfile) {
        entityID = profile.id.rawValue
        update(from: profile)
    }

    /// Profil relu d'une sauvegarde : ses champs sont remplis un à un.
    init(entityID: UUID) {
        self.entityID = entityID
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
        screening = profile.screening
    }

    var screening: HealthScreening {
        get {
            HealthScreening(
                answeredAt: screeningAnsweredAt,
                yes: Set(screeningYesRaw.compactMap(ScreeningQuestion.init(rawValue:))),
                situations: Set(screeningSituationsRaw.compactMap(NoDeficitSituation.init(rawValue:))),
                medicalClearance: medicalClearance
            )
        }
        set {
            screeningAnsweredAt = newValue.answeredAt
            screeningYesRaw = newValue.yes.map(\.rawValue).sorted()
            screeningSituationsRaw = newValue.situations.map(\.rawValue).sorted()
            medicalClearance = newValue.medicalClearance
        }
    }

    var cycle: TrainingCycle? {
        get {
            guard let raw = cycleProgramRaw, let program = CycleProgram(rawValue: raw), let cycleStartDate else { return nil }
            return TrainingCycle(program: program, startDate: cycleStartDate)
        }
        set {
            cycleProgramRaw = newValue?.program.rawValue
            cycleStartDate = newValue?.startDate
        }
    }

    /// Séances prévues cette semaine du cycle : le nombre confirmé pour cette semaine, sinon
    /// une proposition (moyenne récente, puis dernier nombre choisi, puis 4) à confirmer.
    func cycleSessions(on date: Date, recentAverage: Int?, calendar: Calendar = .current) -> (sessions: Int, confirmed: Bool)? {
        guard let cycle, let weekStart = cycle.weekStart(on: date, calendar: calendar) else { return nil }
        if let cycleSessionsWeekStart, calendar.isDate(cycleSessionsWeekStart, inSameDayAs: weekStart), cycleSessionsPerWeek > 0 {
            return (cycleSessionsPerWeek, true)
        }
        let suggested = recentAverage ?? (cycleSessionsPerWeek > 0 ? cycleSessionsPerWeek : CycleSessionPlan.defaultSessions)
        return (CycleSessionPlan(sessions: suggested).sessions, false)
    }

    func confirmCycleSessions(_ sessions: Int, on date: Date, calendar: Calendar = .current) {
        cycleSessionsPerWeek = CycleSessionPlan(sessions: sessions).sessions
        cycleSessionsWeekStart = cycle?.weekStart(on: date, calendar: calendar)
    }

    /// Le bilan revient au plus une fois par semaine.
    func isCheckInDue(at date: Date) -> Bool {
        guard let lastCheckInAt else { return true }
        return date.timeIntervalSince(lastCheckInAt) >= 7 * 86_400
    }

    var profile: UserProfile {
        var profile = UserProfile(
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
            calorieAdjustmentKcal: calorieAdjustmentKcal,
            screening: screening
        )
        profile.maintenanceWeekUntil = maintenanceWeekUntil
        profile.floorWeekUntil = floorWeekUntil
        return profile
    }

    /// Une semaine à l'équilibre à proposer : 12 semaines de déficit depuis la création du
    /// profil ou la dernière semaine à l'équilibre.
    func isMaintenanceWeekDue(phase: BodyPhase, on date: Date, calendar: Calendar = .current) -> Bool {
        phase == .fatLoss && MaintenanceWeek.isDue(
            deficitSince: maintenanceWeekUntil ?? createdAt, dismissedAt: maintenanceOfferDismissedAt, on: date, calendar: calendar
        )
    }

    func startFloorWeek(on date: Date, calendar: Calendar = .current) {
        floorWeekUntil = FloorWeek.end(startingOn: date, calendar: calendar)
        floorProteinDays = []
    }

    /// Protéines du jour atteintes ou non pendant la semaine plancher.
    func recordFloorProtein(_ reached: Bool, on date: Date, calendar: Calendar = .current) {
        guard profile.isOnFloorWeek(on: date) else { return }
        let others = floorProteinDays.filter { !calendar.isDate($0, inSameDayAs: date) }
        let updated = reached ? others + [calendar.storedDay(for: date)] : others
        if updated != floorProteinDays { floorProteinDays = updated }
    }

    func startMaintenanceWeek(on date: Date, calendar: Calendar = .current) {
        maintenanceWeekUntil = calendar.date(byAdding: .day, value: MaintenanceWeek.days, to: calendar.startOfDay(for: date))
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
    /// Mesure estimée au LiDAR (expérimental) : affichée à côté du ruban, jamais dans la tendance.
    var isScan: Bool = false

    init(date: Date, cm: Double, isScan: Bool = false) {
        self.date = date
        self.cm = cm
        self.isScan = isScan
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
    /// Temps du WOD de référence du cycle fait ce jour-là (secondes).
    var benchmarkSeconds: Int?
    /// Séance retouchée pour la journée (séries, exercices retirés ou ajoutés), en JSON.
    var sessionEditsData: Data?
    /// Paliers décalés pour la journée, par exercice (kg, en JSON).
    var loadShiftsData: Data?
    /// Calories mangées, une fois les quatre repas notés (pris, sautés ou décrits) ; `nil` : journée
    /// incomplète. Sert à mesurer la dépense réelle (schéma V3).
    var eatenKcal: Double?

    var sessionEdits: SessionEdits {
        get { sessionEditsData.flatMap { try? JSONDecoder().decode(SessionEdits.self, from: $0) } ?? SessionEdits() }
        set { sessionEditsData = newValue.isEmpty ? nil : try? JSONEncoder().encode(newValue) }
    }

    var loadShifts: [String: Double] {
        get { loadShiftsData.flatMap { try? JSONDecoder().decode([String: Double].self, from: $0) } ?? [:] }
        set {
            let kept = newValue.filter { $0.value != 0 }
            loadShiftsData = kept.isEmpty ? nil : try? JSONEncoder().encode(kept)
        }
    }

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
    /// Effort ressenti (`SetEffort`) ; `nil` : non noté.
    var effortRaw: String?

    init(_ entry: LiftEntry) {
        day = entry.date
        exercise = entry.exercise
        kg = entry.kg
        reps = entry.reps
        isTest = entry.isTest
        effortRaw = entry.effort?.rawValue
    }

    var entry: LiftEntry { LiftEntry(exercise: exercise, date: day, kg: kg, reps: reps, isTest: isTest, effort: effortRaw.flatMap(SetEffort.init(rawValue:))) }
}

/// Ressenti d'une semaine du calendrier : humeur et ce qui a coincé, base des 3 priorités.
@Model
final class WeekFeelingRecord {
    /// Un jour de la semaine (à midi, voir `Calendar.storedDay`) : comparer avec `.weekOfYear`.
    var weekStart: Date = Date.now
    var moodRaw: String = WeekMood.good.rawValue
    var obstaclesRaw: [String] = []
    var answeredAt: Date = Date.now

    init(weekStart: Date, feeling: WeekFeeling) {
        self.weekStart = weekStart
        self.feeling = feeling
    }

    var feeling: WeekFeeling {
        get {
            WeekFeeling(
                mood: WeekMood(rawValue: moodRaw) ?? .good,
                obstacles: Set(obstaclesRaw.compactMap(WeekObstacle.init(rawValue:)))
            )
        }
        set {
            moodRaw = newValue.mood.rawValue
            obstaclesRaw = WeekObstacle.allCases.filter(newValue.obstacles.contains).map(\.rawValue)
            answeredAt = .now
        }
    }
}

/// Test de marche de 1,6 km : temps, pouls à l'arrivée et forme cardio qui en découle.
@Model
final class CardioTestRecord {
    var day: Date = Date.now
    var minutes: Double = 0
    var heartRate: Int = 0
    var vo2max: Double = 0

    init(day: Date, minutes: Double, heartRate: Int, vo2max: Double) {
        self.day = day
        self.minutes = minutes
        self.heartRate = heartRate
        self.vo2max = vo2max
    }

    var measure: CardioMeasure { CardioMeasure(vo2max: vo2max, date: day, source: .walkTest) }
}
