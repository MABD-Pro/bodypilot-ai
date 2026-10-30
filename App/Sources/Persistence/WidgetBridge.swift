import BodyPilotCore
import Coach
import Foundation
import SwiftData
import WidgetKit

/// Lien entre l'app et ses widgets : l'app publie le résumé du jour et applique ce qui a été
/// coché depuis l'écran d'accueil ou le Centre de contrôle.
@MainActor
enum WidgetBridge {
    /// Résumé de la journée affichée. Le jour est arrondi au matin : le résumé ne change
    /// qu'avec le plan, pas à chaque seconde.
    static func snapshot(plan: TodayPlan, training: TrainingDay, workoutDone: Bool, now: Date, calendar: Calendar = .current) -> TodaySnapshot {
        let activity: (title: String?, line: String, symbol: String) = switch training.kind {
        case .workout(let workout): (workout.title, "\(workout.title) · \(training.estimatedMinutes) min", "dumbbell.fill")
        case .activeRest(let title, let minutes): (title, "\(title) · \(minutes) min", "figure.walk")
        case .rest: (nil, "Repos", "bed.double.fill")
        }
        let targets = plan.targets.macros
        let eaten = plan.meals.eatenTotals
        return TodaySnapshot(
            day: calendar.startOfDay(for: now),
            workoutTitle: activity.title,
            trainingLine: activity.line,
            trainingSymbol: activity.symbol,
            workoutDone: workoutDone,
            kcalTarget: Int(targets.kcal.rounded()),
            kcalEaten: Int(eaten.kcal.rounded()),
            proteinTarget: Int(targets.proteinG.rounded()),
            proteinEaten: Int(eaten.proteinG.rounded()),
            meals: plan.meals.meals.map { meal in
                TodaySnapshot.Meal(
                    slot: meal.slot.rawValue, name: meal.slot.title, symbol: meal.slot.symbol,
                    kcal: Int(meal.macros.kcal.rounded()), eaten: meal.isEaten
                )
            }
        )
    }

    static func publish(_ snapshot: TodaySnapshot) {
        // La démo des captures ne doit pas remplacer la vraie journée dans les widgets.
        guard !LaunchOptions.demoData, SharedStore.save(snapshot) else { return }
        WidgetBridgeReload.all()
    }

    /// Ce qui a été coché hors de l'app, appliqué une fois : un repas déjà noté (ou décrit) et une
    /// séance déjà cochée restent tels quels. Une action d'un autre jour est ignorée.
    static func applyPending(in context: ModelContext, now: Date = .now, calendar: Calendar = .current) {
        let actions = SharedStore.takePendingActions()
        guard !actions.isEmpty else { return }
        for action in actions {
            switch action {
            case .mealTaken(let raw, let day):
                guard calendar.isDate(day, inSameDayAs: now), let slot = MealSlot(rawValue: raw) else { continue }
                let log = DayLogEditor.todayLog(in: context, calendar: calendar)
                if log.mealIntakes[slot] == nil, log.describedMeals[slot] == nil {
                    log.mealIntakes[slot] = .asPlanned
                }
            case .workoutDone(let day):
                guard calendar.isDate(day, inSameDayAs: now) else { continue }
                let log = DayLogEditor.todayLog(in: context, calendar: calendar)
                if !log.workoutDone {
                    log.workoutDone = true
                    log.doneWorkoutTitle = DisplayedWorkout.title(on: now, calendar: calendar) ?? nil
                }
            }
        }
        do {
            try context.save()
        } catch {
            AppLog.persistence.error("Actions des widgets non enregistrées : \(error.localizedDescription, privacy: .public)")
        }
    }
}
