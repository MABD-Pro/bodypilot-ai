import BodyPilotCore
import Coach
import Foundation
import Nutrition
import SwiftData
import Training

/// Options de lancement pour les aperçus et les captures d'écran de la CI.
enum LaunchOptions {
    private static var defaults: UserDefaults { .standard }

    /// `-demoData YES` : profil et trois semaines de pesées, en mémoire.
    static var demoData: Bool { defaults.bool(forKey: "demoData") }
    /// `-demoOnboarding YES` : base vide en mémoire, pour afficher l'accueil.
    static var demoOnboarding: Bool { defaults.bool(forKey: "demoOnboarding") }
    /// `-demoAdjustments tired,shortOnTime` : ajustements du jour pré-sélectionnés.
    static var demoAdjustments: Set<QuickAdjustment> {
        let raw = defaults.string(forKey: "demoAdjustments") ?? ""
        return Set(raw.split(separator: ",").compactMap { QuickAdjustment(rawValue: String($0)) })
    }
    /// `-demoHoldSplash YES` : garde l'écran de chargement affiché.
    static var demoHoldSplash: Bool { defaults.bool(forKey: "demoHoldSplash") }
    /// `-demoCommand "…"` : phrase libre appliquée au lancement.
    static var demoCommand: String? { defaults.string(forKey: "demoCommand") }
    /// `-demoHealth YES` : affiche le suivi Santé comme connecté, sans interroger HealthKit.
    static var demoHealth: Bool { defaults.bool(forKey: "demoHealth") }
    /// `-demoCheckIn YES` : pesées en perte rapide, pour afficher le bilan de la semaine.
    static var demoCheckIn: Bool { defaults.bool(forKey: "demoCheckIn") }
    /// `-demoSwap YES` : remplace le premier exercice de la séance du jour par sa variante.
    static var demoSwap: Bool { defaults.bool(forKey: "demoSwap") }
    /// `-demoMeals breakfast=asPlanned,lunch=hearty` : repas déjà pris.
    static var demoMeals: [String] {
        (defaults.string(forKey: "demoMeals") ?? "").split(separator: ",").map(String.init)
    }
    /// `-demoDescribed "lunch=une grande assiette de pâtes carbo et un coca"` : repas décrit en texte.
    static var demoDescribed: (slot: MealSlot, text: String)? {
        let parts = (defaults.string(forKey: "demoDescribed") ?? "").split(separator: "=", maxSplits: 1).map(String.init)
        guard parts.count == 2, let slot = MealSlot(rawValue: parts[0]) else { return nil }
        return (slot, parts[1])
    }
    /// `-demoActivities YES` : quelques activités Santé dans la semaine (course, vélo, marche).
    static var demoActivities: Bool { defaults.bool(forKey: "demoActivities") }
    /// `-demoScrollTo progress` : fait défiler l'écran Aujourd'hui jusqu'à une carte.
    static var demoScrollTarget: String? { defaults.string(forKey: "demoScrollTo") }
}

enum AppContainer {
    static let schema = Schema([ProfileRecord.self, WeightRecord.self, DayLogRecord.self, WeekPlanRecord.self, WaistRecord.self])

    /// Conteneur unique de l'app, partagé avec Siri et Raccourcis pour qu'ils voient les mêmes données.
    @MainActor
    static let shared = make()

    @MainActor
    static func make() -> ModelContainer {
        if LaunchOptions.demoData || LaunchOptions.demoOnboarding {
            let container = inMemory()
            if LaunchOptions.demoData { DemoData.seed(container.mainContext) }
            return container
        }
        do {
            return try ModelContainer(for: schema)
        } catch {
            fatalError("Impossible d'ouvrir la base locale : \(error)")
        }
    }

    @MainActor
    static func inMemory() -> ModelContainer {
        do {
            return try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        } catch {
            fatalError("Impossible de créer la base en mémoire : \(error)")
        }
    }

    @MainActor
    static var preview: ModelContainer {
        let container = inMemory()
        DemoData.seed(container.mainContext)
        return container
    }
}

enum DemoData {
    /// Activités de la Watch, sur les jours précédents de la semaine.
    static func activities(now: Date = .now, calendar: Calendar = .current) -> [ActivitySample] {
        let items: [(days: Int, hour: Int, kind: ActivityKind, minutes: Double, kcal: Double)] = [
            (0, 7, .walking, 32, 140), (1, 18, .cycling, 75, 610), (2, 7, .running, 40, 420),
        ]
        return items.compactMap { item in
            guard let day = calendar.date(byAdding: .day, value: -item.days, to: now),
                  let start = calendar.date(bySettingHour: item.hour, minute: 0, second: 0, of: day),
                  start <= now
            else { return nil }
            return ActivitySample(id: "demo-\(item.days)", kind: item.kind, start: start, minutes: item.minutes, kcal: item.kcal)
        }
    }

    @MainActor
    static func seed(_ context: ModelContext, now: Date = .now, calendar: Calendar = .current) {
        let birthDate = calendar.date(byAdding: .year, value: -34, to: now) ?? now
        let profile = UserProfile(
            sex: .male,
            birthDate: birthDate,
            heightCm: 178,
            startWeightKg: 88,
            targetWeightKg: 80,
            activity: .moderate,
            goal: .recomposition,
            // Six séances : les captures montrent une séance quel que soit le jour (sauf le dimanche).
            trainingDaysPerWeek: 6,
            sessionMinutes: 45,
            equipment: .bodyweight
        )
        context.insert(ProfileRecord(profile))

        let noise = [0.4, -0.3, 0.1, -0.5, 0.3, 0.0, -0.2]
        for offset in 0..<24 {
            let index = 23 - offset
            guard index % 5 != 3, let date = calendar.date(byAdding: .day, value: -offset, to: now) else { continue }
            let perDay = LaunchOptions.demoCheckIn ? 0.17 : 0.09
            let kg = 88.0 - perDay * Double(index) + noise[index % noise.count]
            context.insert(WeightRecord(date: date, kg: (kg * 10).rounded() / 10))
        }

        // Tour de taille en baisse, une mesure par semaine.
        for week in 0..<4 {
            guard let date = calendar.date(byAdding: .day, value: -7 * week, to: now) else { continue }
            context.insert(WaistRecord(date: date, cm: 95.0 - 0.6 * Double(3 - week)))
        }

        // Trois semaines de séances cochées, pour afficher la régularité.
        let trainingWeekdays = profile.trainingWeekdays
        for offset in 1...21 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: now),
                  trainingWeekdays.contains(calendar.component(.weekday, from: date))
            else { continue }
            let log = DayLogRecord(day: calendar.startOfDay(for: date))
            log.workoutDone = true
            context.insert(log)
        }

        var adjustments = LaunchOptions.demoAdjustments
        var minutes: Int?
        var eatingOutSlot: MealSlot?
        if let command = LaunchOptions.demoCommand, let interpreted = CommandInterpreter().interpret(command) {
            adjustments.formUnion(interpreted.adjustments)
            minutes = interpreted.availableMinutes
            eatingOutSlot = interpreted.eatingOutSlot
        }
        var swaps: [String] = []
        if LaunchOptions.demoSwap,
           case .workout(let workout) = CoachFactory.coach.plan(for: profile, weights: [], adjustments: adjustments, on: now).training.kind,
           let first = workout.exercises.first {
            swaps = [first.key]
        }
        if !adjustments.isEmpty || !swaps.isEmpty || !LaunchOptions.demoMeals.isEmpty || LaunchOptions.demoDescribed != nil {
            let log = DayLogRecord(day: calendar.startOfDay(for: now))
            log.adjustments = adjustments
            log.availableMinutes = minutes
            log.eatingOutSlot = eatingOutSlot
            log.exerciseSwapsRaw = swaps
            log.mealIntakesRaw = LaunchOptions.demoMeals
            if let described = LaunchOptions.demoDescribed, case let meal = MealTextParser.parse(described.text).meal, !meal.foods.isEmpty {
                log.describedMeals = [described.slot: meal]
            }
            context.insert(log)
        }
    }
}
