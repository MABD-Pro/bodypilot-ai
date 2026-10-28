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
    /// `-demoHistory Force` : ouvre l'historique sur cette partie (Mesures, Force, Séances, Repas).
    static var demoHistory: String? { defaults.string(forKey: "demoHistory") }
    /// `-demoComposition YES` : 4 semaines de taux de gras et de masse maigre lus dans Santé.
    static var demoComposition: Bool { defaults.bool(forKey: "demoComposition") }
    /// `-demoActivities YES` : quelques activités Santé dans la semaine (course, vélo, marche).
    static var demoActivities: Bool { defaults.bool(forKey: "demoActivities") }
    /// `-demoSleep 5.5` : nuit passée lue dans Santé, en heures.
    /// `-demoMaintenanceOffer YES` : la semaine à l'équilibre est proposée dans Progresser.
    static var demoMaintenanceOffer: Bool { defaults.bool(forKey: "demoMaintenanceOffer") }
    /// `-demoAge 68` : âge du profil de démo (séries de 10, équilibre à partir de 65 ans).
    static var demoAge: Int? { defaults.object(forKey: "demoAge") == nil ? nil : defaults.integer(forKey: "demoAge") }
    /// `-demoSleepAverage 6.25` : sommeil moyen des 7 dernières nuits.
    static var demoSleepAverage: Double? { defaults.object(forKey: "demoSleepAverage") == nil ? nil : defaults.double(forKey: "demoSleepAverage") }
    static var demoSleepHours: Double? { defaults.object(forKey: "demoSleep") == nil ? nil : defaults.double(forKey: "demoSleep") }
    /// `-demoCycle 4` : cycle CrossFit en cours, aujourd'hui dans cette semaine (1 à 12).
    static var demoCycleWeek: Int? { defaults.object(forKey: "demoCycle") == nil ? nil : defaults.integer(forKey: "demoCycle") }
    /// `-demoHyrox` : le cycle de démonstration (et le choix proposé) est l'Hyrox.
    static var demoHyrox: Bool { defaults.bool(forKey: "demoHyrox") }
    /// `-demoLifts YES` : profil en salle et séries notées les semaines passées, record du jour sur le premier exercice.
    static var demoLifts: Bool { defaults.bool(forKey: "demoLifts") }
    /// `-demoCalibration YES` : profil en salle sans charge notée, la séance du jour est le premier test de force.
    static var demoCalibration: Bool { defaults.bool(forKey: "demoCalibration") }
    /// `-demoCardioTest YES` : aucune forme cardio connue, le jour de cardio devient le test de marche.
    static var demoCardioTest: Bool { defaults.bool(forKey: "demoCardioTest") }
    /// `-demoVideo YES` : la fiche d'exercice s'ouvre avec la démonstration affichée.
    static var demoVideo: Bool { defaults.bool(forKey: "demoVideo") }
    /// `-demoRecovery YES` : force faite hier, la séance du jour est cardio et marche.
    static var demoRecovery: Bool { defaults.bool(forKey: "demoRecovery") }
    /// `-demoScreening pending` : profil sans questionnaire de santé (bandeau visible) ;
    /// `caution` : un oui sans accord médical, séances à effort modéré.
    static var demoScreening: String? { defaults.string(forKey: "demoScreening") }
    /// `-demoOnboardingStep 1` : l'accueil s'ouvre sur cette étape (0 à 3).
    static var demoOnboardingStep: Int? { defaults.object(forKey: "demoOnboardingStep") == nil ? nil : defaults.integer(forKey: "demoOnboardingStep") }
    /// `-demoIntake YES` : les 3 dernières semaines ont leurs quatre repas notés (dépense mesurée).
    static var demoIntake: Bool { defaults.bool(forKey: "demoIntake") }
    /// `-demoSteps YES` : deux semaines de pas lus dans Santé (environ 6 500 par jour).
    static var demoSteps: Bool { defaults.bool(forKey: "demoSteps") }
    /// `-demoTarget 92` : poids visé de la démo (au-dessus du poids actuel : phase de légère prise).
    static var demoTargetKg: Double? { defaults.object(forKey: "demoTarget") == nil ? nil : defaults.double(forKey: "demoTarget") }
    /// `-demoScrollTo progress` : fait défiler l'écran Aujourd'hui jusqu'à une carte.
    static var demoScrollTarget: String? { defaults.string(forKey: "demoScrollTo") }
}

enum AppContainer {
    static let schema = Schema(versionedSchema: SchemaV4.self)

    /// Raison pour laquelle la base locale n'a pas pu s'ouvrir : l'app l'affiche au lieu de
    /// planter à chaque lancement (Siri compris), sans jamais effacer les données.
    @MainActor
    static var openFailure: String?

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
            let container = try ModelContainer(for: schema, migrationPlan: BodyPilotMigrationPlan.self)
            StoredDayMigration.run(in: container.mainContext)
            return container
        } catch {
            openFailure = String(describing: error)
            return inMemory()
        }
    }

    @MainActor
    static func inMemory() -> ModelContainer {
        do {
            return try ModelContainer(for: schema, migrationPlan: BodyPilotMigrationPlan.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
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
    /// Pas des 14 derniers jours et d'aujourd'hui (matinée) : environ 6 500 par jour.
    static func steps(now: Date = .now, calendar: Calendar = .current) -> [DailySteps] {
        let today = calendar.startOfDay(for: now)
        let counts = [5_800, 7_200, 6_100, 8_400, 5_200, 6_900, 7_600, 4_800, 6_300, 7_100, 5_900, 6_700, 8_000, 5_400, 3_200]
        return counts.enumerated().compactMap { index, steps in
            calendar.date(byAdding: .day, value: index - (counts.count - 1), to: today).map { DailySteps(day: $0, steps: steps) }
        }
    }

    /// Balance à impédance sur 4 semaines : le gras baisse d'environ un point, la masse maigre monte un peu.
    static func compositions(now: Date = .now, calendar: Calendar = .current) -> [BodyCompositionEntry] {
        stride(from: 27, through: 0, by: -1).compactMap { daysAgo in
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: now) else { return nil }
            let progress = Double(27 - daysAgo) / 27
            let noise = Double((daysAgo * 7) % 5 - 2) * 0.15
            return BodyCompositionEntry(date: date, fatPercent: 31.8 - 1.1 * progress + noise, leanKg: 59.3 + 0.4 * progress + noise / 2)
        }
    }

    /// Forme cardio de la Watch il y a 3 jours : pas de test de cardio à faire.
    static func watchCardio(now: Date = .now) -> CardioMeasure {
        CardioMeasure(vo2max: 41.5, date: now.addingTimeInterval(-3 * 86_400), source: .watch)
    }

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

    /// Deux séances passées par exercice ; la dernière dépasse les répétitions prévues, d'où une charge en hausse.
    @MainActor
    private static func seedLifts(for profile: UserProfile, context: ModelContext, now: Date, calendar: Calendar) {
        // Calibrage fait il y a deux semaines : une série de 5 sur chaque mouvement de référence.
        let tests: [Double] = [70, 52.5, 50, 100, 40, 45]
        for (exercise, kg) in zip(StrengthCalibration.referenceLifts, tests) {
            guard let date = calendar.date(byAdding: .day, value: -14, to: now) else { continue }
            context.insert(LiftRecord(LiftEntry(exercise: exercise, date: calendar.storedDay(for: date), kg: kg, reps: StrengthCalibration.testReps, isTest: true)))
        }
        guard case .workout(let workout) = CoachFactory.coach.plan(for: profile, weights: [], on: now).training.kind else { return }
        let loads: [Double] = [80, 60, 50, 70]
        let strength = workout.exercises.filter { $0.priority < 4 }
        for (index, exercise) in strength.enumerated() {
            guard case .reps(let planned) = exercise.volume else { continue }
            let kg = loads[index % loads.count]
            for (daysAgo, reps) in [(9, planned), (4, planned + 1)] {
                guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: now) else { continue }
                context.insert(LiftRecord(LiftEntry(exercise: exercise.name, date: calendar.storedDay(for: date), kg: kg, reps: reps)))
            }
            if index == 0 {
                let today = LiftEntry(exercise: exercise.name, date: calendar.storedDay(for: now), kg: kg + StrengthProgress.increment(from: kg), reps: planned)
                context.insert(LiftRecord(today))
            }
        }
    }

    /// Repas décrits en démo, par jour passé (1 = hier).
    static let demoRecentMeals: [Int: [MealSlot: String]] = [
        1: [.breakfast: "flocons d'avoine et un skyr", .lunch: "un burger, des frites et un coca"],
        2: [.lunch: "150 g de poulet, du riz et des haricots verts"],
        3: [.dinner: "une pizza et une bière"],
    ]

    @MainActor
    static func seed(_ context: ModelContext, now: Date = .now, calendar: Calendar = .current) {
        let birthDate = calendar.date(byAdding: .year, value: -(LaunchOptions.demoAge ?? 34), to: now) ?? now
        let profile = UserProfile(
            sex: .male,
            birthDate: birthDate,
            heightCm: 178,
            startWeightKg: 88,
            targetWeightKg: LaunchOptions.demoTargetKg ?? 80,
            activity: .moderate,
            goal: .recomposition,
            trainingDaysPerWeek: 3,
            sessionMinutes: 45,
            equipment: LaunchOptions.demoLifts || LaunchOptions.demoCalibration ? .gym : .bodyweight,
            screening: LaunchOptions.demoScreening == "pending"
                ? HealthScreening()
                : HealthScreening(answeredAt: now, yes: LaunchOptions.demoScreening == "caution" ? [.boneOrJoint] : [])
        )
        let profileRecord = ProfileRecord(profile)
        if let week = LaunchOptions.demoCycleWeek, let start = calendar.date(byAdding: .day, value: -7 * (week - 1), to: now) {
            profileRecord.cycle = TrainingCycle(program: LaunchOptions.demoHyrox ? .hyrox : .crossfit, startDate: start)
        }
        context.insert(profileRecord)

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
        // Un scan LiDAR le jour de la dernière mesure au ruban, pour l'historique.
        context.insert(WaistRecord(date: now, cm: 94.0, isScan: true))

        // Trois semaines de séances cochées : force un jour sur deux (B la plus récente, donc A
        // aujourd'hui), cardio et marche entre deux, un jour de repos. Avec -demoRecovery, la force date d'hier.
        let recovery = LaunchOptions.demoRecovery
        let conditioningTitle = profile.equipment == .gym ? "Cardio et marche inclinée" : "Cardio et marche en côte"
        var strengthCount = 0
        // Un jour de repos il y a quatre jours : pas six jours d'activité d'affilée.
        for offset in 1...21 where offset != 4 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: now) else { continue }
            let log = DayLogRecord(day: calendar.storedDay(for: date))
            log.workoutDone = true
            if LaunchOptions.demoIntake { log.eatenKcal = 2_050 + Double((offset * 37) % 7 - 3) * 40 }
            if offset % 2 == (recovery ? 1 : 0) {
                log.doneWorkoutTitle = strengthCount % 2 == 0 ? "Full body B" : "Full body A"
                strengthCount += 1
            } else {
                log.doneWorkoutTitle = conditioningTitle
            }
            // Quelques repas décrits ces derniers jours, à reprendre d'une touche.
            let described = Self.demoRecentMeals[offset] ?? [:]
            if !described.isEmpty {
                log.describedMeals = described.mapValues { MealTextParser.parse($0).meal }
            }
            context.insert(log)
        }

        if LaunchOptions.demoLifts { seedLifts(for: profile, context: context, now: now, calendar: calendar) }

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
            let log = DayLogRecord(day: calendar.storedDay(for: now))
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
