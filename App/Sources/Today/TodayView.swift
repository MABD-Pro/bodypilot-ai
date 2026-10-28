import BodyPilotCore
import Coach
import Nutrition
import ProgressInsights
import SwiftData
import SwiftUI
import Training
import WorkoutKit

/// Écran principal : répond aux trois questions du jour et s'adapte en une touche.
struct TodayView: View {
    let profileRecord: ProfileRecord

    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("healthWeightSync") private var healthSync = false
    @Query(sort: \WeightRecord.date) private var weights: [WeightRecord]
    @Query private var dayLogs: [DayLogRecord]
    @Query(filter: #Predicate<WaistRecord> { !$0.isScan }, sort: \WaistRecord.date) private var waists: [WaistRecord]
    @Query(sort: \LiftRecord.day) private var liftRecords: [LiftRecord]
    @Query(sort: \CardioTestRecord.day) private var cardioTests: [CardioTestRecord]
    @State private var isAddingWaist = false
    @State private var describing: MealToDescribe?
    @State private var isAddingWeight = false
    @State private var isEditingProfile = false
    @State private var isManagingData = false
    @State private var isManagingCycle = false
    @State private var isAnsweringScreening = false
    @State private var isShowingHistory = LaunchOptions.demoHistory != nil
    /// Ce que l'historique montre en s'ouvrant : la partie ou l'élément touché.
    @State private var historyFocus = HistoryView.Focus.section(.measures)
    /// Entraînements lus dans Santé (Watch, autres apps), pour la semaine et la régularité.
    @State private var healthActivities: [ActivitySample] = []
    /// Sommeil de la nuit passée, lu dans Santé.
    @State private var sleepHours: Double?
    /// Forme cardio estimée par la Watch et pouls au repos, lus dans Santé.
    @State private var watchCardio: CardioMeasure?
    @State private var restingHeartRate: Double?
    /// Premiers jours des dernières règles, lus dans Santé (femmes seulement).
    @State private var periodStarts: [Date] = []
    /// Taux de gras et masse maigre écrits dans Santé par la balance.
    @State private var compositions: [BodyCompositionEntry] = []

    private let calendar = Calendar.current

    var body: some View {
        let now = Date.now
        let todayLog = log(on: now)
        let todayAdjustments = todayLog?.adjustments ?? []
        let doneLogs = dayLogs.filter(\.workoutDone)
        let completed = doneLogs.map { (day: $0.day, title: $0.doneWorkoutTitle) }
        let lastStrength = DayLogEditor.lastStrength(before: now, completed: completed, samples: healthActivities, calendar: calendar)
        let activeDays = DayLogEditor.activeDays(before: now, completed: completed, samples: healthActivities, calendar: calendar)
        let cycleSessions = profileRecord.cycleSessions(
            on: now, recentAverage: CycleSessionPlan.recentAverage(doneDays: Array(activeDays), before: now, calendar: calendar), calendar: calendar
        )
        let lifts = liftRecords.map(\.entry)
        let cardioMeasures = cardioTests.map(\.measure) + [watchCardio].compactMap { $0 }
        let cardio = DayLogEditor.cardioStatus(for: profileRecord.profile, measures: cardioMeasures, restingHeartRate: restingHeartRate, on: now, calendar: calendar)
        let exerciseKcal = ExerciseEnergy.dailyAverage(
            samples: healthActivities, completed: completed,
            sessionMinutes: profileRecord.profile.sessionMinutes,
            weightKg: weights.last?.kg ?? profileRecord.startWeightKg, on: now, calendar: calendar
        )
        let plan = CoachFactory.coach.plan(
            for: profileRecord.profile,
            weights: weights.map(\.entry),
            waists: waists.map(\.entry),
            compositions: bodyCompositions,
            adjustments: todayAdjustments,
            availableMinutes: todayLog?.availableMinutes,
            eatingOutSlot: todayLog?.eatingOutSlot,
            exerciseSwaps: todayLog?.exerciseSwaps ?? [:],
            mealIntakes: todayLog?.mealIntakes ?? [:],
            describedMeals: todayLog?.describedMeals ?? [:],
            lastWorkoutTitle: lastStrength.title,
            lastStrengthDay: lastStrength.day,
            calibratedLifts: DayLogEditor.calibratedLifts(lifts, before: now, since: profileRecord.strengthTestResetAt, lastStrengthDay: lastStrength.day, calendar: calendar),
            sleepHours: sleepHours,
            activeDays: activeDays,
            recentActivities: healthActivities,
            trainingChoice: todayLog?.trainingChoice,
            cardio: cardio,
            exerciseKcalPerDay: exerciseKcal,
            cycle: profileRecord.cycle,
            cycleWorkoutsThisWeek: profileRecord.cycle?.workoutsThisWeek(completed, on: now, calendar: calendar) ?? [],
            cycleSessionsPerWeek: cycleSessions?.sessions,
            on: now
        )

        let activityAnalyzer = WeekActivityAnalyzer(calendar: calendar)
        let week = activityAnalyzer.week(
            of: now,
            samples: healthActivities,
            completed: completed,
            sessionMinutes: profileRecord.profile.sessionMinutes
        )
        let checkIn = profileRecord.isCheckInDue(at: now)
            ? CoachFactory.coach.weeklyCheckIn(
                for: profileRecord.profile,
                weights: weights.map(\.entry),
                waists: waists.map(\.entry),
                compositions: bodyCompositions,
                exerciseKcalPerDay: exerciseKcal,
                retainsWater: profileRecord.profile.sex == .female
                    && MenstrualCycle.retainsWater(periodStarts: periodStarts, on: now, calendar: calendar),
                on: now
            )
            : nil

        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                        header(plan: plan, date: now)
                        if !profileRecord.screening.isAnswered {
                            screeningBanner
                        }
                        CommandField(apply: apply)
                        AdjustmentBar(active: todayAdjustments, toggle: toggle)
                        NutritionCard(targets: plan.targets, meals: plan.meals, logIntake: logIntake, describe: { slot in
                            describing = MealToDescribe(slot: slot, current: todayLog?.describedMeals[slot])
                        }, recent: { slot in
                            RecentMeals.list(for: slot, history: recentMealHistory(now: now), today: now, calendar: calendar)
                        }, reuse: { slot, meal in
                            saveDescribed(meal, for: slot)
                        }, showHistory: { slot in showHistory(slot.map { .meal($0) } ?? .section(.meals)) })
                            .id("nutrition")
                        TrainingCard(
                            training: (todayLog?.sessionEdits ?? SessionEdits()).apply(to: plan.training),
                            options: plan.trainingOptions,
                            choice: todayLog?.trainingChoice ?? plan.trainingOptions.recommended,
                            choose: chooseTraining,
                            adjustments: todayAdjustments,
                            setFeeling: setFeeling,
                            swap: swapExercise,
                            isDone: todayLog?.workoutDone ?? false,
                            toggleDone: { toggleWorkoutDone(title: plan.training.workoutTitle) },
                            week: week,
                            healthLinked: healthLink == .on,
                            lifts: lifts,
                            lastStrengthDay: lastStrength.day,
                            usesLoads: profileRecord.profile.equipment == .gym,
                            logLift: logLift,
                            bodyweightKg: weights.last?.kg ?? profileRecord.startWeightKg,
                            sex: profileRecord.profile.sex,
                            cardioTestToday: cardioTests.last { calendar.isDateInToday($0.day) }?.measure,
                            logCardioTest: logCardioTest,
                            cycleWeek: profileRecord.cycle?.week(on: now, calendar: calendar),
                            // Pas de cycle (séries au maximum, fractionné) tant qu'un avis médical est attendu.
                            canStartCycle: profileRecord.profile.equipment == .gym && !profileRecord.screening.restrictsIntensity,
                            manageCycle: { isManagingCycle = true },
                            cycleSessions: cycleSessions,
                            setCycleSessions: { sessions in
                                withAnimation(Theme.springy) { profileRecord.confirmCycleSessions(sessions, on: .now, calendar: calendar) }
                                try? context.save()
                            },
                            benchmarkToday: todayLog?.benchmarkSeconds,
                            previousBenchmark: dayLogs.filter { !calendar.isDateInToday($0.day) && $0.benchmarkSeconds != nil }.max { $0.day < $1.day }?.benchmarkSeconds,
                            logBenchmark: logBenchmark,
                            loadShifts: todayLog?.loadShifts ?? [:],
                            shiftLoads: { exercise, kg in
                                let log = DayLogEditor.todayLog(in: context, calendar: calendar)
                                log.loadShifts[exercise] = kg
                                try? context.save()
                            },
                            edits: todayLog?.sessionEdits ?? SessionEdits(),
                            editSession: { edits in
                                let log = DayLogEditor.todayLog(in: context, calendar: calendar)
                                withAnimation(Theme.springy) { log.sessionEdits = edits }
                                try? context.save()
                            },
                            showHistory: { showHistory(.section(.sessions)) }
                        )
                            .id("training")
                        ProgressCard(
                            trend: plan.trend,
                            message: plan.progressMessage,
                            profile: profileRecord.profile,
                            health: healthLink,
                            checkIn: checkIn,
                            waistCm: waists.last?.cm,
                            waistChange: plan.waistChangeCm,
                            composition: plan.composition,
                            records: StrengthProgress.records(in: lifts),
                            cardio: CardioTest.latest(cardioMeasures),
                            cardioZone: cardio.moderateHeartRate,
                            sleepHours: sleepHours,
                            addWeight: { isAddingWeight = true },
                            addWaist: { isAddingWaist = true },
                            acceptCheckIn: { acceptCheckIn(checkIn) },
                            dismissCheckIn: { withAnimation(Theme.springy) { profileRecord.lastCheckInAt = .now } },
                            connectHealth: { Task { await connectHealth() } },
                            disconnectHealth: { healthSync = false },
                            showHistory: showHistory
                        )
                        .id("progress")
                    }
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.bottom, Theme.Spacing.xxl)
                    .animation(Theme.springy, value: plan)
                }
                .scrollIndicators(.hidden)
                .task {
                    if LaunchOptions.demoActivities { healthActivities = DemoData.activities() }
                    if LaunchOptions.demoComposition { compositions = DemoData.compositions() }
                    if let hours = LaunchOptions.demoSleepHours { sleepHours = hours }
                    if LaunchOptions.demoData && !LaunchOptions.demoCardioTest {
                        watchCardio = DemoData.watchCardio()
                        restingHeartRate = 58
                    }
                    guard let target = LaunchOptions.demoScrollTarget else { return }
                    try? await Task.sleep(for: .seconds(2))
                    withAnimation { proxy.scrollTo(target, anchor: .top) }
                }
            }
            .background { AppBackground() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("Mon profil", systemImage: "person.crop.circle") {
                        Button("Mon profil", systemImage: "person") { isEditingProfile = true }
                        Button("Mes données", systemImage: "externaldrive") { isManagingData = true }
                    }
                }
            }
            .sensoryFeedback(.selection, trigger: todayAdjustments)
            .onChange(of: plan.training.workoutTitle, initial: true) { _, title in
                DisplayedWorkout.remember(title, on: now, calendar: calendar)
            }
            .onChange(of: scenePhase) { _, phase in
                // Tout ce qui a été touché est écrit avant que l'app ne passe en arrière-plan.
                if phase != .active { try? context.save() }
                // Copie du jour dans le dossier choisi, si l'utilisateur l'a demandée.
                if phase == .background, !LaunchOptions.demoData { AutoBackup.runIfDue(context: context) }
            }
            .sensoryFeedback(.selection, trigger: todayLog?.exerciseSwapsRaw.count ?? 0)
            .task(id: scenePhase) {
                // À chaque retour dans l'app : les pesées de la balance arrivent toutes seules.
                guard scenePhase == .active, healthSync else { return }
                // Déjà relié avant l'envoi des repas : Santé demande une fois l'autorisation d'écrire.
                if !LaunchOptions.demoData { try? await HealthWeight.requestAccess(includeCycle: tracksCycle) }
                await importFromHealth()
                await exportMeals(plan.meals, on: now)
            }
            .task(id: [String(healthSync)] + HealthMealExport(calendar: calendar).entries(for: plan.meals, on: now, now: now).map(\.fingerprint)) {
                // Un repas pris, décrit, modifié ou annulé : Santé suit aussitôt.
                await exportMeals(plan.meals, on: now)
            }
            .navigationDestination(isPresented: $isShowingHistory) {
                HistoryView(healthActivities: healthActivities, compositions: bodyCompositions, focus: historyFocus)
            }
            .sheet(isPresented: $isAddingWeight) {
                WeightEntrySheet(initialKg: weights.last?.kg ?? profileRecord.startWeightKg)
            }
            .sheet(item: $describing) { item in
                MealDescriptionSheet(slot: item.slot, initial: item.current) { meal in
                    saveDescribed(meal, for: item.slot)
                }
            }
            .sheet(isPresented: $isAddingWaist) {
                WaistEntrySheet(initialCm: waists.last?.cm ?? 90)
            }
            .sheet(isPresented: $isAnsweringScreening) {
                HealthScreeningSheet(profile: profileRecord)
            }
            .sheet(isPresented: $isManagingCycle) {
                CycleSheet(profile: profileRecord)
            }
            .sheet(isPresented: $isManagingData) {
                DataBackupSheet()
            }
            .sheet(isPresented: $isEditingProfile) {
                OnboardingView(editing: profileRecord, currentWeightKg: weights.last?.kg)
            }
        }
    }

    private func acceptCheckIn(_ suggestion: CalorieSuggestion?) {
        guard let suggestion else { return }
        withAnimation(Theme.springy) {
            profileRecord.calorieAdjustmentKcal += suggestion.deltaKcal
            profileRecord.lastCheckInAt = .now
        }
    }

    private var healthLink: HealthLink {
        if LaunchOptions.demoHealth { return .on }
        guard HealthWeight.isAvailable else { return .unavailable }
        return healthSync ? .on : .off
    }

    private func connectHealth() async {
        do {
            try await HealthWeight.requestAccess(includeCycle: tracksCycle)
        } catch {
            return
        }
        healthSync = true
        await importFromHealth()
    }

    /// Repas mangés du jour → Santé ; un repas annulé ou sauté en est retiré.
    private func exportMeals(_ meals: DayMealPlan, on day: Date) async {
        guard healthSync, HealthWeight.isAvailable, !LaunchOptions.demoData else { return }
        let export = HealthMealExport(calendar: calendar)
        await HealthMeals.shared.sync(
            export.entries(for: meals, on: day, now: .now),
            ids: MealSlot.allCases.map { export.id(for: $0, on: day) }
        )
    }

    /// Toutes les lectures Santé partent en même temps, puis l'écran change une seule fois :
    /// le plan se recalcule une fois au lieu d'une fois par lecture.
    private func importFromHealth() async {
        guard !LaunchOptions.demoData else { return }
        let calendar = calendar
        let readsCycle = tracksCycle
        let weightsSince = calendar.date(byAdding: .day, value: -HealthWeight.lookbackDays, to: .now) ?? .now
        let activitiesSince = calendar.date(byAdding: .weekOfYear, value: -HealthWorkouts.lookbackWeeks, to: .now) ?? .now
        async let weightSamples = try? HealthWeight.samples(since: weightsSince)
        async let activities = try? HealthWorkouts.samples(since: activitiesSince)
        async let sleep = try? HealthSleep.lastNightHours(calendar: calendar)
        async let measure = try? HealthCardio.latestVO2max()
        async let resting = try? HealthCardio.restingHeartRate()
        async let values = HealthProfile.read(calendar: calendar)
        async let starts: [Date]? = readsCycle ? (try? HealthCycle.periodStarts(calendar: calendar)) : nil
        async let entries = HealthBodyComposition.entries(calendar: calendar)
        let read = await (weights: weightSamples, activities: activities, sleep: sleep, measure: measure,
                          resting: resting, values: values, starts: starts, entries: entries)

        let toImport = read.weights.map {
            WeightImportPlanner(calendar: calendar).samplesToImport(
                $0,
                recordedDays: Set(weights.map { calendar.startOfDay(for: $0.date) }),
                knownIDs: Set(weights.compactMap(\.externalID))
            )
        } ?? []
        withAnimation(Theme.springy) {
            for sample in toImport {
                context.insert(WeightRecord(sample))
            }
            if let activities = read.activities { healthActivities = activities }
            if let hours = read.sleep { sleepHours = hours }
            watchCardio = read.measure
            restingHeartRate = read.resting
            if let starts = read.starts { periodStarts = starts }
            compositions = read.entries
            // Taille, date de naissance et sexe de Santé : le profil suit, les besoins se recalculent.
            if let height = read.values.heightCm, abs(height - profileRecord.heightCm) >= 1 {
                profileRecord.heightCm = height
            }
            if let birthDate = read.values.birthDate, !calendar.isDate(birthDate, inSameDayAs: profileRecord.birthDate) {
                profileRecord.birthDate = birthDate
            }
            if let sex = read.values.sex, sex.rawValue != profileRecord.sexRaw {
                profileRecord.sexRaw = sex.rawValue
            }
        }
        try? context.save()
    }

    private var tracksCycle: Bool { profileRecord.profile.sex == .female }

    /// Une balance qui n'écrit que le taux de gras : la masse maigre se déduit de la pesée du même jour.
    /// Une masse maigre incohérente avec le poids et le taux de gras (plus de 5 kg d'écart) est écartée.
    private var bodyCompositions: [BodyCompositionEntry] {
        compositions.map { entry in
            var entry = entry
            if let fat = entry.fatPercent,
               let weight = weights.last(where: { calendar.isDate($0.date, inSameDayAs: entry.date) }) {
                let derived = weight.kg * (1 - fat / 100)
                if let lean = entry.leanKg, abs(lean - derived) > 5 { entry.leanKg = nil }
                if entry.leanKg == nil { entry.leanKg = derived }
            }
            return entry
        }
    }

    /// Test de marche noté : la forme cardio du jour, un seul test par jour.
    private func logCardioTest(minutes: Double, heartRate: Int) {
        let profile = profileRecord.profile
        let vo2max = CardioTest.vo2max(
            minutes: minutes, heartRate: heartRate,
            weightKg: weights.last?.kg ?? profile.startWeightKg,
            age: profile.age(on: .now, calendar: calendar), sex: profile.sex
        )
        withAnimation(Theme.springy) {
            if let existing = cardioTests.last(where: { calendar.isDateInToday($0.day) }) {
                existing.minutes = minutes
                existing.heartRate = heartRate
                existing.vo2max = vo2max
            } else {
                context.insert(CardioTestRecord(day: calendar.storedDay(for: .now), minutes: minutes, heartRate: heartRate, vo2max: vo2max))
            }
        }
        try? context.save()
    }

    private func chooseTraining(_ choice: TrainingChoice) {
        let log = todayLog()
        withAnimation(Theme.springy) {
            // Une autre proposition : la séance retouchée pour l'ancienne ne s'applique plus.
            if log.trainingChoice != choice { log.sessionEdits = SessionEdits() }
            log.trainingChoice = choice
        }
        try? context.save()
    }

    /// « Comment te sens-tu ? » : en forme efface fatigue et courbatures, les autres s'activent ou s'éteignent.
    private func setFeeling(_ feeling: Feeling) {
        let log = todayLog()
        withAnimation(Theme.springy) {
            var adjustments = log.adjustments
            switch feeling {
            case .great: adjustments.subtract([.tired, .sore])
            case .sore: adjustments.formSymmetricDifference([.sore])
            case .tired: adjustments.formSymmetricDifference([.tired])
            }
            log.adjustments = adjustments
            // Le ressenti change la recommandation : on la suit plutôt qu'un ancien choix.
            log.trainingChoice = nil
        }
        try? context.save()
    }

    /// Profil créé avant le questionnaire de santé : on le propose une fois, sans bloquer.
    private var screeningBanner: some View {
        Button { isAnsweringScreening = true } label: {
            HStack(spacing: Theme.Spacing.m) {
                IconBadge(symbol: "stethoscope", tint: Theme.protein, size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Questionnaire de santé")
                        .font(.subheadline.weight(.semibold))
                    Text("Sept questions, 30 secondes : le coach adapte l'intensité si besoin.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(Theme.Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: Theme.Radius.inner + 4))
    }

    private func header(plan: TodayPlan, date: Date) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Theme.locale)).capitalizingFirstLetter)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(greeting(at: date))
                .font(.display(34))
            Text(plan.headline)
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
        }
        .padding(.top, Theme.Spacing.s)
    }

    private func greeting(at date: Date) -> String {
        switch calendar.component(.hour, from: date) {
        case 5..<12: "Bonjour"
        case 12..<18: "Bon après-midi"
        default: "Bonsoir"
        }
    }

    private func log(on date: Date) -> DayLogRecord? {
        dayLogs.first { calendar.isDate($0.day, inSameDayAs: date) }
    }

    private func todayLog() -> DayLogRecord {
        if let existing = log(on: .now) { return existing }
        let created = DayLogRecord(day: calendar.storedDay(for: .now))
        context.insert(created)
        return created
    }

    private func toggle(_ adjustment: QuickAdjustment) {
        let log = todayLog()
        withAnimation(Theme.springy) {
            var current = log.adjustments
            if current.contains(adjustment) {
                current.remove(adjustment)
                if adjustment == .shortOnTime { log.availableMinutes = nil }
                if adjustment == .eatingOut { log.eatingOutSlot = nil }
            } else {
                current.insert(adjustment)
                // Le repas visé est fixé maintenant : il ne bascule plus au dîner à 15 h.
                if adjustment == .eatingOut, log.eatingOutSlot == nil {
                    log.eatingOutSlot = MealConstraints.nextMainMeal(at: .now, calendar: calendar)
                }
            }
            log.adjustments = current
        }
    }

    /// Un exercice ne convient pas (poste occupé, matériel absent) : variante suivante, pour la journée.
    private func swapExercise(key: String) {
        let log = todayLog()
        withAnimation(Theme.springy) {
            log.exerciseSwapsRaw.append(key)
        }
    }

    /// Repas pris : `nil` annule la saisie. Les repas suivants se recalculent aussitôt.
    private func logIntake(_ slot: MealSlot, _ intake: MealIntake?) {
        let log = todayLog()
        withAnimation(Theme.springy) {
            log.mealIntakes[slot] = intake
            if intake == nil { log.describedMeals[slot] = nil }
        }
    }

    /// Repas décrits des 7 derniers jours (seuls ces journaux sont décodés).
    private func showHistory(_ focus: HistoryView.Focus) {
        historyFocus = focus
        isShowingHistory = true
    }

    private func recentMealHistory(now: Date) -> [(day: Date, meals: [MealSlot: DescribedMeal])] {
        guard let since = calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: now)) else { return [] }
        return dayLogs
            .filter { $0.day >= since && $0.describedMealsData != nil }
            .map { (day: $0.day, meals: $0.describedMeals) }
    }

    /// Repas décrit en texte : il remplace la saisie d'une touche pour ce repas.
    private func saveDescribed(_ meal: DescribedMeal, for slot: MealSlot) {
        let log = todayLog()
        withAnimation(Theme.springy) {
            log.describedMeals[slot] = meal
            log.mealIntakes[slot] = nil
        }
        try? context.save()
    }

    /// Meilleure série du jour : une seule par exercice, la dernière saisie la remplace.
    private func logLift(_ entry: LiftEntry) {
        withAnimation(Theme.springy) {
            if let existing = liftRecords.first(where: { $0.exercise == entry.exercise && calendar.isDate($0.day, inSameDayAs: entry.date) }) {
                existing.kg = entry.kg
                existing.reps = entry.reps
                existing.isTest = entry.isTest
            } else {
                context.insert(LiftRecord(entry))
            }
        }
        try? context.save()
    }

    private func logBenchmark(_ seconds: Int) {
        let log = todayLog()
        withAnimation(Theme.springy) {
            log.benchmarkSeconds = seconds
        }
    }

    private func toggleWorkoutDone(title: String?) {
        let log = todayLog()
        withAnimation(Theme.springy) {
            log.workoutDone.toggle()
            log.doneWorkoutTitle = log.workoutDone ? title : nil
        }
    }

    /// Phrase libre comprise : on ajoute les ajustements, sans retirer ceux déjà choisis.
    private func apply(_ command: InterpretedCommand) {
        let log = todayLog()
        withAnimation(Theme.springy) {
            DayLogEditor.apply(command, to: log)
        }
    }
}

#Preview {
    RootView()
        .modelContainer(AppContainer.preview)
}

/// Repas en cours de description, pour présenter la feuille de saisie.
private struct MealToDescribe: Identifiable {
    let slot: MealSlot
    let current: DescribedMeal?
    var id: String { slot.rawValue }
}
