import BodyPilotCore

/// Cardio du cycle de 12 semaines : une séance de fractionné par semaine, les autres jours de
/// cardio en aérobie continue. Durées et formats du plan validé (docs/COACH_RULES.md) : 30 s / 30 s
/// en phase 1, puis efforts de 3 à 4 min (4 × 4 min : Helgerud et al., 2007), sans impact.
public enum CycleCardio {
    public static let intervalsTitle = "Fractionné du cycle"
    public static let aerobicTitle = "Cardio aérobie"

    public struct Intervals: Sendable, Equatable {
        public var rounds: Int
        public var workSeconds: Int
        public var restSeconds: Int
    }

    static let aerobicMinutesByWeek = [30, 35, 40, 25, 40, 45, 45, 30, 45, 50, 50, 30]
    static let intervalsByWeek: [Intervals?] = [
        Intervals(rounds: 6, workSeconds: 30, restSeconds: 30),
        Intervals(rounds: 8, workSeconds: 30, restSeconds: 30),
        Intervals(rounds: 10, workSeconds: 30, restSeconds: 30),
        Intervals(rounds: 5, workSeconds: 30, restSeconds: 30),
        Intervals(rounds: 3, workSeconds: 180, restSeconds: 180),
        Intervals(rounds: 4, workSeconds: 180, restSeconds: 180),
        Intervals(rounds: 4, workSeconds: 240, restSeconds: 180),
        Intervals(rounds: 2, workSeconds: 180, restSeconds: 180),
        Intervals(rounds: 4, workSeconds: 240, restSeconds: 180),
        Intervals(rounds: 5, workSeconds: 240, restSeconds: 180),
        Intervals(rounds: 8, workSeconds: 120, restSeconds: 60),
        // Semaine 12 : allégée, le WOD de référence remplace le fractionné.
        nil,
    ]

    public static func aerobicMinutes(for week: CycleWeek) -> Int {
        aerobicMinutesByWeek[min(max(week.number, 1), TrainingCycle.weeks) - 1]
    }

    public static func intervals(for week: CycleWeek) -> Intervals? {
        intervalsByWeek[min(max(week.number, 1), TrainingCycle.weeks) - 1]
    }

    /// Séance dure de la semaine : le WOD de référence en semaines 11 et 12 (salle), sinon le fractionné.
    static func hardWorkout(for week: CycleWeek, budget: Int, equipment: Equipment) -> Workout? {
        if week.number >= benchmarkWeeks.lowerBound, equipment == .gym {
            return CycleConditioning.benchmarkWorkout()
        }
        return intervals(for: week).map { intervalsWorkout($0, week: week, budget: budget, equipment: equipment) }
    }

    /// Semaines du WOD de référence : une première mesure, puis la comparaison.
    static let benchmarkWeeks = 11...12

    /// La séance dure de la semaine reste à faire, et le jour s'y prête : ni fatigue, ni
    /// courbatures, ni nuit courte (moins de 6 h).
    static func intervalsDue(_ week: CycleWeek, equipment: Equipment, constraints: DayConstraints) -> Bool {
        // À 2 séances dans la semaine, le fractionné se fait en fin de force.
        if constraints.cyclePlan?.hard == 0 || week.program == .hyrox { return false }
        let available = intervals(for: week) != nil || (benchmarkWeeks.contains(week.number) && equipment == .gym)
        let done = constraints.cycleWorkoutsThisWeek.contains { $0 == intervalsTitle || $0 == CycleConditioning.benchmarkTitle }
        return available && !done
            && !constraints.avoidsHardCardio && !constraints.sore
            && (constraints.sleepHours ?? 8) >= 6
    }

    static let warmupMinutes = 8
    static let cooldownMinutes = 5

    /// Fractionné de la semaine (rameur ou vélo, sans impact), resserré si le temps manque.
    static func intervalsWorkout(_ intervals: Intervals, week: CycleWeek, budget: Int, equipment: Equipment) -> Workout {
        var exercise = intervalsExercise(intervals, equipment: equipment)
        var workout = Workout(
            title: intervalsTitle, warmupMinutes: warmupMinutes, cooldownMinutes: cooldownMinutes, exercises: [exercise],
            intensityCue: intervals.workSeconds >= 120
                ? "Efforts durs, 85 à 95 % de ta fréquence cardiaque maximale : tu ne peux plus parler. Récupère en continuant doucement."
                : "Efforts vifs mais réguliers, du premier au dernier. Récupère en continuant doucement."
        )
        while workout.estimatedMinutes > budget && exercise.sets > 2 {
            exercise.sets -= 1
            workout.exercises = [exercise]
        }
        return workout
    }

    static func intervalsExercise(_ intervals: Intervals, equipment: Equipment) -> WorkoutExercise {
        let gym = equipment == .gym
        return WorkoutExercise(
            name: gym ? "Rameur fractionné" : "Boxe dans le vide fractionnée",
            sets: intervals.rounds, volume: .seconds(intervals.workSeconds), restSeconds: intervals.restSeconds, priority: 4,
            alternatives: gym ? ["Vélo fractionné", "SkiErg fractionné"] : ["Mountain climbers", "Pas chassés"]
        )
    }

    /// Aérobie continue : allure où l'on peut parler, durée de la semaine dans la limite du temps du jour.
    static func aerobicWorkout(week: CycleWeek, budget: Int, equipment: Equipment, dayIndex: Int, zone: ClosedRange<Int>?) -> Workout {
        let formats = WorkoutCatalog.recoveryCardio(for: equipment)
        let format = formats[dayIndex % formats.count]
        let minutes = max(min(aerobicMinutes(for: week), budget), 10)
        let cue = zone.map { "Allure où tu peux parler, entre \($0.lowerBound) et \($0.upperBound) battements par minute." }
            ?? "Allure où tu peux parler en phrases complètes, tout du long."
        return Workout(
            title: aerobicTitle, warmupMinutes: 0, cooldownMinutes: 0,
            exercises: [WorkoutExercise(name: format.name, sets: 1, volume: .seconds(minutes * 60 - WorkoutExercise.transitionSeconds), restSeconds: 0, priority: 4, alternatives: format.alternatives)],
            intensityCue: cue
        )
    }
}
