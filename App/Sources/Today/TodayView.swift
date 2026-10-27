import BodyPilotCore
import Coach
import ProgressInsights
import SwiftData
import SwiftUI

/// Écran principal : répond aux trois questions du jour et s'adapte en une touche.
struct TodayView: View {
    let profileRecord: ProfileRecord

    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("healthWeightSync") private var healthSync = false
    @Query(sort: \WeightRecord.date) private var weights: [WeightRecord]
    @Query private var dayLogs: [DayLogRecord]
    @Query private var weekPlans: [WeekPlanRecord]
    @State private var isAddingWeight = false
    @State private var isEditingProfile = false

    private let calendar = Calendar.current

    var body: some View {
        let now = Date.now
        let todayLog = log(on: now)
        let todayAdjustments = todayLog?.adjustments ?? []
        let weekPlan = weekPlans.first { calendar.isDate($0.weekStart, equalTo: now, toGranularity: .weekOfYear) }
        let weekDays = DayLogEditor.trainingDays(week: weekPlan, profile: profileRecord.profile)
        let plan = CoachFactory.coach.plan(
            for: profileRecord.profile,
            weights: weights.map(\.entry),
            adjustments: todayAdjustments,
            availableMinutes: todayLog?.availableMinutes,
            eatingOutSlot: todayLog?.eatingOutSlot,
            yesterdayAdjustments: adjustments(on: calendar.date(byAdding: .day, value: -1, to: now) ?? now),
            exerciseSwaps: todayLog?.exerciseSwaps ?? [:],
            weekTrainingDays: weekPlan?.weekdaysRaw,
            on: now
        )

        let consistency = ConsistencyAnalyzer(calendar: calendar).consistency(
            completedDays: dayLogs.filter(\.workoutDone).map(\.day),
            plannedPerWeek: weekDays.count,
            on: now
        )

        let checkIn = profileRecord.isCheckInDue(at: now)
            ? CoachFactory.coach.weeklyCheckIn(for: profileRecord.profile, weights: weights.map(\.entry), on: now)
            : nil

        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                        header(plan: plan, date: now)
                        CommandField(apply: apply)
                        AdjustmentBar(active: todayAdjustments, toggle: toggle)
                        NutritionCard(targets: plan.targets, meals: plan.meals)
                            .id("nutrition")
                        TrainingCard(
                            training: plan.training,
                            swap: swapExercise,
                            isDone: todayLog?.workoutDone ?? false,
                            toggleDone: toggleWorkoutDone,
                            weekDays: weekDays,
                            toggleWeekDay: toggleWeekDay
                        )
                            .id("training")
                        ProgressCard(
                            trend: plan.trend,
                            message: plan.progressMessage,
                            profile: profileRecord.profile,
                            health: healthLink,
                            checkIn: checkIn,
                            consistency: consistency,
                            addWeight: { isAddingWeight = true },
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
                if scenePhase == .active, healthSync { await importHealthWeights() }
            }
            .sheet(isPresented: $isAddingWeight) {
                WeightEntrySheet(initialKg: weights.last?.kg ?? profileRecord.startWeightKg)
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

    /// Planning de la semaine : un jour coché ou décoché ne change que cette semaine.
    private func toggleWeekDay(_ weekday: Int) {
        withAnimation(Theme.springy) {
            DayLogEditor.toggleTrainingDay(weekday, on: .now, profile: profileRecord.profile, in: context, calendar: calendar)
        }
    }

    private func toggleWorkoutDone() {
        let log = todayLog()
        withAnimation(Theme.springy) {
            log.workoutDone.toggle()
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
