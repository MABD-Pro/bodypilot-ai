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
    /// En déplacement, une séance courte est plus réaliste.
    public static let travelMaxMinutes = 30
    /// À partir de cette durée, la séance enchaîne les trois axes : force, cardio, marche inclinée.
    /// En dessous, la force seule : mieux vaut l'essentiel bien fait.
    public static let threeAxisMinutes = 30
    /// Part du temps donnée à la force ; le reste se partage entre cardio et marche inclinée.
    static let strengthShare = 0.6

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// Jours d'entraînement par défaut, pour un nombre de séances donné.
    public static func trainingWeekdays(daysPerWeek: Int) -> [Int] {
        UserProfile.defaultTrainingWeekdays(count: daysPerWeek)
    }

    public func isTrainingDay(_ date: Date, for profile: UserProfile) -> Bool {
        profile.trainingWeekdays.contains(calendar.component(.weekday, from: date))
    }

    public func trainingDay(for profile: UserProfile, on date: Date, constraints: DayConstraints) -> TrainingDay {
        var profile = profile
        if constraints.traveling {
            profile.equipment = .bodyweight
            profile.sessionMinutes = min(profile.sessionMinutes, Self.travelMaxMinutes)
        }
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
            } else if constraints.wantsExtraSession && !constraints.missedToday {
                workout = nextWorkout(after: constraints.lastWorkoutTitle, for: profile, on: date)
                notes.append(constraints.lastWorkoutTitle.map { "Séance en plus : la suite de « \($0) », pour faire travailler d'autres muscles." }
                    ?? "Séance en plus : les jours cochés sont un repère, pas une limite.")
            } else {
                return restDay(for: profile, constraints: constraints)
            }
        }

        let budget = min(constraints.availableMinutes ?? profile.sessionMinutes, profile.sessionMinutes)
        let composed = budget >= Self.threeAxisMinutes ? withConditioning(workout, budget: budget, equipment: profile.equipment, on: date) : workout

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
        let weekdays = profile.trainingWeekdays
        let position = weekdays.firstIndex(of: calendar.component(.weekday, from: date)) ?? 0
        let week = calendar.component(.weekOfYear, from: date)
        return sessions[(week * weekdays.count + position) % sessions.count]
    }

    /// Force d'abord (60 % du temps), puis un cardio qui change d'une séance à l'autre,
    /// puis la marche inclinée ou l'escalier, qui fait aussi office de retour au calme.
    func withConditioning(_ strength: Workout, budget: Int, equipment: Equipment, on date: Date) -> Workout {
        var result = fit(strength, toMinutes: Int(Double(budget) * Self.strengthShare))
        result.cooldownMinutes = 0
        let remaining = budget - result.estimatedMinutes
        guard remaining >= 8 else { return strength }

        let index = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        let cardioFormats = WorkoutCatalog.cardio(for: equipment)
        let inclineFormats = WorkoutCatalog.incline(for: equipment)
        let cardio = cardioFormats[index % cardioFormats.count]
        let incline = inclineFormats[index % inclineFormats.count]
        let cardioSeconds = remaining / 2 * 60
        let transition = WorkoutExercise.transitionSeconds

        if cardio.restSeconds > 0 {
            let rounds = max(3, (cardioSeconds - transition + cardio.restSeconds) / (cardio.workSeconds + cardio.restSeconds))
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

    /// La séance qui suit la dernière faite dans la rotation ; sans historique, celle du calendrier.
    func nextWorkout(after title: String?, for profile: UserProfile, on date: Date) -> Workout {
        let sessions = WorkoutCatalog.sessions(for: profile.equipment)
        guard let title, let index = sessions.firstIndex(where: { $0.title == title }) else {
            return scheduledWorkout(for: profile, on: date)
        }
        return sessions[(index + 1) % sessions.count]
    }

    private func restDay(for profile: UserProfile, constraints: DayConstraints) -> TrainingDay {
        if constraints.kneePain {
            return TrainingDay(
                kind: .activeRest(title: "Mobilité douce", minutes: 15),
                estimatedMinutes: 15,
                notes: ["Genou : marche seulement si elle est indolore. Sinon, mobilité du haut du corps et du bassin."]
            )
        }
        let minutes = (profile.goal == .loseFat || profile.goal == .recomposition) && !constraints.lowEnergy ? 30 : 20
        let incline = profile.equipment == .gym ? "Marche inclinée ou escalier" : "Marche en côte ou escaliers"
        let title = constraints.lowEnergy ? "Marche tranquille" : incline
        let available = constraints.availableMinutes.map { min($0, minutes) } ?? minutes
        let notes = constraints.traveling ? ["Déplacement : profite-en pour découvrir les lieux à pied."] : []
        return TrainingDay(kind: .activeRest(title: title, minutes: available), estimatedMinutes: available, notes: notes)
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
            { w in w.exercises = w.exercises.map { var e = $0; e.restSeconds = max(30, e.restSeconds * 2 / 3); return e } },
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
