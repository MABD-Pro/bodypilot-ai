import BodyPilotCore
import Charts
import Coach
import ProgressInsights
import SwiftData
import SwiftUI

/// « Mes 7 derniers jours » : calories, nutriments et activité jour par jour, ce qui a été bien
/// fait, et quoi faire pour le reste de la journée et de la semaine.
struct WeekReviewView: View {
    let profileRecord: ProfileRecord
    /// Ce que l'écran Aujourd'hui sait du jour. Une référence, pas des valeurs : la destination de
    /// navigation reste identique d'un rendu à l'autre de l'écran Aujourd'hui.
    let context: WeekReviewContext

    private var todayPlan: TodayPlan? { context.today?.plan }
    private var workoutDone: Bool { context.today?.workoutDone ?? false }
    private var healthActivities: [ActivitySample] { context.today?.healthActivities ?? [] }
    private var compositions: [BodyCompositionEntry] { context.today?.compositions ?? [] }
    private var dailySteps: [DailySteps] { context.today?.dailySteps ?? [] }
    private var stepsGoal: Int? { context.today?.stepsGoal }

    @Query(sort: \WeightRecord.date) private var weights: [WeightRecord]
    /// Sans filtre #Predicate : un prédicat recréé à chaque init rend la vue « différente » pour SwiftUI,
    /// et la destination de navigation se reconstruisait sans fin (écran figé au premier affichage).
    @Query(sort: \WaistRecord.date) private var allWaists: [WaistRecord]
    private var waists: [WaistRecord] { allWaists.filter { !$0.isScan } }
    @Query private var dayLogs: [DayLogRecord]
    @Query(sort: \WeekFeelingRecord.weekStart) private var weekFeelings: [WeekFeelingRecord]
    @Environment(\.modelContext) private var modelContext
    /// Bilan calculé une fois à l'ouverture (6 journées rejouées), puis seulement si les données changent.
    @State private var computed: Computed?

    private let calendar = Calendar.current

    /// Ressenti de la semaine du calendrier en cours (démo : `-demoFeeling hard:hunger,time`).
    private var feelingRecord: WeekFeelingRecord? {
        weekFeelings.last { calendar.isDate($0.weekStart, equalTo: .now, toGranularity: .weekOfYear) }
    }

    private var feeling: WeekFeeling? {
        feelingRecord?.feeling ?? LaunchOptions.demoFeeling
    }

    /// Semaine vécue comme difficile, ou motivation en berne : le minimum plutôt que tout le plan.
    private var offersFloorWeek: Bool {
        guard let feeling, !profileRecord.profile.isOnFloorWeek(on: .now) else { return false }
        return feeling.mood == .hard || feeling.obstacles.contains(.motivation)
    }

    private var floorWeekAction: (() -> Void)? {
        offersFloorWeek ? { startFloorWeek() } : nil
    }

    private func startFloorWeek() {
        withAnimation(Theme.springy) { profileRecord.startFloorWeek(on: .now, calendar: calendar) }
        try? modelContext.save()
        Telemetry.record(.floorWeekStarted)
    }

    private func saveFeeling(_ feeling: WeekFeeling) {
        if let feelingRecord {
            feelingRecord.feeling = feeling
        } else {
            modelContext.insert(WeekFeelingRecord(weekStart: calendar.storedDay(for: .now), feeling: feeling))
            Telemetry.record(.weekFeelingSaved)
        }
        try? modelContext.save()
    }

    /// Bilan et repas de chaque jour, calculés une seule fois par affichage.
    private struct Computed {
        var review: WeekReview
        var meals: [Date: DayMealPlan]
    }

    /// Ce qui oblige à refaire le bilan : un repas, une séance, une pesée, une donnée de Santé.
    private struct Inputs: Equatable {
        /// Repas notés et objectif du jour, en entiers : une comparaison toujours stable.
        var eatenKcal: Int
        var targetKcal: Int
        var workoutDone: Bool
        var logs: Int
        /// Repas notés des journaux, jour par jour : un repas corrigé un jour passé refait le bilan.
        var meals: [MealsNoted]
        var weights: Int
        var activities: Int
        var steps: Int
    }

    private var inputs: Inputs {
        Inputs(
            eatenKcal: Self.whole(todayPlan?.meals.eatenTotals.kcal ?? 0), targetKcal: Self.whole(todayPlan?.targets.macros.kcal ?? 0),
            workoutDone: workoutDone, logs: dayLogs.count,
            meals: dayLogs.sorted { $0.day < $1.day }.suffix(WeekReviewer.days + 1).map { MealsNoted(intakes: $0.mealIntakesRaw, described: $0.describedMealsData) },
            weights: weights.count, activities: healthActivities.count, steps: dailySteps.count)
    }

    struct MealsNoted: Equatable {
        var intakes: [String]
        var described: Data?
    }

    private static func whole(_ value: Double) -> Int {
        value.isFinite ? Int(value.rounded()) : 0
    }

    private func compute(today todayPlan: TodayPlan) -> Computed {
        let now = Date.now
        let profile = profileRecord.profile
        let completed = dayLogs.filter(\.workoutDone).map { (day: $0.day, title: $0.doneWorkoutTitle) }
        let intakes = dayLogs.compactMap { log in log.eatenKcal.map { IntakeDay(day: log.day, kcal: $0) } }
        var inputs: [ReviewDayInput] = []
        var meals: [Date: DayMealPlan] = [:]
        for offset in 0..<WeekReviewer.days {
            guard let date = calendar.date(byAdding: .day, value: offset - (WeekReviewer.days - 1), to: now) else { continue }
            let day = calendar.startOfDay(for: date)
            let isToday = offset == WeekReviewer.days - 1
            // Aujourd'hui : le plan affiché. Avant : la journée rejouée avec ses repas notés.
            let plan = isToday ? todayPlan : DayReplay.plan(
                on: calendar.storedDay(for: day),
                log: dayLogs.first { calendar.isDate($0.day, inSameDayAs: day) },
                profile: profile,
                weights: weights.map(\.entry), waists: waists.map(\.entry), compositions: compositions,
                intakes: intakes, samples: healthActivities, completed: completed, dailySteps: dailySteps,
                calendar: calendar
            )
            meals[day] = plan.meals
            inputs.append(ReviewDayInput(
                day: day,
                target: plan.targets.macros,
                eaten: plan.meals.eatenTotals,
                mealsNoted: plan.meals.meals.filter(\.isEaten).count,
                mealsPlanned: plan.meals.meals.count,
                steps: dailySteps.first { calendar.isDate($0.day, inSameDayAs: day) }?.steps
            ))
        }
        let today = ReviewToday(
            meals: todayPlan.meals,
            target: todayPlan.targets.macros,
            training: todayPlan.training,
            workoutDone: workoutDone,
            steps: dailySteps.first { calendar.isDateInToday($0.day) }?.steps,
            stepsGoal: stepsGoal
        )
        let review = WeekReviewer(calendar: calendar).review(
            days: inputs, samples: healthActivities, completed: completed,
            sessionMinutes: profile.sessionMinutes, today: today, on: now
        )
        return Computed(review: review, meals: meals)
    }

    var body: some View {
        Group {
            if let computed, LaunchOptions.demoReview == "jour", let yesterday = computed.review.days.dropLast().last {
                // Capture de démonstration : le détail de la veille.
                DayReviewView(day: yesterday, meals: computed.meals[yesterday.day], context: context)
            } else if let computed {
                content(computed)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background { AppBackground() }
        .navigationTitle("Mes 7 derniers jours")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: inputs) {
            guard let todayPlan else { return }
            computed = compute(today: todayPlan)
        }
    }

    private func content(_ computed: Computed) -> some View {
        let review = computed.review
        return ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    coachCard(review, headline: WeekReviewer(calendar: calendar).headline(review, feeling: feeling))
                    WeekFeelingCard(feeling: feeling, save: saveFeeling)
                        .id("feeling")
                    WeekPrioritiesCard(
                        priorities: WeekReviewer(calendar: calendar).priorities(review, feeling: feeling),
                        fromFeeling: feeling != nil,
                        startFloorWeek: floorWeekAction
                    )
                    adviceCard(title: "Pour le reste de la journée", symbol: "sun.max.fill", tint: Theme.nutrition, advice: review.restOfDay)
                    caloriesCard(review)
                        .id("calories")
                    activityCard(review)
                        .id("activity")
                    daysCard(computed)
                        .id("days")
                    Text("Les objectifs des jours passés sont recalculés avec ton profil actuel. Un repas noté d'une touche est une estimation ; un repas décrit est plus précis.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, Theme.Spacing.s)
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.bottom, Theme.Spacing.xxl)
            }
            .scrollIndicators(.hidden)
            .task {
                // Capture de démonstration : `-demoScrollTo calories`, `activity` ou `days`.
                guard let target = LaunchOptions.demoScrollTarget else { return }
                try? await Task.sleep(for: .seconds(1))
                withAnimation { proxy.scrollTo(target, anchor: .top) }
            }
        }
    }

    // MARK: - Le mot du coach

    private func coachCard(_ review: WeekReview, headline: String) -> some View {
        CoachCard(eyebrow: "Le mot du coach", symbol: "sparkles", tint: Theme.progress) {
            Text(headline)
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            if !review.wins.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    ForEach(review.wins, id: \.self) { win in
                        Label {
                            Text(win)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(Theme.progress)
                        }
                    }
                }
            }
        }
    }

    private func adviceCard(title: String, symbol: String, tint: Color, advice: [String]) -> some View {
        CoachCard(eyebrow: title, symbol: symbol, tint: tint) {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                ForEach(advice, id: \.self) { line in
                    CoachNote(text: line, tint: tint)
                }
            }
        }
    }

    // MARK: - Calories et nutriments

    private func caloriesCard(_ review: WeekReview) -> some View {
        CoachCard(eyebrow: "Calories et nutriments", symbol: "fork.knife", tint: Theme.nutrition) {
            if let eaten = review.averageEaten, let target = review.averageTarget {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                    Text(eaten.kcal.frenchInteger)
                        .font(.display(40))
                        .monospacedDigit()
                    Text("kcal/jour")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Tag(text: "objectif \(target.kcal.frenchInteger)", tint: Theme.nutrition)
                }
                Text("Moyenne des \(review.completeDays) journée\(review.completeDays > 1 ? "s" : "") où tous les repas sont notés.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                NutrientGauges(eaten: eaten, target: target)
            } else {
                Text("Aucune journée avec tous ses repas notés")
                    .font(.headline)
                Text("Note tes 4 repas d'une touche : la moyenne de la semaine apparaîtra ici.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Chart {
                ForEach(review.days) { day in
                    BarMark(x: .value("Jour", day.day, unit: .day), y: .value("Mangé", day.eaten.kcal))
                        .foregroundStyle(Theme.nutrition.opacity(day.isComplete ? 1 : 0.35))
                        .cornerRadius(5)
                    LineMark(x: .value("Jour", day.day, unit: .day), y: .value("Objectif", day.target.kcal))
                        .foregroundStyle(Color.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                }
            }
            .chartXAxis { weekdayAxis }
            .frame(height: 150)
            .accessibilityLabel("Calories mangées par jour, comparées à l'objectif")
            legend([(Theme.nutrition, "Journée complète"), (Theme.nutrition.opacity(0.35), "Repas en partie notés")], dashed: "Objectif")
        }
    }

    // MARK: - Activité

    private func activityCard(_ review: WeekReview) -> some View {
        CoachCard(eyebrow: "Activité", symbol: "figure.run", tint: Theme.training) {
            HStack(alignment: .top) {
                stat("\(review.sessions)", label: review.sessions > 1 ? "séances" : "séance")
                stat("\(review.strengthSessions)", label: "de force")
                stat(WeekActivityAnalyzer.duration(review.activeMinutes), label: "bougées")
                if let steps = review.averageSteps {
                    stat(StepActivity.displayed(steps).frenchInteger, label: "pas/jour")
                }
            }
            Chart {
                ForEach(review.days) { day in
                    ForEach(day.activities) { activity in
                        BarMark(x: .value("Jour", day.day, unit: .day), y: .value("Minutes", activity.minutes))
                            .foregroundStyle(by: .value("Type", activity.kind == .strength ? "Force" : "Endurance et autres"))
                            .cornerRadius(4)
                    }
                }
            }
            .chartForegroundStyleScale(["Force": Theme.training, "Endurance et autres": Theme.progress])
            .chartXScale(domain: (review.days.first?.day ?? .now)...(calendar.date(byAdding: .day, value: 1, to: review.days.last?.day ?? .now) ?? .now))
            .chartXAxis { weekdayAxis }
            .chartLegend(position: .bottom, alignment: .leading)
            .frame(height: 150)
            .accessibilityLabel("Minutes d'activité par jour")
        }
    }

    private func stat(_ value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.display(22, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Jour par jour

    private func daysCard(_ computed: Computed) -> some View {
        let review = computed.review
        return CoachCard(eyebrow: "Jour par jour", symbol: "list.bullet", tint: Theme.progress) {
            VStack(spacing: Theme.Spacing.s) {
                ForEach(review.days.reversed()) { day in
                    NavigationLink {
                        DayReviewView(day: day, meals: computed.meals[day.day], context: context)
                    } label: {
                        HStack(spacing: Theme.Spacing.m) {
                            Image(systemName: day.statusSymbol)
                                .font(.title3)
                                .foregroundStyle(day.statusTint)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ReviewDates.label(day.day, calendar: calendar))
                                    .font(.subheadline.weight(.semibold))
                                Text(day.summary)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: Theme.Spacing.s)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(Theme.Spacing.m)
                        .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: Theme.Radius.inner))
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Éléments communs

    private var weekdayAxis: some AxisContent {
        AxisMarks(values: .stride(by: .day)) { value in
            AxisValueLabel {
                if let date = value.as(Date.self) {
                    Text(date.formatted(.dateTime.weekday(.narrow).locale(Theme.locale)))
                }
            }
        }
    }

    private func legend(_ items: [(Color, String)], dashed: String) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            ForEach(items.indices, id: \.self) { index in
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2).fill(items[index].0).frame(width: 10, height: 10)
                    Text(items[index].1)
                }
            }
            HStack(spacing: 4) {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0.75))
                    path.addLine(to: CGPoint(x: 12, y: 0.75))
                }
                .stroke(.secondary, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .frame(width: 12, height: 1.5)
                Text(dashed)
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
}

/// Ce que l'écran Aujourd'hui transmet au bilan, mis à jour quand le jour change.
struct WeekReviewToday: Equatable {
    var plan: TodayPlan
    var workoutDone: Bool
    var healthActivities: [ActivitySample]
    var compositions: [BodyCompositionEntry]
    var dailySteps: [DailySteps]
    var stepsGoal: Int?
}

@MainActor
@Observable
final class WeekReviewContext {
    var today: WeekReviewToday?
}

/// Le détail d'une journée : le mot du coach, les repas notés et l'activité.
struct DayReviewView: View {
    let day: ReviewDay
    let meals: DayMealPlan?
    /// Données de Santé lues par l'écran Aujourd'hui, pour corriger les repas d'un jour passé.
    var context: WeekReviewContext?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                CoachCard(eyebrow: "Le mot du coach", symbol: "sparkles", tint: Theme.progress) {
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                        Image(systemName: day.statusSymbol)
                            .foregroundStyle(day.statusTint)
                        Text(day.comment)
                            .font(.headline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                nutrition
                activity
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .scrollIndicators(.hidden)
        .background { AppBackground() }
        .navigationTitle(ReviewDates.label(day.day))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var nutrition: some View {
        CoachCard(eyebrow: "Manger", symbol: "fork.knife", tint: Theme.nutrition) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                Text(day.eaten.kcal.frenchInteger)
                    .font(.display(40))
                    .monospacedDigit()
                Text("/ \(day.target.kcal.frenchInteger) kcal")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                Tag(text: "\(day.mealsNoted) repas sur \(day.mealsPlanned)", tint: Theme.nutrition)
            }
            NutrientGauges(eaten: day.eaten, target: day.target)
            if !Calendar.current.isDateInToday(day.day) {
                NavigationLink {
                    PastDayMealsView(
                        day: day.day,
                        healthActivities: context?.today?.healthActivities ?? [],
                        compositions: context?.today?.compositions ?? [],
                        dailySteps: context?.today?.dailySteps ?? []
                    )
                } label: {
                    Label("Modifier les repas", systemImage: "square.and.pencil")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.nutrition)
                }
                .buttonStyle(.plain)
            }
            if let meals {
                VStack(spacing: Theme.Spacing.s) {
                    ForEach(meals.meals, id: \.slot) { meal in
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            HStack(spacing: Theme.Spacing.m) {
                                IconBadge(symbol: meal.slot.symbol, tint: meal.isEaten ? meal.slot.tint : .secondary, size: 34)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(meal.slot.title)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    Text(meal.isEaten ? (meal.described?.title ?? meal.title) : "Non noté")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(meal.isEaten ? .primary : .secondary)
                                    if meal.described == nil, let intake = meal.intake {
                                        Text(intake.label)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer(minLength: Theme.Spacing.s)
                                if meal.isEaten {
                                    Text("\(meal.macros.kcal.frenchInteger) kcal")
                                        .font(.subheadline.weight(.semibold))
                                        .monospacedDigit()
                                }
                            }
                            // Sous le nom, sur toute la largeur : à côté des kcal, les quatre colonnes étaient tronquées.
                            if meal.isEaten {
                                NutrientBreakdown(macros: meal.macros, approximate: true)
                                    .padding(.leading, 34 + Theme.Spacing.m)
                            }
                        }
                    }
                }
            }
        }
    }

    private var activity: some View {
        CoachCard(eyebrow: "Bouger", symbol: "figure.run", tint: Theme.training) {
            if day.activities.isEmpty {
                Text("Pas de séance enregistrée ce jour-là.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(day.activities) { activity in
                    HStack(spacing: Theme.Spacing.m) {
                        IconBadge(symbol: activity.kind.symbol, tint: activity.kind == .strength ? Theme.training : Theme.progress, size: 34)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(activity.title)
                                .font(.subheadline.weight(.semibold))
                            Text(activity.fromHealth ? "Santé" : "Cochée dans BodyPilot")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: Theme.Spacing.s)
                        Text([
                            WeekActivityAnalyzer.duration(activity.minutes),
                            activity.kcal.map { "\($0.frenchInteger) kcal" },
                        ].compactMap { $0 }.joined(separator: " · "))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    }
                }
            }
            if let steps = day.steps, steps > 0 {
                Label("\(Double(steps).frenchInteger) pas", systemImage: "shoeprints.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.training)
            }
        }
    }
}

/// Une journée passée rejouée : objectifs recalculés avec le profil actuel, repas notés ce jour-là.
@MainActor
enum DayReplay {
    static func plan(
        on day: Date,
        log: DayLogRecord?,
        profile: UserProfile,
        weights: [WeightEntry],
        waists: [WaistEntry],
        compositions: [BodyCompositionEntry],
        intakes: [IntakeDay],
        samples: [ActivitySample],
        completed: [(day: Date, title: String?)],
        dailySteps: [DailySteps],
        calendar: Calendar
    ) -> TodayPlan {
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: day)) ?? day
        let pastWeights = weights.filter { $0.date < end }
        let exerciseKcal = ExerciseEnergy.dailyAverage(
            samples: samples, completed: completed, sessionMinutes: profile.sessionMinutes,
            weightKg: pastWeights.last?.kg ?? profile.startWeightKg, on: day, calendar: calendar
        )
        return CoachFactory.coach.plan(
            for: profile,
            weights: pastWeights,
            waists: waists.filter { $0.date < end },
            compositions: compositions.filter { $0.date < end },
            adjustments: log?.adjustments ?? [],
            availableMinutes: log?.availableMinutes,
            eatingOutSlot: log?.eatingOutSlot,
            mealIntakes: log?.mealIntakes ?? [:],
            describedMeals: log?.describedMeals ?? [:],
            exerciseKcalPerDay: exerciseKcal,
            averageDailySteps: StepActivity.average(dailySteps, excluding: samples, before: day, calendar: calendar),
            measuredExpenditure: EnergyBalance.measured(intakes: intakes, weights: pastWeights, on: day, calendar: calendar),
            on: day
        )
    }
}

enum ReviewDates {
    /// « Aujourd'hui », « Hier », « mar. 27 oct. ».
    static func label(_ date: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) { return "Aujourd'hui" }
        if calendar.isDateInYesterday(date) { return "Hier" }
        return date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated).locale(Theme.locale)).capitalizedFirst
    }
}

private extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}

extension ReviewDay {
    /// Pastille de la journée : dans la cible, à côté, ou pas assez notée pour juger.
    var statusSymbol: String {
        switch kcalStatus {
        case .onTarget: proteinReached == true ? "checkmark.circle.fill" : "checkmark.circle"
        case .over: "arrow.up.circle.fill"
        case .under: "arrow.down.circle.fill"
        case nil: mealsNoted == 0 ? "circle.dashed" : "circle.lefthalf.filled"
        }
    }

    var statusTint: Color {
        switch kcalStatus {
        case .onTarget: Theme.progress
        case .over: Theme.carbs
        case .under: Theme.protein
        case nil: .secondary
        }
    }
}
