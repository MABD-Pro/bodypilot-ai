import BodyPilotCore
import Foundation

/// Planificateur de séances par règles. Pas de jours fixes : chaque jour a sa séance.
/// Force lourde en full body quand la précédente date d'au moins 48 h, sinon cardio et marche
/// inclinée, puis les ajustements du jour (temps, fatigue, genou) dans des limites de sécurité.
public struct TrainingPlanner: TrainingPlanning {
    public var calendar: Calendar

    /// En dessous, une séance n'a plus de sens : on propose de la marche.
    public static let minimumWorkoutMinutes = 12
    /// On garde au moins les exercices essentiels.
    static let minimumExercises = 3
    /// En déplacement, une séance courte est plus réaliste.
    public static let travelMaxMinutes = 30
    /// À partir de cette durée, la séance enchaîne les trois axes : force, cardio, marche inclinée.
    /// En dessous, la force seule : mieux vaut l'essentiel bien fait.
    public static let threeAxisMinutes = 30
    /// Part du temps donnée à la force ; le reste se partage entre cardio et marche inclinée.
    static let strengthShare = 0.6
    /// Repos minimal conservé sur les exercices principaux quand la séance est resserrée.
    static let mainLiftRestSeconds = 120
    /// Jours entre deux séances de force lourde sur les mêmes muscles (48 h).
    public static let strengthRecoveryDays = 2
    /// Séances de force visées par semaine : chaque muscle 2 à 3 fois (Schoenfeld et al., 2016).
    public static let weeklyStrengthTarget = 3

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// Jours d'entraînement par défaut, pour un nombre de séances donné.
    public static func trainingWeekdays(daysPerWeek: Int) -> [Int] {
        UserProfile.defaultTrainingWeekdays(count: daysPerWeek)
    }

    /// Titre d'une séance de force du catalogue (et non d'une séance cardio et marche).
    public static func isStrengthSession(_ title: String) -> Bool {
        (WorkoutCatalog.sessions(for: .gym) + WorkoutCatalog.sessions(for: .bodyweight)).contains { $0.title == title }
    }

    /// Force possible ce jour-là : jamais faite, ou faite il y a au moins 48 h.
    public func isStrengthDay(_ date: Date, lastStrengthDay: Date?) -> Bool {
        guard let lastStrengthDay else { return true }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: lastStrengthDay), to: calendar.startOfDay(for: date)).day ?? 0
        return days >= Self.strengthRecoveryDays
    }

    public func trainingDay(for profile: UserProfile, on date: Date, constraints: DayConstraints) -> TrainingDay {
        var profile = profile
        if constraints.traveling {
            profile.equipment = .bodyweight
            profile.sessionMinutes = min(profile.sessionMinutes, Self.travelMaxMinutes)
        }
        var notes: [String] = []

        if constraints.missedToday {
            let minutes = 15
            return TrainingDay(
                kind: .activeRest(title: "Marche tranquille", minutes: minutes),
                estimatedMinutes: minutes,
                notes: ["Séance ratée : on ne la double pas. Le coach la repropose au prochain jour."]
            )
        }

        let budget = min(constraints.availableMinutes ?? profile.sessionMinutes, profile.sessionMinutes)
        let composed: Workout
        if isStrengthDay(date, lastStrengthDay: constraints.lastStrengthDay) {
            let strength = nextWorkout(after: constraints.lastWorkoutTitle, for: profile, on: date)
            composed = budget >= Self.threeAxisMinutes ? withConditioning(strength, budget: budget, equipment: profile.equipment, on: date) : strength
        } else {
            composed = conditioningWorkout(budget: budget, equipment: profile.equipment, on: date)
            notes.append("Force faite hier : aujourd'hui cardio et marche, les muscles récupèrent 48 h avant la prochaine séance lourde.")
        }

        // Les remplacements choisis passent avant les règles de sécurité : une variante qui
        // charge le genou est elle aussi remplacée si le genou est douloureux.
        var adapted = swapExercises(composed, swaps: constraints.exerciseSwaps)
        if constraints.traveling {
            notes.append("Déplacement : séance au poids du corps, faisable dans une chambre d'hôtel.")
        }
        if constraints.kneePain {
            adapted = protectKnee(adapted)
            notes.append("Genou : aucun exercice qui le charge. Si la douleur est vive, gonfle ou dure plus de quelques jours, consulte un professionnel de santé.")
        }
        if constraints.lowEnergy {
            adapted = lighten(adapted)
            notes.append("Fatigue : une série de moins, pas d'impacts, effort modéré.")
        }

        if budget < Self.minimumWorkoutMinutes || adapted.exercises.isEmpty {
            let minutes = max(min(budget, 30), 10)
            return TrainingDay(
                kind: .activeRest(title: "Marche rapide", minutes: minutes),
                estimatedMinutes: minutes,
                notes: notes + ["Moins de \(Self.minimumWorkoutMinutes) minutes : une marche rapide vaut mieux qu'une séance bâclée."]
            )
        }
        if adapted.estimatedMinutes > budget {
            adapted = fit(adapted, toMinutes: budget)
            notes.append("Séance resserrée à \(adapted.estimatedMinutes) min : l'essentiel est gardé.")
        }
        return TrainingDay(kind: .workout(adapted), estimatedMinutes: adapted.estimatedMinutes, notes: notes)
    }

    /// Jour de récupération musculaire : cardio varié puis marche inclinée ou escalier.
    func conditioningWorkout(budget: Int, equipment: Equipment, on date: Date) -> Workout {
        let title = equipment == .gym ? "Cardio et marche inclinée" : "Cardio et marche en côte"
        let base = Workout(
            title: title, warmupMinutes: 5, cooldownMinutes: 0, exercises: [],
            intensityCue: "Tout à allure modérée : tu peux parler, avec un léger essoufflement."
        )
        // Muscles en récupération : cardio continu, modéré et sans impact (moins d'interférence, Wilson et al., 2012).
        return withConditioning(base, budget: budget, equipment: equipment, on: date, recovery: true)
    }

    /// Force d'abord (60 % du temps), puis un cardio qui change d'une séance à l'autre,
    /// puis la marche inclinée ou l'escalier, qui fait aussi office de retour au calme.
    func withConditioning(_ strength: Workout, budget: Int, equipment: Equipment, on date: Date, recovery: Bool = false) -> Workout {
        var result = fit(strength, toMinutes: Int(Double(budget) * Self.strengthShare))
        result.cooldownMinutes = 0
        let remaining = budget - result.estimatedMinutes
        guard remaining >= 8 else { return strength }

        let index = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        let cardioFormats = recovery ? WorkoutCatalog.recoveryCardio(for: equipment) : WorkoutCatalog.cardio(for: equipment)
        let inclineFormats = WorkoutCatalog.incline(for: equipment)
        let cardio = cardioFormats[index % cardioFormats.count]
        let incline = inclineFormats[index % inclineFormats.count]
        let cardioSeconds = remaining / 2 * 60
        let transition = WorkoutExercise.transitionSeconds

        if cardio.restSeconds > 0 {
            // Un nombre pair de tours, plus simple à suivre.
            let fitting = (cardioSeconds - transition + cardio.restSeconds) / (cardio.workSeconds + cardio.restSeconds)
            let rounds = max(4, fitting - fitting % 2)
            result.exercises.append(WorkoutExercise(
                name: cardio.name, sets: rounds, volume: .seconds(cardio.workSeconds), restSeconds: cardio.restSeconds, priority: 4,
                isHighImpact: cardio.isHighImpact, lowImpactAlternative: cardio.lowImpactAlternative,
                loadsKnee: cardio.loadsKnee, kneeFriendlyAlternative: cardio.kneeFriendlyAlternative, alternatives: cardio.alternatives
            ))
        } else {
            result.exercises.append(WorkoutExercise(
                name: cardio.name, sets: 1, volume: .seconds(cardioSeconds - transition), restSeconds: 0, priority: 4, alternatives: cardio.alternatives
            ))
        }

        // La marche prend le temps qui reste, à la minute près.
        var inclineSeconds = (budget - result.estimatedMinutes) * 60 - transition
        var walk = WorkoutExercise(
            name: incline.name, sets: 1, volume: .seconds(inclineSeconds), restSeconds: 0, priority: 4,
            loadsKnee: incline.loadsKnee, kneeFriendlyAlternative: incline.kneeFriendlyAlternative, alternatives: incline.alternatives
        )
        while inclineSeconds > 300 && result.estimatedMinutes + Int((Double(walk.estimatedSeconds) / 60).rounded(.up)) > budget {
            inclineSeconds -= 60
            walk.volume = .seconds(inclineSeconds)
        }
        guard inclineSeconds >= 300 else {
            result.cooldownMinutes = strength.cooldownMinutes
            return result
        }
        result.exercises.append(walk)
        return result
    }

    /// La séance de force qui suit la dernière faite (A puis B) ; sans historique, la A.
    func nextWorkout(after title: String?, for profile: UserProfile, on date: Date) -> Workout {
        let sessions = WorkoutCatalog.sessions(for: profile.equipment)
        guard let title, let index = sessions.firstIndex(where: { $0.title == title }) else { return sessions[0] }
        return sessions[(index + 1) % sessions.count]
    }

    /// Remplace chaque exercice demandé par sa variante : la n-ième demande donne la n-ième variante,
    /// puis on revient à l'exercice d'origine. Séries, volume et repos sont conservés.
    func swapExercises(_ workout: Workout, swaps: [String: Int]) -> Workout {
        var result = workout
        result.exercises = workout.exercises.map { exercise in
            guard let count = swaps[exercise.key], !exercise.alternatives.isEmpty else { return exercise }
            let position = count % (exercise.alternatives.count + 1)
            guard position > 0 else { return exercise }
            var swapped = exercise
            swapped.name = exercise.alternatives[position - 1]
            return swapped
        }
        return result
    }

    /// Genou douloureux : variantes sans flexion chargée ni impact ; sans variante, l'exercice est retiré.
    func protectKnee(_ workout: Workout) -> Workout {
        var result = workout
        result.exercises = workout.exercises.compactMap { exercise in
            guard exercise.loadsKnee else { return exercise }
            guard let alternative = exercise.kneeFriendlyAlternative else { return nil }
            var safer = exercise
            safer.name = alternative
            safer.loadsKnee = false
            safer.isHighImpact = false
            // La variante de sécurité ne se remplace pas : elle seule épargne le genou.
            safer.alternatives = []
            return safer
        }
        return result
    }

    /// Fatigue : une série de moins (minimum 2), variantes sans impact, intensité modérée.
    func lighten(_ workout: Workout) -> Workout {
        var result = workout
        result.exercises = workout.exercises.map { exercise in
            var lighter = exercise
            // Un effort continu (marche, cardio tempo) reste en une seule fois.
            lighter.sets = exercise.sets > 1 ? max(exercise.sets - 1, 2) : 1
            if exercise.isHighImpact, let alternative = exercise.lowImpactAlternative {
                lighter.name = alternative
                lighter.isHighImpact = false
                lighter.alternatives = []
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
            // Les exercices principaux gardent au moins 2 minutes de repos : en dessous, la force
            // progresse moins sur les polyarticulaires (Grgic et al., 2018). Voir docs/TRAINING_EVIDENCE.md.
            { w in w.exercises = w.exercises.map { var e = $0; e.restSeconds = e.priority == 1 ? max(min(e.restSeconds, Self.mainLiftRestSeconds), e.restSeconds * 2 / 3) : max(30, e.restSeconds * 2 / 3); return e } },
            { w in w.warmupMinutes = min(w.warmupMinutes, 3); w.cooldownMinutes = min(w.cooldownMinutes, 2) },
            // Le cardio et la marche (priorité 4) ne perdent pas de séries : ils sont retirés en premier si besoin.
            { w in w.exercises = w.exercises.map { var e = $0; if e.priority > 1 && e.priority < 4 { e.sets = min(e.sets, 2) }; return e } },
            { w in w.exercises = w.exercises.map { var e = $0; if e.priority < 4 { e.sets = min(e.sets, 2) }; return e } },
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
