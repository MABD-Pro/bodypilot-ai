import BodyPilotCore
import Coach
import Foundation
import SwiftData

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
    /// `-demoScrollTo progress` : fait défiler l'écran Aujourd'hui jusqu'à une carte.
    static var demoScrollTarget: String? { defaults.string(forKey: "demoScrollTo") }
}

enum AppContainer {
    static let schema = Schema([ProfileRecord.self, WeightRecord.self, DayLogRecord.self])

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
            goal: .loseFat,
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
        if !adjustments.isEmpty || !swaps.isEmpty {
            let log = DayLogRecord(day: calendar.startOfDay(for: now))
            log.adjustments = adjustments
            log.availableMinutes = minutes
            log.eatingOutSlot = eatingOutSlot
            log.exerciseSwapsRaw = swaps
            context.insert(log)
        }
    }
}
