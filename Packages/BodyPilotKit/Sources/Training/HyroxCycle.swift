import BodyPilotCore

/// Cycle Hyrox (plan validé par Mounaïm le 2026-10-28, docs/COACH_RULES.md) : la course au
/// premier plan, avec une progression prudente (les tendons d'abord), la force en 2 séances
/// au service des ateliers, et les fondamentaux (technique puis endurance de force).
public enum HyroxCycle {
    public static let qualityTitle = "Séance de qualité"
    public static let easyRunTitle = "Course facile"
    public static let fundamentalsTitle = "Fondamentaux Hyrox"
    public static let benchmarkTitle = "Test Hyrox"

    /// Test de départ et de fin : 1 km + 50 wall balls + 1 km, au chrono.
    static let benchmarkWeeks: Set<Int> = [1, 11]

    // MARK: Course facile

    /// Phase 1 : course alternée avec la marche (tours, course, marche, en secondes).
    static let runWalkByWeek: [(rounds: Int, run: Int, walk: Int)] = [(8, 60, 90), (7, 120, 90), (6, 180, 60), (5, 180, 60)]
    /// Phases 2 et 3 : course continue (min), semaines 5 à 12.
    static let continuousMinutesByWeek = [20, 25, 30, 20, 30, 35, 40, 25]

    static let runCue = "Allure facile : tu peux parler en phrases complètes. Petits pas rapides, sur tapis ou sol souple si possible."

    static func easyRun(for week: CycleWeek, budget: Int, zone: ClosedRange<Int>?) -> Workout {
        let cue = zone.map { "Allure facile, entre \($0.lowerBound) et \($0.upperBound) battements par minute. Petits pas rapides, sur tapis ou sol souple si possible." } ?? runCue
        let exercise: WorkoutExercise
        if week.phase == 1 {
            let plan = runWalkByWeek[week.weekInPhase - 1]
            exercise = running("Course facile, alternée avec la marche", sets: plan.rounds, seconds: plan.run, rest: plan.walk)
        } else {
            let minutes = min(continuousMinutesByWeek[week.number - 5], max(budget - 5, 10))
            exercise = running("Course facile continue", sets: 1, seconds: minutes * 60 - WorkoutExercise.transitionSeconds, rest: 0)
        }
        return Workout(
            title: easyRunTitle, warmupMinutes: 5, cooldownMinutes: 0, exercises: [exercise],
            intensityCue: week.phase == 1 ? cue + " La récupération se fait en marchant." : cue
        )
    }

    /// Course : remplacée par le vélo en cas de fatigue (sans impact) ou de genou sensible.
    static func running(_ name: String, sets: Int, seconds: Int, rest: Int) -> WorkoutExercise {
        WorkoutExercise(
            name: name, sets: sets, volume: .seconds(seconds), restSeconds: rest, priority: 4,
            isHighImpact: true, lowImpactAlternative: "Vélo à allure modérée",
            loadsKnee: true, kneeFriendlyAlternative: "Vélo à allure modérée"
        )
    }

    // MARK: Séance de qualité

    /// Phase 1 sans impact (rameur, SkiErg), phase 2 au kilomètre à allure Hyrox, phase 3 en
    /// course enchaînée (1 km puis un atelier).
    static func quality(for week: CycleWeek) -> Workout {
        let exercise: WorkoutExercise
        let cue: String
        switch week.number {
        case 1, 2, 3:
            let rounds = [6, 8, 5][week.number - 1]
            let work = week.number == 3 ? 180 : 120
            exercise = WorkoutExercise(
                name: week.number == 3 ? "SkiErg et rameur en alternance" : "Rameur fractionné",
                sets: rounds, volume: .seconds(work), restSeconds: 60, priority: 4,
                alternatives: ["SkiErg fractionné", "Vélo fractionné"]
            )
            cue = "Efforts soutenus, réguliers du premier au dernier. Pas de course dure en phase 1 : les tendons s'habituent d'abord."
        case 4:
            exercise = WorkoutExercise(name: "Vélo facile", sets: 1, volume: .seconds(20 * 60 - WorkoutExercise.transitionSeconds), restSeconds: 0, priority: 4, alternatives: ["Rameur à allure modérée"])
            cue = "Semaine allégée : allure facile, tu peux parler."
        case 5, 6, 7, 8:
            exercise = running("1 km à allure Hyrox", sets: [4, 5, 6, 3][week.number - 5], seconds: 360, rest: 120)
            cue = "Allure Hyrox : tu peux dire quelques mots, effort 6 à 7 sur 10. Récupère en marchant."
        default:
            let rounds = [9: 4, 10: 4, 12: 3][week.number] ?? 6
            exercise = running(
                week.number == 10
                    ? "1 km à allure Hyrox, puis l'atelier suivant dans l'ordre de la course (SkiErg, poussée, tirage, burpees)"
                    : "1 km à allure Hyrox, puis un atelier (fentes, marche du fermier, wall balls ou rameur)",
                sets: rounds, seconds: 480, rest: 60
            )
            cue = "Course enchaînée : la course après un atelier se fait jambes lourdes, à allure Hyrox. Repars sans t'arrêter."
        }
        return Workout(title: qualityTitle, warmupMinutes: 10, cooldownMinutes: 5, exercises: [exercise], intensityCue: cue)
    }

    /// En semaine 1 (phase 1, pas de course dure), le test se court à allure soutenue mais
    /// contrôlée : il donne la référence. En semaine 11, à allure de course.
    static func benchmark(for week: CycleWeek) -> Workout {
        let first = week.phase == 1
        let run = first ? "1 km à allure soutenue" : "1 km à allure Hyrox"
        return Workout(
            title: benchmarkTitle, warmupMinutes: 10, cooldownMinutes: 5,
            exercises: [
                running(run, sets: 1, seconds: 360, rest: 0),
                WorkoutExercise(name: "Wall ball", sets: 1, volume: .reps(50), restSeconds: 0, priority: 4, loadsKnee: true, kneeFriendlyAlternative: "Rameur 500 m"),
                running(run, sets: 1, seconds: 360, rest: 0),
            ],
            intensityCue: first
                ? "Au chrono : 1 km, 50 wall balls en séries fixes, 1 km. Allure soutenue mais contrôlée, sans finir à fond : c'est ta référence de départ, les tendons s'habituent encore."
                : "Au chrono, sans pause prévue : 1 km, 50 wall balls en séries fixes, 1 km. Compare ton temps à celui de la semaine 1."
        )
    }

    // MARK: Fondamentaux

    /// Technique des ateliers en phase 1, endurance de force ensuite, puis les ateliers qui
    /// coûtent le plus en fin de course.
    static func fundamentals(for week: CycleWeek) -> Workout {
        let exercises: [WorkoutExercise]
        let cue: String
        switch week.number {
        case 5, 6, 7, 8:
            exercises = [WorkoutExercise(
                name: "Tour : 200 m de marche du fermier, 50 m de fentes avec sac, 30 wall balls",
                sets: [2, 3, 3, 2][week.number - 5], volume: .seconds(420), restSeconds: 120, priority: 4,
                loadsKnee: true, kneeFriendlyAlternative: "Tour : 200 m de marche du fermier, 500 m de rameur"
            )]
            cue = "Endurance de force à allure de course : régulier, sans t'arrêter. Charges légères la 1re semaine, de course ensuite."
        case 9, 10:
            exercises = [WorkoutExercise(name: "100 wall balls en séries fixes de 10 à 15", sets: 1, volume: .seconds(600), restSeconds: 0, priority: 4, loadsKnee: true, kneeFriendlyAlternative: "Rameur 2 000 m")]
            cue = "Découpe en séries fixes avec des pauses courtes et prévues, sans aller jusqu'à l'échec."
        case 11:
            exercises = [WorkoutExercise(name: "Fentes avec sac lesté (50 m) et marche du fermier (100 m)", sets: 3, volume: .seconds(240), restSeconds: 120, priority: 4, loadsKnee: true, kneeFriendlyAlternative: "Marche du fermier (200 m)")]
            cue = "Charges de course : le sac et les poignées ne se posent pas."
        default:
            exercises = technique(sets: week.isDeload || week.number == 12 ? 2 : 3)
            cue = "Technique d'abord, à charge légère : la clé de chaque atelier est dans sa fiche."
        }
        return Workout(title: fundamentalsTitle, warmupMinutes: 8, cooldownMinutes: 0, exercises: exercises, intensityCue: cue)
    }

    /// Les 8 ateliers, à charge légère.
    static func technique(sets: Int) -> [WorkoutExercise] {
        [
            WorkoutExercise(name: "SkiErg (250 m)", sets: sets, volume: .seconds(60), restSeconds: 60, priority: 4, alternatives: ["Rameur (250 m)"]),
            WorkoutExercise(name: "Poussée de traîneau (20 m)", sets: sets, volume: .seconds(30), restSeconds: 90, priority: 4, alternatives: ["Presse à cuisses"]),
            WorkoutExercise(name: "Tirage de traîneau (20 m)", sets: sets, volume: .seconds(40), restSeconds: 90, priority: 4, alternatives: ["Tirage horizontal à la poulie"]),
            WorkoutExercise(name: "Burpees sautés en longueur (10 m)", sets: sets, volume: .seconds(40), restSeconds: 60, priority: 4, isHighImpact: true, lowImpactAlternative: "Burpees sans saut", loadsKnee: true, kneeFriendlyAlternative: "Pompes"),
            WorkoutExercise(name: "Marche du fermier (50 m)", sets: sets, volume: .seconds(45), restSeconds: 60, priority: 4),
            WorkoutExercise(name: "Fentes avec sac lesté (20 m)", sets: sets, volume: .seconds(45), restSeconds: 60, priority: 4, loadsKnee: true, kneeFriendlyAlternative: "Presse à cuisses"),
            WorkoutExercise(name: "Wall ball", sets: sets, volume: .reps(15), restSeconds: 60, priority: 4, loadsKnee: true, kneeFriendlyAlternative: "Développé militaire haltères"),
        ]
    }

    // MARK: Force

    /// Après la force : poussée de traîneau (A) ou tirage (B), et 10 minutes d'ateliers quand la
    /// semaine n'a pas de séance de fondamentaux.
    static func compose(_ strength: Workout, week: CycleWeek, stationsAfter: Bool) -> Workout {
        var result = strength
        result.exercises.append(strength.title == WorkoutCatalog.gymB.title
            ? WorkoutExercise(name: "Tirage de traîneau (20 m)", sets: week.isDeload ? 2 : 4, volume: .seconds(40), restSeconds: 90, priority: 3, alternatives: ["Tirage horizontal à la poulie"])
            : WorkoutExercise(name: "Poussée de traîneau (20 m)", sets: week.isDeload ? 2 : 4, volume: .seconds(30), restSeconds: 90, priority: 3, alternatives: ["Presse à cuisses"]))
        if stationsAfter {
            result.exercises.append(WorkoutExercise(
                name: "Ateliers : marche du fermier, fentes avec sac, wall balls, à charge légère",
                sets: 1, volume: .seconds(600 - WorkoutExercise.transitionSeconds), restSeconds: 0, priority: 4,
                loadsKnee: true, kneeFriendlyAlternative: "Marche du fermier et SkiErg"
            ))
        }
        return result
    }

    // MARK: Choix du jour

    enum Session { case benchmark, quality, fundamentals, easyRun }

    /// Le cardio du jour : la séance dure tant qu'elle reste à faire et que le jour s'y prête
    /// (ni fatigue, ni courbatures, ni nuit courte), puis les fondamentaux, puis la course facile.
    static func session(for week: CycleWeek, constraints: DayConstraints) -> Session {
        let done = constraints.cycleWorkoutsThisWeek
        let fresh = !constraints.avoidsMaximalEffort && !constraints.sore && (constraints.sleepHours ?? 8) >= 6
        let hardDone = done.contains { $0 == qualityTitle || $0 == benchmarkTitle }
        if fresh, !hardDone {
            return benchmarkWeeks.contains(week.number) ? .benchmark : .quality
        }
        let fundamentalsTarget = constraints.cyclePlan?.fundamentals ?? 1
        if done.filter({ $0 == fundamentalsTitle }).count < fundamentalsTarget {
            return .fundamentals
        }
        return .easyRun
    }

    static func workout(_ session: Session, week: CycleWeek, budget: Int, zone: ClosedRange<Int>?) -> Workout {
        switch session {
        case .benchmark: benchmark(for: week)
        case .quality: quality(for: week)
        case .fundamentals: fundamentals(for: week)
        case .easyRun: easyRun(for: week, budget: budget, zone: zone)
        }
    }

    static func reason(_ session: Session, week: CycleWeek, strengthOK: Bool) -> String? {
        let lead = strengthOK ? "Force de la semaine faite" : "Force faite récemment"
        return switch session {
        case .benchmark: "\(lead) : c'est le jour du test Hyrox (1 km, 50 wall balls, 1 km). Note ton temps pour mesurer ta progression."
        case .quality: "\(lead) : c'est le jour de la séance de qualité de la semaine \(week.number)."
        case .fundamentals: "\(lead) : place aux fondamentaux, la technique et l'endurance des ateliers."
        case .easyRun: nil
        }
    }
}
