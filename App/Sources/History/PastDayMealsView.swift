import BodyPilotCore
import Coach
import Nutrition
import ProgressInsights
import SwiftData
import SwiftUI

/// Les repas d'un jour passé, à corriger comme ceux du jour : pris d'une touche, décrits, repris
/// ou annulés. Les calories de la journée (mesure de la dépense), le bilan et Santé suivent.
struct PastDayMealsView: View {
    let day: Date
    /// Ce que l'écran Aujourd'hui a lu dans Santé : l'objectif du jour est rejoué comme dans le bilan.
    var healthActivities: [ActivitySample] = []
    var compositions: [BodyCompositionEntry] = []
    var dailySteps: [DailySteps] = []

    @Environment(\.modelContext) private var context
    @AppStorage("healthWeightSync") private var healthSync = false
    // Sans filtre #Predicate : un prédicat recréé à chaque init reconstruit sans fin une destination de navigation.
    @Query(sort: \ProfileRecord.createdAt) private var profiles: [ProfileRecord]
    @Query(sort: \WeightRecord.date) private var weights: [WeightRecord]
    @Query(sort: \WaistRecord.date) private var allWaists: [WaistRecord]
    @Query private var dayLogs: [DayLogRecord]
    @State private var describing: PastMealToDescribe?

    private let calendar = Calendar.current

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                if let profile = profiles.first {
                    let plan = replay(profile.profile, log: log)
                    NutritionCard(
                        targets: plan.targets,
                        meals: plan.meals,
                        logIntake: logIntake,
                        describe: { slot in describing = PastMealToDescribe(slot: slot, current: log?.describedMeals[slot]) },
                        recent: { slot in RecentMeals.list(for: slot, history: recentMealHistory, today: tomorrow, calendar: calendar) },
                        reuse: { slot, meal in saveDescribed(meal, for: slot) },
                        pastDay: true
                    )
                    Text("L'objectif de ce jour est recalculé avec ton profil actuel. Tes corrections comptent dans le bilan des 7 derniers jours et dans la mesure de ta dépense.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, Theme.Spacing.s)
                }
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .scrollIndicators(.hidden)
        .background { AppBackground() }
        .navigationTitle(ReviewDates.label(day, calendar: calendar))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $describing) { item in
            MealDescriptionSheet(slot: item.slot, initial: item.current) { meal in
                saveDescribed(meal, for: item.slot)
            }
        }
    }

    private var log: DayLogRecord? {
        dayLogs.first { calendar.isDate($0.day, inSameDayAs: day) }
    }

    /// Le journal du jour, créé à la première correction d'un jour sans rien de noté.
    private func editableLog() -> DayLogRecord {
        if let log { return log }
        let created = DayLogRecord(day: calendar.storedDay(for: day))
        context.insert(created)
        return created
    }

    private var tomorrow: Date {
        calendar.date(byAdding: .day, value: 1, to: .now) ?? .now
    }

    /// Repas décrits des 7 derniers jours, à reprendre ; ceux du jour corrigé n'y sont pas.
    private var recentMealHistory: [(day: Date, meals: [MealSlot: DescribedMeal])] {
        dayLogs
            .filter { $0.describedMealsData != nil && !calendar.isDate($0.day, inSameDayAs: day) }
            .map { (day: $0.day, meals: $0.describedMeals) }
    }

    /// La journée rejouée comme dans « Mes 7 derniers jours ».
    private func replay(_ profile: UserProfile, log: DayLogRecord?) -> TodayPlan {
        DayReplay.plan(
            on: calendar.storedDay(for: day),
            log: log,
            profile: profile,
            weights: weights.map(\.entry),
            waists: allWaists.filter { !$0.isScan }.map(\.entry),
            compositions: compositions,
            intakes: dayLogs.compactMap { log in log.eatenKcal.map { IntakeDay(day: log.day, kcal: $0) } },
            samples: healthActivities,
            completed: dayLogs.filter(\.workoutDone).map { (day: $0.day, title: $0.doneWorkoutTitle) },
            dailySteps: dailySteps,
            calendar: calendar
        )
    }

    /// Repas pris : `nil` annule la saisie (et le repas décrit).
    private func logIntake(_ slot: MealSlot, _ intake: MealIntake?) {
        edit { log in
            log.mealIntakes[slot] = intake
            if intake == nil { log.describedMeals[slot] = nil }
        }
    }

    /// Repas décrit en texte : il remplace la saisie d'une touche pour ce repas.
    private func saveDescribed(_ meal: DescribedMeal, for slot: MealSlot) {
        edit { log in
            log.describedMeals[slot] = meal
            log.mealIntakes[slot] = nil
        }
        Telemetry.record(.mealDescribed)
    }

    /// Applique la correction, puis remet à jour ce qui en dépend : les calories de la journée
    /// complète (mesure de la dépense, donc les objectifs des jours suivants) et Santé.
    /// Seule une correction écrit : ouvrir un jour passé ne change rien.
    private func edit(_ change: (DayLogRecord) -> Void) {
        guard let profile = profiles.first else { return }
        let record = editableLog()
        withAnimation(Theme.springy) { change(record) }
        let meals = replay(profile.profile, log: record).meals
        let kcal = meals.meals.allSatisfy(\.isEaten) ? meals.eatenTotals.kcal.rounded() : nil
        if record.eatenKcal != kcal { record.eatenKcal = kcal }
        try? context.save()
        Task { await exportMeals(meals) }
    }

    /// Repas mangés de ce jour → Santé ; un repas annulé ou sauté en est retiré.
    private func exportMeals(_ meals: DayMealPlan) async {
        guard healthSync, HealthWeight.isAvailable, !LaunchOptions.demoData else { return }
        let export = HealthMealExport(calendar: calendar)
        await HealthMeals.shared.sync(
            export.entries(for: meals, on: day, now: .now),
            ids: MealSlot.allCases.map { export.id(for: $0, on: day) }
        )
    }
}

/// Repas d'un jour passé en cours de description.
private struct PastMealToDescribe: Identifiable {
    let slot: MealSlot
    let current: DescribedMeal?
    var id: String { slot.rawValue }
}

/// Choix d'un jour passé à compléter, même sans aucun repas noté.
struct PastDayPicker: View {
    let open: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var day = Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now

    private var yesterday: Date {
        Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.l) {
                DatePicker("Jour", selection: $day, in: ...yesterday, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .environment(\.locale, Theme.locale)
                    .tint(Theme.nutrition)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.Spacing.l)
            .navigationTitle("Un jour passé")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ouvrir") {
                        open(day)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
