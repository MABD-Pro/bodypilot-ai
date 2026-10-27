import BodyPilotCore
import Coach
import Foundation
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
        let created = DayLogRecord(day: calendar.startOfDay(for: .now))
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
        }
    }

    /// Plan du jour calculé depuis la base, hors de toute vue (Siri, Raccourcis).
    static func todayPlan(in context: ModelContext, calendar: Calendar = .current, now: Date = .now) -> TodayPlan? {
        let profiles = (try? context.fetch(FetchDescriptor<ProfileRecord>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        guard let profile = profiles.first else { return nil }
        let weights = (try? context.fetch(FetchDescriptor<WeightRecord>(sortBy: [SortDescriptor(\.date)]))) ?? []
        let waists = (try? context.fetch(FetchDescriptor<WaistRecord>(sortBy: [SortDescriptor(\.date)]))) ?? []
        let today = log(on: now, in: context, calendar: calendar)
        let start = calendar.startOfDay(for: now)
        let done = (try? context.fetch(FetchDescriptor<DayLogRecord>(predicate: #Predicate { $0.workoutDone && $0.day < start }))) ?? []
        let lifts = (try? context.fetch(FetchDescriptor<LiftRecord>(predicate: #Predicate { $0.day < start }))) ?? []
        let last = lastStrength(before: now, completed: done.map { (day: $0.day, title: $0.doneWorkoutTitle) }, samples: [], calendar: calendar)
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
            lastWorkoutTitle: last.title,
            lastStrengthDay: last.day,
            calibratedLifts: calibratedLifts(lifts.map(\.entry), before: now, calendar: calendar),
            activeDays: activeDays(before: now, completed: done.map { (day: $0.day, title: $0.doneWorkoutTitle) }, samples: [], calendar: calendar),
            trainingChoice: today?.trainingChoice,
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

    /// Exercices dont une charge est notée avant ce jour. Les séries du jour n'en font pas partie :
    /// un test en cours reste affiché jusqu'au bout.
    nonisolated static func calibratedLifts(_ lifts: [LiftEntry], before date: Date, calendar: Calendar = .current) -> Set<String> {
        let start = calendar.startOfDay(for: date)
        return Set(lifts.filter { $0.date < start && ($0.kg ?? 0) > 0 }.map(\.exercise))
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
