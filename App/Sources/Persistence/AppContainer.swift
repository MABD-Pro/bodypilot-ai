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
    /// `-demoScrollTo progress` : fait défiler l'écran Aujourd'hui jusqu'à une carte.
    static var demoScrollTarget: String? { defaults.string(forKey: "demoScrollTo") }
}

enum AppContainer {
    static let schema = Schema([ProfileRecord.self, WeightRecord.self, DayLogRecord.self])

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
            trainingDaysPerWeek: 3,
            sessionMinutes: 45,
            equipment: .bodyweight
        )
        context.insert(ProfileRecord(profile))

        let noise = [0.4, -0.3, 0.1, -0.5, 0.3, 0.0, -0.2]
        for offset in 0..<24 {
            let index = 23 - offset
            guard index % 5 != 3, let date = calendar.date(byAdding: .day, value: -offset, to: now) else { continue }
            let kg = 88.0 - 0.09 * Double(index) + noise[index % noise.count]
            context.insert(WeightRecord(date: date, kg: (kg * 10).rounded() / 10))
        }

        let adjustments = LaunchOptions.demoAdjustments
        if !adjustments.isEmpty {
            let log = DayLogRecord(day: calendar.startOfDay(for: now))
            log.adjustments = adjustments
            context.insert(log)
        }
    }
}
