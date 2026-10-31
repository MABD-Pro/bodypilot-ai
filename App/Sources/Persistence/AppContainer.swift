import BodyPilotCore
import Coach
import Foundation
import Nutrition
import ProgressInsights
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
    /// `-demoLowRecovery YES` : VFC basse et pouls au repos haut sur la dernière semaine.
    static var demoLowRecovery: Bool { defaults.bool(forKey: "demoLowRecovery") }
    /// `-demoHabits YES` : le même petit-déjeuner décrit 4 jours sur les 5 derniers, proposé comme habitude.
    static var demoHabits: Bool { defaults.bool(forKey: "demoHabits") }
    /// `-demoAvoid fish,dairy` : aliments écartés des repas proposés (valeurs de `FoodAversion`).
    static var demoAvoid: Set<FoodAversion> {
        Set((defaults.string(forKey: "demoAvoid") ?? "").split(separator: ",").compactMap { FoodAversion(rawValue: String($0)) })
    }
    /// `-demoHistory Force` : ouvre l'historique sur cette partie (Mesures, Force, Séances, Repas, Pas).
    static var demoHistory: String? { defaults.string(forKey: "demoHistory") }
    /// `-demoSessionDetail YES` : avec `-demoHistory Séances -demoActivities YES`, ouvre le détail
    /// de la course (parcours, pouls, kilomètres).
    static var demoSessionDetail: Bool { defaults.bool(forKey: "demoSessionDetail") }
    /// `-demoReview YES` : ouvre « Mes 7 derniers jours », avec une semaine de repas notés ;
    /// `-demoReview jour` : ouvre en plus le détail de la veille.
    static var demoReview: String? { defaults.string(forKey: "demoReview") }
    /// `-demoFeeling hard:hunger,time` : ressenti de la semaine affiché (non enregistré).
    static var demoFeeling: WeekFeeling? {
        guard let value = defaults.string(forKey: "demoFeeling") else { return nil }
        let parts = value.split(separator: ":", maxSplits: 1)
        guard let mood = parts.first.flatMap({ WeekMood(rawValue: String($0)) }) else { return nil }
        let obstacles = parts.count > 1 ? parts[1].split(separator: ",").compactMap { WeekObstacle(rawValue: String($0)) } : []
        return WeekFeeling(mood: mood, obstacles: Set(obstacles))
    }
    /// `-demoPastMeals YES` (avec `-demoHistory Repas`) : ouvre les repas de la veille pour les corriger.
    static var demoPastMeals: Bool { defaults.bool(forKey: "demoPastMeals") }
    /// `-demoGroceries YES` : ouvre la liste de courses des 7 prochains jours.
    static var demoGroceries: Bool { defaults.bool(forKey: "demoGroceries") }
    /// `-demoBrands "Skyr nature"` : avec la liste de courses, ouvre les marques conseillées de cet article.
    static var demoBrands: String? { defaults.string(forKey: "demoBrands") }
    /// `-demoComposition YES` : 4 semaines de taux de gras et de masse maigre lus dans Santé.
    static var demoComposition: Bool { defaults.bool(forKey: "demoComposition") }
    /// `-demoActivities YES` : quelques activités Santé dans la semaine (course, vélo, marche).
    static var demoActivities: Bool { defaults.bool(forKey: "demoActivities") }
    /// `-demoSleep 5.5` : nuit passée lue dans Santé, en heures.
    /// `-demoGuides YES` : « Conseils et sources » s'ouvre au lancement.
    static var demoGuides: Bool { defaults.bool(forKey: "demoGuides") }
    /// `-demoMaintenanceOffer YES` : la semaine à l'équilibre est proposée dans Progresser.
    static var demoMaintenanceOffer: Bool { defaults.bool(forKey: "demoMaintenanceOffer") }
    /// `-demoComeback YES` : 5 jours sans rien noter, le coach propose une semaine plancher.
    static var demoComeback: Bool { defaults.bool(forKey: "demoComeback") }
    /// `-demoEatingCare YES` : carte du garde-fou alimentaire ; `-demoEatingCare purging` : version immédiate.
    static var demoEatingCare: String? { defaults.string(forKey: "demoEatingCare") }
    /// `-demoDebrief YES` : débrief du soir affiché quelle que soit l'heure ; avec une phrase,
    /// elle est déjà comprise (`-demoDebrief "Séance faite, pizza ce soir, crevé"`).
    static var demoDebrief: String? { defaults.string(forKey: "demoDebrief") }
    /// `-demoWhatIf 200:2000` : ouvre « Et si ? » avec 200 kcal de moins et 2 000 pas de plus par jour
    /// (sans signe moins : une valeur qui commence par « - » serait lue comme une option).
    static var demoWhatIf: ProjectionScenario? {
        guard let value = defaults.string(forKey: "demoWhatIf") else { return nil }
        let parts = value.split(separator: ":").compactMap { Int($0) }
        return ProjectionScenario(kcalPerDay: -(parts.first ?? 0), extraSteps: parts.count > 1 ? parts[1] : 0)
    }
    /// `-demoFloorWeek YES` : semaine plancher commencée il y a 3 jours.
    static var demoFloorWeek: Bool { defaults.bool(forKey: "demoFloorWeek") }
    /// `-demoAge 68` : âge du profil de démo (séries de 10, équilibre à partir de 65 ans).
    static var demoAge: Int? { defaults.object(forKey: "demoAge") == nil ? nil : defaults.integer(forKey: "demoAge") }
    /// `-demoSleepAverage 6.25` : sommeil moyen des 7 dernières nuits.
    static var demoSleepAverage: Double? { defaults.object(forKey: "demoSleepAverage") == nil ? nil : defaults.double(forKey: "demoSleepAverage") }
    static var demoSleepHours: Double? { defaults.object(forKey: "demoSleep") == nil ? nil : defaults.double(forKey: "demoSleep") }
    /// `-demoCycle 4` : cycle CrossFit en cours, aujourd'hui dans cette semaine (1 à 12).
    static var demoCycleWeek: Int? { defaults.object(forKey: "demoCycle") == nil ? nil : defaults.integer(forKey: "demoCycle") }
    /// `-demoHyrox` : le cycle de démonstration (et le choix proposé) est l'Hyrox.
    static var demoHyrox: Bool { defaults.bool(forKey: "demoHyrox") }
    /// `-demoMuscles YES` : séance lourde notée hier (jambes et dos durs), carte de fatigue par muscle.
    static var demoMuscles: Bool { defaults.bool(forKey: "demoMuscles") }
    /// `-demoHunger YES` : faim notée l'après-midi quatre jours sur quatorze, et une petite faim il y a vingt minutes.
    static var demoHunger: Bool { defaults.bool(forKey: "demoHunger") }
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
    /// `-demoSteps YES` : deux mois de pas lus dans Santé (environ 6 500 par jour ces deux semaines).
    static var demoSteps: Bool { defaults.bool(forKey: "demoSteps") }
    /// `-demoAgenda YES` : journée chargée avec un dîner au restaurant ; `-demoAgenda travel` :
    /// un train le matin ; `-demoAgenda full` : aucune pause assez longue pour la séance.
    static var demoAgenda: String? { defaults.string(forKey: "demoAgenda") }
    /// `-demoAgendaInvite YES` : montre l'invitation à lire l'agenda.
    static var demoAgendaInvite: Bool { defaults.bool(forKey: "demoAgendaInvite") }
    /// `-demoTarget 92` : poids visé de la démo (au-dessus du poids actuel : phase de légère prise).
    static var demoTargetKg: Double? { defaults.object(forKey: "demoTarget") == nil ? nil : defaults.double(forKey: "demoTarget") }
    /// `-demoScrollTo progress` : fait défiler l'écran Aujourd'hui jusqu'à une carte.
    static var demoScrollTarget: String? { defaults.string(forKey: "demoScrollTo") }
    /// `-demoConsent YES` : affiche la question sur les rapports de plantage et statistiques.
    static var demoConsent: Bool { defaults.bool(forKey: "demoConsent") }
    /// Lancé avec une option `-demo…` : rien n'est envoyé à Firebase.
    static var isDemo: Bool { ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("-demo") } }
}

enum AppContainer {
    static let schema = Schema(versionedSchema: SchemaV8.self)

    /// Raison pour laquelle la base locale n'a pas pu s'ouvrir : l'app l'affiche au lieu de
    /// planter à chaque lancement (Siri compris), sans jamais effacer les données.
    @MainActor
    static var openFailure: String?

    /// Conteneur unique de l'app, partagé avec Siri et Raccourcis pour qu'ils voient les mêmes données.
    @MainActor
    static let shared = make()

    /// Base dans le bac à sable de l'app, jamais dans l'App Group : avec l'App Group des widgets,
    /// la configuration par défaut (`groupContainer: .automatic`) ouvrait une base vide dans le
    /// conteneur partagé et laissait les données existantes de côté. Les widgets lisent
    /// `TodaySnapshot`, jamais la base.
    static let storeConfiguration = ModelConfiguration(schema: schema, groupContainer: .none)

    @MainActor
    static func make() -> ModelContainer {
        if LaunchOptions.demoData || LaunchOptions.demoOnboarding {
            let container = inMemory()
            if LaunchOptions.demoData { DemoData.seed(container.mainContext) }
            return container
        }
        do {
            let container = try ModelContainer(for: schema, migrationPlan: BodyPilotMigrationPlan.self, configurations: storeConfiguration)
            StoredDayMigration.run(in: container.mainContext)
            return container
        } catch {
            AppLog.persistence.fault("Base locale illisible : \(String(describing: error), privacy: .public)")
            Telemetry.recordNonFatal(error)
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
    /// Quatre semaines de VFC et de pouls au repos : la dernière semaine, VFC en baisse et pouls en hausse.
    static func lowRecovery(now: Date = .now, calendar: Calendar = .current) -> (hrv: [DatedValue], resting: [DatedValue]) {
        let noise = [3.0, -2.0, 1.0, -4.0, 2.0, 0.0, -1.0]
        var hrv: [DatedValue] = []
        var resting: [DatedValue] = []
        for daysAgo in 0..<28 {
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: now) else { continue }
            let tired = daysAgo < 7
            hrv.append(DatedValue(date: date, value: (tired ? 38 : 52) + noise[daysAgo % noise.count]))
            resting.append(DatedValue(date: date, value: (tired ? 62 : 56) + noise[daysAgo % noise.count] / 2))
        }
        return (hrv, resting)
    }

    /// Faims de `-demoHunger` : l'après-midi plusieurs jours, une fois le soir.
    static func hunger(now: Date = .now, calendar: Calendar = .current) -> [HungerNote] {
        let notes: [(daysAgo: Int, hour: Int, minute: Int, level: HungerLevel)] = [
            (1, 16, 30, .hungry), (3, 17, 0, .starving), (6, 15, 45, .hungry), (9, 16, 15, .hungry), (5, 21, 30, .peckish),
        ]
        return notes.compactMap { note in
            guard let day = calendar.date(byAdding: .day, value: -note.daysAgo, to: now),
                  let date = calendar.date(bySettingHour: note.hour, minute: note.minute, second: 0, of: day) else { return nil }
            return HungerNote(date: date, level: note.level)
        }
    }

    /// Événements du jour pour `-demoAgenda`.
    static func agenda(_ kind: String, now: Date = .now, calendar: Calendar = .current) -> [AgendaEvent] {
        func at(_ hour: Int, _ minute: Int = 0) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
        }
        switch kind {
        case "travel":
            return [
                AgendaEvent(title: "Train Paris → Lyon", start: at(7, 30), end: at(9, 30)),
                AgendaEvent(title: "Atelier client", start: at(10), end: at(17)),
            ]
        case "full":
            return [
                AgendaEvent(title: "Formation", start: at(6), end: at(12, 30)),
                AgendaEvent(title: "Formation", start: at(13, 5), end: at(18)),
                AgendaEvent(title: "Réunion parents", start: at(18, 20), end: at(22)),
            ]
        default:
            return [
                AgendaEvent(title: "Comité de direction", start: at(7), end: at(12, 15)),
                AgendaEvent(title: "Point projet", start: at(13), end: at(19)),
                AgendaEvent(title: "Dîner au restaurant avec Léa", start: at(20), end: at(22, 30)),
            ]
        }
    }

    /// 60 jours de pas : environ 5 500 par jour il y a deux mois, 6 500 ces deux dernières
    /// semaines, quelques jours sans téléphone, aujourd'hui en cours.
    static func steps(now: Date = .now, calendar: Calendar = .current) -> [DailySteps] {
        let today = calendar.startOfDay(for: now)
        let recent = [5_800, 7_200, 6_100, 8_400, 5_200, 6_900, 7_600, 4_800, 6_300, 7_100, 5_900, 6_700, 8_000, 5_400, 3_200]
        let noise = [600, -900, 300, 1_400, -400, -1_200, 800, 0, -700, 1_100, 200, -300, 2_600, -1_500]
        var days: [DailySteps] = []
        for daysAgo in stride(from: 59, through: recent.count, by: -1) {
            // Un jour sur onze sans téléphone : pas de pas lus.
            guard daysAgo % 11 != 0, let day = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }
            let base = 5_500 + (59 - daysAgo) * 15
            days.append(DailySteps(day: day, steps: base + noise[daysAgo % noise.count]))
        }
        for (index, steps) in recent.enumerated() {
            if let day = calendar.date(byAdding: .day, value: index - (recent.count - 1), to: today) {
                days.append(DailySteps(day: day, steps: steps))
            }
        }
        return days
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

    /// Détail d'une activité de démo : boucle de ~7 km autour du parc Monceau, pouls qui monte
    /// puis se stabilise, petite accélération à la fin.
    static func workoutDetail(for item: SessionDetailSheet.Item) -> WorkoutDetail {
        let start = item.entry.start ?? item.day
        let minutes = item.entry.minutes ?? 40
        let end = start.addingTimeInterval(minutes * 60)
        let count = 240
        let route = (0...count).map { index -> RoutePoint in
            let progress = Double(index) / Double(count)
            let angle = progress * 2 * .pi
            // Ellipse d'environ 1,1 km × 0,9 km, parcourue une fois : ~6,3 km avec les détours.
            let wobble = 0.0006 * sin(angle * 9)
            return RoutePoint(
                latitude: 48.8795 + 0.0085 * sin(angle) + wobble,
                longitude: 2.3090 + 0.0145 * cos(angle) - 0.0145,
                altitude: 45 + 12 * sin(angle * 2),
                time: start.addingTimeInterval(minutes * 60 * pow(progress, 0.97))
            )
        }
        let heartRates = stride(from: 0.0, through: minutes * 60, by: 5).map { seconds -> HeartRatePoint in
            let progress = seconds / (minutes * 60)
            let warmup = min(progress / 0.15, 1)
            let finish = progress > 0.88 ? (progress - 0.88) / 0.12 * 18 : 0
            let noise = 3 * sin(seconds / 37)
            return HeartRatePoint(time: start.addingTimeInterval(seconds), bpm: 105 + 45 * warmup + finish + noise)
        }
        let bpm = heartRates.map(\.bpm)
        return WorkoutDetail(
            start: start, end: end, source: "Apple Watch", indoor: false,
            distanceKm: WorkoutDetails.distanceKm(route), elevationGainM: 48, temperatureC: 12,
            averageHeartRate: bpm.reduce(0, +) / Double(bpm.count), maxHeartRate: bpm.max(),
            heartRates: heartRates, route: route
        )
    }

    /// Deux séances passées par exercice ; la dernière dépasse les répétitions prévues, d'où une charge en hausse.
    @MainActor
    /// Séries notées hier : jambes et dos poussés jusqu'au bout, épaules et dos à l'effort visé.
    private static func seedMuscles(context: ModelContext, now: Date, calendar: Calendar) {
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else { return }
        let lifts: [(String, Double, Int, SetEffort)] = [
            ("Soulevé de terre", 100, 5, .hard), ("Développé militaire", 40, 6, .right),
            ("Rowing barre", 60, 8, .right), ("Fentes bulgares haltères", 16, 8, .hard),
        ]
        for (exercise, kg, reps, effort) in lifts {
            context.insert(LiftRecord(LiftEntry(exercise: exercise, date: calendar.storedDay(for: yesterday), kg: kg, reps: reps, effort: effort)))
        }
    }

    /// Faims passées, et une petite faim notée il y a vingt minutes.
    private static func seedHunger(context: ModelContext, now: Date, calendar: Calendar) {
        for note in DemoData.hunger(now: now, calendar: calendar) {
            context.insert(HungerRecord(date: note.date, level: note.level))
        }
        context.insert(HungerRecord(date: now.addingTimeInterval(-20 * 60), level: .peckish))
    }

    private static func seedLifts(for profile: UserProfile, context: ModelContext, now: Date, calendar: Calendar) {
        // Calibrage fait il y a deux semaines : une série de 5 sur chaque mouvement de référence.
        let tests: [Double] = [70, 52.5, 50, 100, 40, 45]
        for (exercise, kg) in zip(StrengthCalibration.referenceLifts, tests) {
            guard let date = calendar.date(byAdding: .day, value: -14, to: now) else { continue }
            context.insert(LiftRecord(LiftEntry(exercise: exercise, date: calendar.storedDay(for: date), kg: kg, reps: StrengthCalibration.testReps, isTest: true)))
        }
        guard case .workout(let workout) = CoachFactory.coach.plan(for: profile, weights: [], on: now).training.kind else { return }
        let loads: [Double] = [80, 60, 50, 70]
        // Mouvements principaux seulement : les compléments d'isolation gardent leur charge d'essai.
        let strength = workout.exercises.filter { $0.priority < 3 }
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

    static let demoHabitBreakfast = "trois tranches de pain complet, trois œufs et un café"

    /// Repas pris d'une touche les jours passés, pour le bilan des 7 jours (il y a 4 jours : aucun journal).
    static let demoReviewIntakes: [Int: [MealSlot: MealIntake]] = [
        1: [.snack: .asPlanned, .dinner: .light],
        2: [.breakfast: .asPlanned, .snack: .asPlanned, .dinner: .hearty],
        3: [.breakfast: .asPlanned, .lunch: .asPlanned, .snack: .skipped],
        5: [.breakfast: .asPlanned, .lunch: .asPlanned, .snack: .asPlanned, .dinner: .asPlanned],
        6: [.breakfast: .asPlanned, .lunch: .hearty],
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
        profileRecord.avoidedFoods = LaunchOptions.demoAvoid
        if let week = LaunchOptions.demoCycleWeek, let start = calendar.date(byAdding: .day, value: -7 * (week - 1), to: now) {
            profileRecord.cycle = TrainingCycle(program: LaunchOptions.demoHyrox ? .hyrox : .crossfit, startDate: start)
        }
        if LaunchOptions.demoFloorWeek, let start = calendar.date(byAdding: .day, value: -3, to: now) {
            profileRecord.startFloorWeek(on: start, calendar: calendar)
            profileRecord.floorProteinDays = (1...2).compactMap { calendar.date(byAdding: .day, value: -$0, to: now) }.map(calendar.storedDay(for:))
        }
        context.insert(profileRecord)

        let noise = [0.4, -0.3, 0.1, -0.5, 0.3, 0.0, -0.2]
        for offset in 0..<24 {
            let index = 23 - offset
            guard index % 5 != 3, let date = calendar.date(byAdding: .day, value: -offset, to: now) else { continue }
            // Poids visé au-dessus (-demoTarget) : prise lente, environ 0,2 kg par semaine.
            let perDay = (LaunchOptions.demoTargetKg ?? 0) > 88 ? -0.03 : LaunchOptions.demoCheckIn ? 0.17 : 0.09
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
            var described = Self.demoRecentMeals[offset] ?? [:]
            if LaunchOptions.demoHabits, [1, 2, 3, 5].contains(offset) { described[.breakfast] = Self.demoHabitBreakfast }
            if !described.isEmpty {
                log.describedMeals = described.mapValues { MealTextParser.parse($0).meal }
            }
            // Bilan des 7 jours : des repas notés d'une touche, plus ou moins copieux, et une journée incomplète.
            if LaunchOptions.demoReview != nil, offset < 7, let intakes = Self.demoReviewIntakes[offset] {
                log.mealIntakes = intakes.filter { described[$0.key] == nil }
            }
            context.insert(log)
        }

        if LaunchOptions.demoLifts { seedLifts(for: profile, context: context, now: now, calendar: calendar) }
        if LaunchOptions.demoHunger { seedHunger(context: context, now: now, calendar: calendar) }
        if LaunchOptions.demoMuscles { seedMuscles(context: context, now: now, calendar: calendar) }

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
