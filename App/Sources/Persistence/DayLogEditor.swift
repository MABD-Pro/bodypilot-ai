import BodyPilotCore
import Coach
import Foundation
import SwiftData

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

    static func weekPlan(containing date: Date, in context: ModelContext, calendar: Calendar = .current) -> WeekPlanRecord? {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: date) else { return nil }
        let start = week.start
        let end = week.end
        var descriptor = FetchDescriptor<WeekPlanRecord>(predicate: #Predicate { $0.weekStart >= start && $0.weekStart < end })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// Jours de séance de la semaine : ceux choisis pour cette semaine, sinon les jours habituels.
    static func trainingDays(week: WeekPlanRecord?, profile: UserProfile) -> [Int] {
        week?.weekdaysRaw ?? profile.trainingWeekdays
    }

    /// Ajoute ou retire un jour de séance pour cette semaine seulement.
    static func toggleTrainingDay(_ weekday: Int, on date: Date, profile: UserProfile, in context: ModelContext, calendar: Calendar = .current) {
        let week = weekPlan(containing: date, in: context, calendar: calendar) ?? {
            let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
            let created = WeekPlanRecord(weekStart: start, weekdays: profile.trainingWeekdays)
            context.insert(created)
            return created
        }()
        var days = Set(week.weekdaysRaw)
        if days.contains(weekday) { days.remove(weekday) } else { days.insert(weekday) }
        week.weekdaysRaw = days.sorted()
        // Sans sauvegarde, la vue ne voit pas tout de suite une semaine tout juste créée.
        try? context.save()
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
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now).flatMap { log(on: $0, in: context, calendar: calendar) }
        let week = weekPlan(containing: now, in: context, calendar: calendar)
        return CoachFactory.coach.plan(
            for: profile.profile,
            weights: weights.map(\.entry),
            waists: waists.map(\.entry),
            adjustments: today?.adjustments ?? [],
            availableMinutes: today?.availableMinutes,
            eatingOutSlot: today?.eatingOutSlot,
            yesterdayAdjustments: yesterday?.adjustments ?? [],
            exerciseSwaps: today?.exerciseSwaps ?? [:],
            weekTrainingDays: week?.weekdaysRaw,
            mealIntakes: today?.mealIntakes ?? [:],
            describedMeals: today?.describedMeals ?? [:],
            on: now
        )
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
