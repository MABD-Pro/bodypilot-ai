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
    @Query(sort: \WaistRecord.date) private var waists: [WaistRecord]
    @Query(sort: \LiftRecord.day) private var liftRecords: [LiftRecord]
    @State private var isAddingWaist = false
    @State private var describing: MealToDescribe?
    @State private var isAddingWeight = false
    @State private var isEditingProfile = false
    /// Entraînements lus dans Santé (Watch, autres apps), pour la semaine et la régularité.
    @State private var healthActivities: [ActivitySample] = []
    /// Sommeil de la nuit passée, lu dans Santé.
    @State private var sleepHours: Double?

    private let calendar = Calendar.current

    var body: some View {
        let now = Date.now
        let todayLog = log(on: now)
        let todayAdjustments = todayLog?.adjustments ?? []
        let doneLogs = dayLogs.filter(\.workoutDone)
        let completed = doneLogs.map { (day: $0.day, title: $0.doneWorkoutTitle) }
        let lastStrength = DayLogEditor.lastStrength(before: now, completed: completed, samples: healthActivities, calendar: calendar)
        let lifts = liftRecords.map(\.entry)
        let plan = CoachFactory.coach.plan(
            for: profileRecord.profile,
            weights: weights.map(\.entry),
            waists: waists.map(\.entry),
            adjustments: todayAdjustments,
            availableMinutes: todayLog?.availableMinutes,
            eatingOutSlot: todayLog?.eatingOutSlot,
            exerciseSwaps: todayLog?.exerciseSwaps ?? [:],
            mealIntakes: todayLog?.mealIntakes ?? [:],
            describedMeals: todayLog?.describedMeals ?? [:],
            lastWorkoutTitle: lastStrength.title,
            lastStrengthDay: lastStrength.day,
            calibratedLifts: DayLogEditor.calibratedLifts(lifts, before: now, calendar: calendar),
            sleepHours: sleepHours,
            activeDays: DayLogEditor.activeDays(before: now, completed: completed, samples: healthActivities, calendar: calendar),
            recentActivities: healthActivities,
            trainingChoice: todayLog?.trainingChoice,
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
            ? CoachFactory.coach.weeklyCheckIn(for: profileRecord.profile, weights: weights.map(\.entry), waists: waists.map(\.entry), on: now)
            : nil

        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                        header(plan: plan, date: now)
                        CommandField(apply: apply)
                        AdjustmentBar(active: todayAdjustments, toggle: toggle)
                        NutritionCard(targets: plan.targets, meals: plan.meals, logIntake: logIntake, describe: { slot in
                            describing = MealToDescribe(slot: slot, current: todayLog?.describedMeals[slot])
                        })
                            .id("nutrition")
                        TrainingCard(
                            training: plan.training,
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
                            usesLoads: profileRecord.profile.equipment == .gym,
                            logLift: logLift,
                            bodyweightKg: weights.last?.kg ?? profileRecord.startWeightKg,
                            sex: profileRecord.profile.sex
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
                            records: StrengthProgress.records(in: lifts),
                            addWeight: { isAddingWeight = true },
                            addWaist: { isAddingWaist = true },
                            acceptCheckIn: { acceptCheckIn(checkIn) },
                            dismissCheckIn: { withAnimation(Theme.springy) { profileRecord.lastCheckInAt = .now } },
                            connectHealth: { Task { await connectHealth() } },
                            disconnectHealth: { healthSync = false }
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
                    if let hours = LaunchOptions.demoSleepHours { sleepHours = hours }
                    guard let target = LaunchOptions.demoScrollTarget else { return }
                    try? await Task.sleep(for: .seconds(2))
                    withAnimation { proxy.scrollTo(target, anchor: .top) }
                }
            }
            .background { AppBackground() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Mon profil", systemImage: "person.crop.circle") {
                        isEditingProfile = true
                    }
                }
            }
            .sensoryFeedback(.selection, trigger: todayAdjustments)
            .sensoryFeedback(.selection, trigger: todayLog?.exerciseSwapsRaw.count ?? 0)
            .task(id: scenePhase) {
                // À chaque retour dans l'app : les pesées de la balance arrivent toutes seules.
                guard scenePhase == .active, healthSync else { return }
                // Déjà relié avant l'envoi des repas : Santé demande une fois l'autorisation d'écrire.
                if !LaunchOptions.demoData { try? await HealthWeight.requestAccess() }
                await importHealthWeights()
                await importHealthActivities()
                await importSleep()
                await exportMeals(plan.meals, on: now)
            }
            .task(id: [String(healthSync)] + HealthMealExport(calendar: calendar).entries(for: plan.meals, on: now, now: now).map(\.fingerprint)) {
                // Un repas pris, décrit, modifié ou annulé : Santé suit aussitôt.
                await exportMeals(plan.meals, on: now)
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
            .sheet(isPresented: $isEditingProfile) {
                OnboardingView(editing: profileRecord)
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
            try await HealthWeight.requestAccess()
        } catch {
            return
        }
        healthSync = true
        await importHealthWeights()
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

    private func importSleep() async {
        guard !LaunchOptions.demoData, let hours = try? await HealthSleep.lastNightHours(calendar: calendar) else { return }
        withAnimation(Theme.springy) { sleepHours = hours }
    }

    private func chooseTraining(_ choice: TrainingChoice) {
        let log = todayLog()
        withAnimation(Theme.springy) { log.trainingChoice = choice }
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

    private func importHealthActivities() async {
        guard !LaunchOptions.demoData else { return }
        let since = calendar.date(byAdding: .weekOfYear, value: -HealthWorkouts.lookbackWeeks, to: .now) ?? .now
        guard let samples = try? await HealthWorkouts.samples(since: since) else { return }
        withAnimation(Theme.springy) { healthActivities = samples }
    }

    private func importHealthWeights() async {
        guard !LaunchOptions.demoData else { return }
        let since = calendar.date(byAdding: .day, value: -HealthWeight.lookbackDays, to: .now) ?? .now
        guard let samples = try? await HealthWeight.samples(since: since) else { return }
        let toImport = WeightImportPlanner(calendar: calendar).samplesToImport(
            samples,
            recordedDays: Set(weights.map { calendar.startOfDay(for: $0.date) }),
            knownIDs: Set(weights.compactMap(\.externalID))
        )
        withAnimation(Theme.springy) {
            for sample in toImport {
                context.insert(WeightRecord(sample))
            }
        }
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
        let created = DayLogRecord(day: calendar.startOfDay(for: .now))
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
