import BodyPilotCore
import Foundation

/// Planificateur de séances par règles : calendrier hebdomadaire fixe, séances alternées,
/// ajustements du jour (temps, fatigue, séance ratée) dans des limites de sécurité.
public struct TrainingPlanner: TrainingPlanning {
    public var calendar: Calendar

    /// En dessous, une séance n'a plus de sens : on propose de la marche.
    public static let minimumWorkoutMinutes = 12
    /// On garde au moins les exercices essentiels.
    static let minimumExercises = 3

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// Jours d'entraînement (1 = dimanche … 7 = samedi), répartis pour laisser des jours de récupération.
    public static func trainingWeekdays(daysPerWeek: Int) -> [Int] {
        switch min(max(daysPerWeek, 1), 6) {
        case 1: [4]
        case 2: [2, 5]
        case 3: [2, 4, 6]
        case 4: [2, 3, 5, 6]
        case 5: [2, 3, 4, 6, 7]
        default: [2, 3, 4, 5, 6, 7]
        }
    }

    public func isTrainingDay(_ date: Date, for profile: UserProfile) -> Bool {
        Self.trainingWeekdays(daysPerWeek: profile.trainingDaysPerWeek).contains(calendar.component(.weekday, from: date))
    }

    public func trainingDay(for profile: UserProfile, on date: Date, constraints: DayConstraints) -> TrainingDay {
        var notes: [String] = []
        let workout: Workout

        if isTrainingDay(date, for: profile) {
            if constraints.missedToday {
                let minutes = 15
                return TrainingDay(
                    kind: .activeRest(title: "Marche tranquille", minutes: minutes),
                    estimatedMinutes: minutes,
                    notes: ["Séance ratée : on ne la double pas. Si demain est un jour de repos, elle y sera proposée."]
                )
            }
            workout = scheduledWorkout(for: profile, on: date)
            if constraints.missedYesterday {
                notes.append("Séance d'hier non rattrapée : on ne fait jamais deux séances le même jour.")
            }
        } else {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: date) ?? date
            if constraints.missedYesterday && isTrainingDay(yesterday, for: profile) && !constraints.missedToday {
                workout = scheduledWorkout(for: profile, on: yesterday)
                notes.append("Rattrapage de la séance d'hier, puisque aujourd'hui est libre.")
            } else {
                return restDay(for: profile, constraints: constraints)
            }
        }

        var adapted = workout
        if constraints.lowEnergy {
            adapted = lighten(adapted)
            notes.append("Fatigue : une série de moins, pas d'impacts, effort modéré.")
        }

        let budget = min(constraints.availableMinutes ?? profile.sessionMinutes, profile.sessionMinutes)
        if budget < Self.minimumWorkoutMinutes {
            return TrainingDay(
                kind: .activeRest(title: "Marche rapide", minutes: max(budget, 10)),
                estimatedMinutes: max(budget, 10),
                notes: notes + ["Moins de \(Self.minimumWorkoutMinutes) minutes : une marche rapide vaut mieux qu'une séance bâclée."]
            )
        }
        if adapted.estimatedMinutes > budget {
            adapted = fit(adapted, toMinutes: budget)
            notes.append("Séance resserrée à \(adapted.estimatedMinutes) min : l'essentiel est gardé.")
        }
        return TrainingDay(kind: .workout(adapted), estimatedMinutes: adapted.estimatedMinutes, notes: notes)
    }

    func scheduledWorkout(for profile: UserProfile, on date: Date) -> Workout {
        let sessions = WorkoutCatalog.sessions(for: profile.equipment)
        let weekdays = Self.trainingWeekdays(daysPerWeek: profile.trainingDaysPerWeek)
        let position = weekdays.firstIndex(of: calendar.component(.weekday, from: date)) ?? 0
        let week = calendar.component(.weekOfYear, from: date)
        return sessions[(week * weekdays.count + position) % sessions.count]
    }

    private func restDay(for profile: UserProfile, constraints: DayConstraints) -> TrainingDay {
        let minutes = profile.goal == .loseFat && !constraints.lowEnergy ? 30 : 20
        let title = constraints.lowEnergy ? "Repos : marche tranquille" : "Repos actif : marche"
        let available = constraints.availableMinutes.map { min($0, minutes) } ?? minutes
        return TrainingDay(kind: .activeRest(title: title, minutes: available), estimatedMinutes: available)
    }

    /// Fatigue : une série de moins (minimum 2), variantes sans impact, intensité modérée.
    func lighten(_ workout: Workout) -> Workout {
        var result = workout
        result.exercises = workout.exercises.map { exercise in
            var lighter = exercise
            lighter.sets = max(exercise.sets - 1, 2)
            if exercise.isHighImpact, let alternative = exercise.lowImpactAlternative {
                lighter.name = alternative
                lighter.isHighImpact = false
            }
            return lighter
        }
        result.intensityCue = "Effort modéré : garde 3 répétitions en réserve. Arrête si la fatigue devient douleur."
        return result
    }

    /// Réduit la séance jusqu'à tenir dans le temps : repos, puis échauffement, puis séries, puis accessoires.
    func fit(_ workout: Workout, toMinutes budget: Int) -> Workout {
        var result = workout
        let steps: [(inout Workout) -> Void] = [
            { w in w.exercises = w.exercises.map { var e = $0; e.restSeconds = max(30, e.restSeconds * 2 / 3); return e } },
            { w in w.warmupMinutes = min(w.warmupMinutes, 3); w.cooldownMinutes = min(w.cooldownMinutes, 2) },
            { w in w.exercises = w.exercises.map { var e = $0; if e.priority > 1 { e.sets = min(e.sets, 2) }; return e } },
            { w in w.exercises = w.exercises.map { var e = $0; e.sets = min(e.sets, 2); return e } },
        ]
        for step in steps where result.estimatedMinutes > budget {
            step(&result)
        }
        while result.estimatedMinutes > budget && result.exercises.count > Self.minimumExercises {
            let lowestPriority = result.exercises.map(\.priority).max() ?? 0
            if let index = result.exercises.lastIndex(where: { $0.priority == lowestPriority }) {
                result.exercises.remove(at: index)
            }
        }
        return result
    }
}
