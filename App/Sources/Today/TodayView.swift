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

    private let calendar = Calendar.current

    var body: some View {
        let now = Date.now
        let todayLog = log(on: now)
        let todayAdjustments = todayLog?.adjustments ?? []
        let doneLogs = dayLogs.filter(\.workoutDone)
        let completed = doneLogs.map { (day: $0.day, title: $0.doneWorkoutTitle) }
        let lastStrength = DayLogEditor.lastStrength(before: now, completed: completed, samples: healthActivities, calendar: calendar)
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
            on: now
        )
        // Les jours suivants supposent la séance du jour faite.
        let afterToday = strength(after: plan.training, on: now, otherwise: lastStrength)

        let activityAnalyzer = WeekActivityAnalyzer(calendar: calendar)
        let week = activityAnalyzer.week(
            of: now,
            samples: healthActivities,
            completed: completed,
            sessionMinutes: profileRecord.profile.sessionMinutes
        )
        // Régularité : séances de force de la semaine, cochées ou enregistrées par la Watch.
        let strengthDays = completed.filter { $0.title.map(TrainingPlanner.isStrengthSession) == true }.map(\.day)
            + healthActivities.filter { $0.kind == .strength && $0.minutes >= 20 }.map(\.start)
        let consistency = ConsistencyAnalyzer(calendar: calendar).consistency(
            completedDays: strengthDays,
            plannedPerWeek: TrainingPlanner.weeklyStrengthTarget,
            on: now
        )

        let lifts = liftRecords.map(\.entry)

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
                            week: week,
                            healthLinked: healthLink == .on,
                            planWeekOnWatch: { await planWeekOnWatch(today: plan.training, isTodayDone: todayLog?.workoutDone ?? false, after: afterToday) },
                            lifts: lifts,
                            usesLoads: profileRecord.profile.equipment == .gym,
                            logLift: logLift,
                            bodyweightKg: weights.last?.kg ?? profileRecord.startWeightKg,
                            sex: profileRecord.profile.sex,
                            upcoming: forecast(from: calendar.date(byAdding: .day, value: 1, to: now) ?? now, days: 6, last: afterToday)
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

    /// Les jours à venir, en supposant chaque séance proposée faite : la force revient au plus
    /// tous les deux jours, cardio et marche entre deux.
    private func forecast(from start: Date, days: Int, last: (day: Date?, title: String?)) -> [UpcomingDay] {
        var last = last
        var result: [UpcomingDay] = []
        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { break }
            let training = CoachFactory.coach.plan(
                for: profileRecord.profile, weights: weights.map(\.entry), lastWorkoutTitle: last.title, lastStrengthDay: last.day, on: day
            ).training
            if case .workout(let workout) = training.kind, workout.hasStrength {
                last = (calendar.startOfDay(for: day), workout.title)
            }
            result.append(UpcomingDay(date: calendar.startOfDay(for: day), training: training))
        }
        return result
    }

    /// Séances de la semaine, d'aujourd'hui à dimanche, planifiées sur la montre.
    /// Aujourd'hui garde ses ajustements ; les jours suivants partent du plan de base.
    private func planWeekOnWatch(today: TrainingDay, isTodayDone: Bool, after last: (day: Date?, title: String?)) async -> Bool {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: .now),
              let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now))
        else { return false }
        let remaining = calendar.dateComponents([.day], from: tomorrow, to: week.end).day ?? 0
        var plans: [(day: Date, plan: WorkoutPlan)] = []
        if !isTodayDone, let plan = today.watchPlan { plans.append((calendar.startOfDay(for: .now), plan)) }
        for upcoming in forecast(from: tomorrow, days: max(remaining, 0), last: last) {
            if let plan = upcoming.training.watchPlan { plans.append((upcoming.date, plan)) }
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

    /// Dernière force une fois la séance du jour faite.
    private func strength(after training: TrainingDay, on day: Date, otherwise last: (day: Date?, title: String?)) -> (day: Date?, title: String?) {
        guard case .workout(let workout) = training.kind, workout.hasStrength else { return last }
        return (calendar.startOfDay(for: day), workout.title)
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
