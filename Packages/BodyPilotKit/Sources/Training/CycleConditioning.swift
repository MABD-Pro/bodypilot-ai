import BodyPilotCore

/// Fin de séance de force pendant le cycle en salle : 10 minutes de technique après la B
/// (kettlebell, puis épaulé), un conditioning court après la A et la C. Sans impact tant que
/// les critères du plan ne sont pas remplis : rameur, kettlebell, step-up, wall ball.
public enum CycleConditioning {
    /// Durée du conditioning par semaine (min) : 8 à 10 en phase 1, EMOM de 10 à 12 en phase 2,
    /// AMRAP de 12 à 15 en phase 3, plus court en semaine allégée.
    static let minutesByWeek = [8, 8, 10, 6, 10, 12, 12, 8, 12, 15, 15, 6]

    public static func minutes(for week: CycleWeek) -> Int {
        minutesByWeek[min(max(week.number, 1), TrainingCycle.weeks) - 1]
    }

    /// Le bloc de conditioning de la semaine, selon la phase.
    public static func finisher(for week: CycleWeek) -> WorkoutExercise {
        let name: String
        switch week.phase {
        case 1: name = "Circuit : 250 m de rameur, 10 kettlebell swings, 10 step-ups"
        case 2: name = "EMOM : chaque minute, 10 kettlebell swings puis 8 wall balls"
        default: name = "AMRAP : 10 wall balls, 10 kettlebell swings, 250 m de rameur"
        }
        return WorkoutExercise(
            name: name, sets: 1, volume: .seconds(minutes(for: week) * 60), restSeconds: 0, priority: 4,
            loadsKnee: true, kneeFriendlyAlternative: "Rameur à allure soutenue"
        )
    }

    /// Technique après la B : apprendre les mouvements olympiques sans fatigue, charges légères.
    public static func technique(for week: CycleWeek) -> WorkoutExercise {
        switch week.phase {
        case 1:
            WorkoutExercise(name: "Kettlebell swing", sets: 3, volume: .reps(10), restSeconds: 60, priority: 3, alternatives: ["Soulevé de terre roumain haltères"])
        case 2:
            WorkoutExercise(name: "Hang power clean", sets: 4, volume: .reps(3), restSeconds: 90, priority: 3, alternatives: ["Kettlebell swing"])
        default:
            WorkoutExercise(name: "Power clean", sets: 4, volume: .reps(3), restSeconds: 90, priority: 3, alternatives: ["Hang power clean"])
        }
    }

    public static let finisherCue = "Conditioning : allure soutenue mais régulière, sans sauter. Arrête-toi si la technique se dégrade."

    /// `intervals` : à 2 séances dans la semaine, le fractionné de la semaine remplace le
    /// conditioning (et suit la technique après la B), pour garder les deux stimuli.
    static func compose(_ strength: Workout, week: CycleWeek, intervals: WorkoutExercise? = nil) -> Workout {
        var result = strength
        if strength.title == WorkoutCatalog.gymB.title {
            result.exercises.append(technique(for: week))
            if let intervals { result.exercises.append(intervals) }
        } else if let intervals {
            result.exercises.append(intervals)
        } else {
            result.exercises.append(finisher(for: week))
            result.intensityCue += " " + finisherCue
        }
        return result
    }

    // MARK: WOD de référence

    public static let benchmarkTitle = "WOD de référence"

    /// « Helen » adaptée, sans course ni traction : 3 tours de 500 m de rameur, 21 kettlebell
    /// swings et 12 rowings aux anneaux, au chrono. Fait en semaine 11 puis en semaine 12.
    static func benchmarkWorkout() -> Workout {
        Workout(
            title: benchmarkTitle, warmupMinutes: 10, cooldownMinutes: 5,
            exercises: [
                WorkoutExercise(name: "Tour : 500 m de rameur, 21 kettlebell swings, 12 rowings aux anneaux", sets: 3, volume: .seconds(300), restSeconds: 0, priority: 4),
            ],
            intensityCue: "Enchaîne les 3 tours sans pause prévue, au chrono. Note ton temps : il mesure ta progression d'une fois à l'autre."
        )
    }
}
