import BodyPilotCore
import Coach
import SwiftData
import SwiftUI

/// Écran principal : répond aux trois questions du jour et s'adapte en une touche.
struct TodayView: View {
    let profileRecord: ProfileRecord

    @Environment(\.modelContext) private var context
    @Query(sort: \WeightRecord.date) private var weights: [WeightRecord]
    @Query private var dayLogs: [DayLogRecord]
    @State private var isAddingWeight = false
    @State private var isEditingProfile = false

    private let calendar = Calendar.current

    var body: some View {
        let now = Date.now
        let todayAdjustments = adjustments(on: now)
        let plan = CoachFactory.coach.plan(
            for: profileRecord.profile,
            weights: weights.map(\.entry),
            adjustments: todayAdjustments,
            yesterdayAdjustments: adjustments(on: calendar.date(byAdding: .day, value: -1, to: now) ?? now),
            on: now
        )

        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                        header(plan: plan, date: now)
                        AdjustmentBar(active: todayAdjustments, toggle: toggle)
                        NutritionCard(targets: plan.targets, meals: plan.meals)
                            .id("nutrition")
                        TrainingCard(training: plan.training)
                            .id("training")
                        ProgressCard(trend: plan.trend, message: plan.progressMessage, profile: profileRecord.profile) {
                            isAddingWeight = true
                        }
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
            .sheet(isPresented: $isAddingWeight) {
                WeightEntrySheet(initialKg: weights.last?.kg ?? profileRecord.startWeightKg)
            }
            .sheet(isPresented: $isEditingProfile) {
                OnboardingView(editing: profileRecord)
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

    private func adjustments(on date: Date) -> Set<QuickAdjustment> {
        let day = calendar.startOfDay(for: date)
        return dayLogs.first { calendar.isDate($0.day, inSameDayAs: day) }?.adjustments ?? []
    }

    private func toggle(_ adjustment: QuickAdjustment) {
        let day = calendar.startOfDay(for: .now)
        let log: DayLogRecord
        if let existing = dayLogs.first(where: { calendar.isDate($0.day, inSameDayAs: day) }) {
            log = existing
        } else {
            log = DayLogRecord(day: day)
            context.insert(log)
        }
        withAnimation(Theme.springy) {
            var current = log.adjustments
            if current.contains(adjustment) {
                current.remove(adjustment)
            } else {
                current.insert(adjustment)
            }
            log.adjustments = current
        }
    }
}

#Preview {
    RootView()
        .modelContainer(AppContainer.preview)
}
