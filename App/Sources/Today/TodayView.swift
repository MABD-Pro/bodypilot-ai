import BodyPilotCore
import Coach
import Nutrition
import ProgressInsights
import SwiftData
import SwiftUI
import WorkoutKit

/// Écran principal : répond aux trois questions du jour et s'adapte en une touche.
struct TodayView: View {
    let profileRecord: ProfileRecord

    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("healthWeightSync") private var healthSync = false
    @Query(sort: \WeightRecord.date) private var weights: [WeightRecord]
    @Query private var dayLogs: [DayLogRecord]
    @Query private var weekPlans: [WeekPlanRecord]
    @Query(sort: \WaistRecord.date) private var waists: [WaistRecord]
    @State private var isAddingWaist = false
    @State private var describing: MealToDescribe?
    @State private var isAddingWeight = false
    @State private var isEditingProfile = false
    /// Entraînements lus dans Santé (Watch, autres apps), pour la semaine et la régularité.
    @State private var healthActivities: [ActivitySample] = []

    private let calendar = Calendar.current

    var body: some View {
        let now = Date.now
        let todayLog = log(on: now)
        let todayAdjustments = todayLog?.adjustments ?? []
        let weekPlan = weekPlans.first { calendar.isDate($0.weekStart, equalTo: now, toGranularity: .weekOfYear) }
        let weekDays = DayLogEditor.trainingDays(week: weekPlan, profile: profileRecord.profile)
        let doneLogs = dayLogs.filter(\.workoutDone)
        let lastWorkoutTitle = doneLogs
            .filter { $0.day < calendar.startOfDay(for: now) && $0.doneWorkoutTitle != nil }
            .max { $0.day < $1.day }?.doneWorkoutTitle
        let plan = CoachFactory.coach.plan(
            for: profileRecord.profile,
            weights: weights.map(\.entry),
            waists: waists.map(\.entry),
            adjustments: todayAdjustments,
            availableMinutes: todayLog?.availableMinutes,
            eatingOutSlot: todayLog?.eatingOutSlot,
            yesterdayAdjustments: adjustments(on: calendar.date(byAdding: .day, value: -1, to: now) ?? now),
            exerciseSwaps: todayLog?.exerciseSwaps ?? [:],
            weekTrainingDays: weekPlan?.weekdaysRaw,
            mealIntakes: todayLog?.mealIntakes ?? [:],
            describedMeals: todayLog?.describedMeals ?? [:],
            lastWorkoutTitle: lastWorkoutTitle,
            on: now
        )

        let activityAnalyzer = WeekActivityAnalyzer(calendar: calendar)
        let week = activityAnalyzer.week(
            of: now,
            samples: healthActivities,
            completed: doneLogs.map { (day: $0.day, title: $0.doneWorkoutTitle) },
            sessionMinutes: profileRecord.profile.sessionMinutes
        )
        // Une séance enregistrée par la Watch compte comme une séance cochée.
        let consistency = ConsistencyAnalyzer(calendar: calendar).consistency(
            completedDays: activityAnalyzer.sessionDays(completedDays: doneLogs.map(\.day), samples: healthActivities),
            on: now
        ) { day in
            let plan = weekPlans.first { calendar.isDate($0.weekStart, equalTo: day, toGranularity: .weekOfYear) }
            return DayLogEditor.trainingDays(week: plan, profile: profileRecord.profile).count
        }

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
                            swap: swapExercise,
                            isDone: todayLog?.workoutDone ?? false,
                            toggleDone: { toggleWorkoutDone(title: plan.training.workoutTitle) },
                            weekDays: weekDays,
                            toggleWeekDay: toggleWeekDay,
                            week: week,
                            healthLinked: healthLink == .on,
                            wantsToTrain: todayAdjustments.contains(.wantsToTrain) ? nil : { toggle(.wantsToTrain) },
                            cancelExtraSession: todayAdjustments.contains(.wantsToTrain) && plan.training.notes.contains { $0.hasPrefix("Séance en plus") }
                                ? { toggle(.wantsToTrain) } : nil,
                            planWeekOnWatch: { await planWeekOnWatch(today: plan.training, weekDays: weekDays, isTodayDone: todayLog?.workoutDone ?? false) }
                        )
                            .id("training")
                        ProgressCard(
                            trend: plan.trend,
                            message: plan.progressMessage,
                            profile: profileRecord.profile,
                            health: healthLink,
                            checkIn: checkIn,
                            consistency: consistency,
                            waistCm: waists.last?.cm,
                            waistChange: plan.waistChangeCm,
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

    private func importHealthActivities() async {
        guard !LaunchOptions.demoData else { return }
        let since = calendar.date(byAdding: .weekOfYear, value: -HealthWorkouts.lookbackWeeks, to: .now) ?? .now
        guard let samples = try? await HealthWorkouts.samples(since: since) else { return }
        withAnimation(Theme.springy) { healthActivities = samples }
    }

    /// Séances et marches de la semaine, d'aujourd'hui à dimanche, planifiées sur la montre.
    /// Aujourd'hui garde ses ajustements ; les jours suivants partent du plan de base.
    private func planWeekOnWatch(today: TrainingDay, weekDays: [Int], isTodayDone: Bool) async -> Bool {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: .now) else { return false }
        var plans: [(day: Date, plan: WorkoutPlan)] = []
        var day = calendar.startOfDay(for: .now)
        while day < week.end {
            let training: TrainingDay? = calendar.isDateInToday(day)
                ? (isTodayDone ? nil : today)
                : CoachFactory.coach.plan(for: profileRecord.profile, weights: weights.map(\.entry), weekTrainingDays: weekDays, on: day).training
            if let plan = training?.watchPlan { plans.append((day, plan)) }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return await WatchSchedule.replace(with: plans, calendar: calendar)
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

    private func adjustments(on date: Date) -> Set<QuickAdjustment> {
        log(on: date)?.adjustments ?? []
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

    /// Planning de la semaine : un jour coché ou décoché ne change que cette semaine.
    private func toggleWeekDay(_ weekday: Int) {
        withAnimation(Theme.springy) {
            DayLogEditor.toggleTrainingDay(weekday, on: .now, profile: profileRecord.profile, in: context, calendar: calendar)
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
