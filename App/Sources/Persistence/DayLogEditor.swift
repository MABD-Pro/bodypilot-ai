import BodyPilotCore
import Coach
import Foundation
import Nutrition
import ProgressInsights
import SwiftData
import Training

/// Lecture et mise à jour du journal du jour, partagées par l'écran Aujourd'hui, Siri et Raccourcis.
@MainActor
enum DayLogEditor {
    static func log(on date: Date, in context: ModelContext, calendar: Calendar = .current) -> DayLogRecord? {
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
        var descriptor = FetchDescriptor<DayLogRecord>(predicate: #Predicate { $0.day >= start && $0.day < end })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    static func todayLog(in context: ModelContext, calendar: Calendar = .current) -> DayLogRecord {
        if let existing = log(on: .now, in: context, calendar: calendar) { return existing }
        let created = DayLogRecord(day: calendar.storedDay(for: .now))
        context.insert(created)
        return created
    }

    /// Ajoute ce qui a été compris, sans retirer les ajustements déjà choisis.
    static func apply(_ command: InterpretedCommand, to log: DayLogRecord) {
        log.adjustments = log.adjustments.union(command.adjustments)
        if let minutes = command.availableMinutes {
            log.availableMinutes = minutes
        }
        if let slot = command.eatingOutSlot {
            log.eatingOutSlot = slot
        } else if command.adjustments.contains(.eatingOut), log.eatingOutSlot == nil {
            log.eatingOutSlot = MealConstraints.nextMainMeal(at: .now, calendar: .current)
        }
    }

    /// Repas décrits des `days` derniers jours, pour les habitudes et les portions habituelles.
    static func mealHistory(_ logs: [DayLogRecord], days: Int, now: Date, calendar: Calendar = .current) -> [(day: Date, meals: [MealSlot: DescribedMeal])] {
        guard let since = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: now)) else { return [] }
        return logs
            .filter { $0.day >= since && $0.describedMealsData != nil }
            .map { (day: $0.day, meals: $0.describedMeals) }
    }

    static func mealHistory(in context: ModelContext, days: Int, now: Date, calendar: Calendar = .current) -> [(day: Date, meals: [MealSlot: DescribedMeal])] {
        guard let since = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: now)) else { return [] }
        let logs = (try? context.fetch(FetchDescriptor<DayLogRecord>(predicate: #Predicate { $0.day >= since }))) ?? []
        return mealHistory(logs, days: days, now: now, calendar: calendar)
    }

    /// Plan du jour calculé depuis la base, hors de toute vue (Siri, Raccourcis).
    static func todayPlan(in context: ModelContext, calendar: Calendar = .current, now: Date = .now) -> TodayPlan? {
        let profiles = (try? context.fetch(FetchDescriptor<ProfileRecord>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        guard let profile = profiles.first else { return nil }
        let weights = (try? context.fetch(FetchDescriptor<WeightRecord>(sortBy: [SortDescriptor(\.date)]))) ?? []
        let waists = (try? context.fetch(FetchDescriptor<WaistRecord>(predicate: #Predicate { !$0.isScan }, sortBy: [SortDescriptor(\.date)]))) ?? []
        let today = log(on: now, in: context, calendar: calendar)
        let start = calendar.startOfDay(for: now)
        let done = (try? context.fetch(FetchDescriptor<DayLogRecord>(predicate: #Predicate { $0.workoutDone && $0.day < start }))) ?? []
        let lifts = (try? context.fetch(FetchDescriptor<LiftRecord>(predicate: #Predicate { $0.day < start }))) ?? []
        let cardioTests = (try? context.fetch(FetchDescriptor<CardioTestRecord>())) ?? []
        let last = lastStrength(before: now, completed: done.map { (day: $0.day, title: $0.doneWorkoutTitle) }, samples: [], calendar: calendar)
        let active = activeDays(before: now, completed: done.map { (day: $0.day, title: $0.doneWorkoutTitle) }, samples: [], calendar: calendar)
        return CoachFactory.coach.plan(
            for: profile.profile,
            weights: weights.map(\.entry),
            waists: waists.map(\.entry),
            adjustments: today?.adjustments ?? [],
            availableMinutes: today?.availableMinutes,
            eatingOutSlot: today?.eatingOutSlot,
            exerciseSwaps: today?.exerciseSwaps ?? [:],
            mealIntakes: today?.mealIntakes ?? [:],
            describedMeals: today?.describedMeals ?? [:],
            habitMeals: HabitMeals.usual(history: mealHistory(in: context, days: HabitMeals.windowDays, now: now, calendar: calendar), today: now, calendar: calendar),
            lastWorkoutTitle: last.title,
            lastStrengthDay: last.day,
            calibratedLifts: calibratedLifts(lifts.map(\.entry), before: now, since: profile.strengthTestResetAt, lastStrengthDay: last.day, calendar: calendar),
            activeDays: active,
            trainingChoice: today?.trainingChoice,
            cardio: cardioStatus(for: profile.profile, measures: cardioTests.map(\.measure), restingHeartRate: nil, on: now, calendar: calendar),
            exerciseKcalPerDay: ExerciseEnergy.dailyAverage(
                samples: [], completed: done.map { (day: $0.day, title: $0.doneWorkoutTitle) },
                sessionMinutes: profile.sessionMinutes, weightKg: weights.last?.kg ?? profile.startWeightKg, on: now, calendar: calendar
            ),
            cycle: profile.cycle,
            cycleWorkoutsThisWeek: profile.cycle?.workoutsThisWeek(done.map { (day: $0.day, title: $0.doneWorkoutTitle) }, on: now, calendar: calendar) ?? [],
            cycleSessionsPerWeek: profile.cycleSessions(
                on: now, recentAverage: CycleSessionPlan.recentAverage(doneDays: Array(active), before: now, calendar: calendar), calendar: calendar
            )?.sessions,
            on: now
        )
    }

    /// Jours avec une séance faite avant ce jour : cochée dans l'app, ou d'au moins 20 min dans Santé.
    nonisolated static func activeDays(
        before date: Date,
        completed: [(day: Date, title: String?)],
        samples: [ActivitySample],
        calendar: Calendar = .current
    ) -> Set<Date> {
        let start = calendar.startOfDay(for: date)
        let days = completed.map(\.day) + samples.filter { $0.minutes >= 20 }.map(\.start)
        return Set(days.map { calendar.startOfDay(for: $0) }.filter { $0 < start })
    }

    /// Forme cardio : test de marche à faire sans mesure de moins de 8 semaines avant ce jour
    /// (un test fait aujourd'hui reste affiché), zone de cardio modéré selon l'âge et le pouls au repos.
    nonisolated static func cardioStatus(for profile: UserProfile, measures: [CardioMeasure], restingHeartRate: Double?, on date: Date, calendar: Calendar = .current) -> CardioStatus {
        let start = calendar.startOfDay(for: date)
        let last = CardioTest.latest(measures.filter { $0.date < start })
        return CardioStatus(
            testDue: CardioTest.isDue(lastMeasured: last?.date, on: date, calendar: calendar),
            moderateHeartRate: CardioTest.moderateZone(age: profile.age(on: date, calendar: calendar), restingHeartRate: restingHeartRate)
        )
    }

    /// Exercices dont une charge est notée avant ce jour. Les séries du jour n'en font pas partie :
    /// un test en cours reste affiché jusqu'au bout. Après « Refaire le test de force », seules
    /// les charges notées depuis comptent. Après plus de 3 mois sans force (séries notées, séance
    /// cochée ou enregistrée dans Santé), le test revient : les anciennes charges ne disent plus grand-chose.
    nonisolated static func calibratedLifts(
        _ lifts: [LiftEntry],
        before date: Date,
        since reset: Date? = nil,
        lastStrengthDay: Date? = nil,
        calendar: Calendar = .current
    ) -> Set<String> {
        let start = calendar.startOfDay(for: date)
        let resetDay = reset.map { calendar.startOfDay(for: $0) } ?? .distantPast
        let earlier = lifts.filter { $0.date < start }
        if let pause = StrengthProgress.pauseDays(history: earlier, lastStrengthDay: lastStrengthDay, on: date, calendar: calendar),
           pause > StrengthProgress.retestAfterDays {
            return []
        }
        return Set(earlier.filter { $0.date >= resetDay && ($0.kg ?? 0) > 0 }.map(\.exercise))
    }

    /// Dernière séance de force avant ce jour : cochée dans l'app (son titre fixe la suivante, A puis B)
    /// ou enregistrée dans Santé (renforcement d'au moins 20 min, Watch ou autre app).
    nonisolated static func lastStrength(
        before date: Date,
        completed: [(day: Date, title: String?)],
        samples: [ActivitySample],
        calendar: Calendar = .current
    ) -> (day: Date?, title: String?) {
        let start = calendar.startOfDay(for: date)
        let logged = completed
            .filter { $0.day < start && $0.title.map(TrainingPlanner.isStrengthSession) == true }
            .max { $0.day < $1.day }
        let recorded = samples
            .filter { $0.kind == .strength && $0.minutes >= 20 && $0.start < start }
            .map { calendar.startOfDay(for: $0.start) }
            .max()
        let day = [logged.map { calendar.startOfDay(for: $0.day) }, recorded].compactMap { $0 }.max()
        return (day, logged?.title)
    }
}

extension InterpretedCommand {
    /// « 15 min, fatigue, restaurant » : ce que le coach a retenu, en clair.
    var summary: String {
        var parts = QuickAdjustment.allCases
            .filter { adjustments.contains($0) && !($0 == .shortOnTime && availableMinutes != nil) }
            .map(\.shortLabel)
        if let availableMinutes {
            parts.insert("\(availableMinutes) min", at: 0)
        }
        return parts.joined(separator: ", ")
    }
}

/// Séance affichée aujourd'hui sur l'écran Aujourd'hui. Siri coche celle que l'utilisateur a
/// vue : son propre calcul du plan ne connaît ni le sommeil, ni les séances de la Watch, et
/// pouvait proposer une autre séance.
enum DisplayedWorkout {
    private static func key(for date: Date, calendar: Calendar) -> String {
        let day = calendar.dateComponents([.year, .month, .day], from: date)
        return "displayedWorkout-\(day.year ?? 0)-\(day.month ?? 0)-\(day.day ?? 0)"
    }

    /// `nil` un jour sans séance (repos, marche), enregistré quand même : c'est ce qui est affiché.
    static func remember(_ title: String?, on date: Date, calendar: Calendar = .current, defaults: UserDefaults = .standard) {
        defaults.set(title ?? "", forKey: key(for: date, calendar: calendar))
    }

    /// La séance affichée ce jour-là, ou `.none` si l'écran ne l'a pas encore montrée.
    static func title(on date: Date, calendar: Calendar = .current, defaults: UserDefaults = .standard) -> String?? {
        guard let stored = defaults.string(forKey: key(for: date, calendar: calendar)) else { return .none }
        return .some(stored.isEmpty ? nil : stored)
    }
}
