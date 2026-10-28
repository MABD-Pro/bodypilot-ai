import BodyPilotCore
import Foundation

/// Planificateur de séances par règles, au jour le jour : chaque jour, force (si la dernière
/// date d'au moins 48 h), cardio et marche inclinée, marche tranquille ou repos. Le coach en
/// recommande une selon la récupération, l'utilisateur choisit ; puis les ajustements du jour
/// (temps, fatigue, genou) dans des limites de sécurité.
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
    /// Début de la note d'une séance resserrée au temps disponible.
    static let fittedNotePrefix = "Séance resserrée à"
    /// Jours entre deux séances de force lourde sur les mêmes muscles (48 h).
    public static let strengthRecoveryDays = 2
    /// Au-delà, le coach recommande un jour de repos complet.
    static let maxActiveStreak = 6
    /// Sous ce sommeil, la force maximale baisse (Knowles et al., 2018) : pas de séance lourde recommandée.
    static let shortSleepHours = 6.0
    /// Séance intense de la veille qui compte dans la récupération.
    static let hardActivityMinutes = 45.0
    static let intenseKinds: Set<ActivityKind> = [.intervals, .sport, .combat, .cardio, .running]
    /// Durée de la marche tranquille proposée.
    static let lightWalkMinutes = 30

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// Jours d'entraînement par défaut, pour un nombre de séances donné.
    public static func trainingWeekdays(daysPerWeek: Int) -> [Int] {
        UserProfile.defaultTrainingWeekdays(count: daysPerWeek)
    }

    /// Titre d'une séance de force du catalogue (et non d'une séance cardio et marche).
    public static func isStrengthSession(_ title: String) -> Bool {
        title.hasPrefix("Test de force") || title == WorkoutCatalog.gymCTitle
            || (WorkoutCatalog.sessions(for: .gym) + WorkoutCatalog.sessions(for: .bodyweight)).contains { $0.title == title }
    }

    /// Force possible ce jour-là : jamais faite, ou faite il y a au moins 48 h.
    public func isStrengthDay(_ date: Date, lastStrengthDay: Date?) -> Bool {
        guard let lastStrengthDay else { return true }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: lastStrengthDay), to: calendar.startOfDay(for: date)).day ?? 0
        return days >= Self.strengthRecoveryDays
    }

    public func options(for profile: UserProfile, on date: Date, constraints: DayConstraints) -> TrainingOptions {
        let profile = adapted(profile, constraints: constraints)
        let budget = min(constraints.availableMinutes ?? profile.sessionMinutes, profile.sessionMinutes)
        let strengthOK = isStrengthDay(date, lastStrengthDay: constraints.lastStrengthDay)
        let test = strengthOK ? strengthTest(for: profile, budget: budget, constraints: constraints) : nil
        let choices: [TrainingChoice] = (strengthOK ? [.strength] : []) + [.conditioning, .light, .rest]
        let hasCardioTest = cardioTest(budget: budget, constraints: constraints) != nil
        let recommendation = recommend(on: date, constraints: constraints, strengthOK: strengthOK, isTest: test != nil, cardioTest: hasCardioTest)
        var reason = recommendation.reason
        if recommendation.choice == .conditioning, !hasCardioTest, let week = constraints.cycleWeek, week.program == .hyrox {
            reason = HyroxCycle.reason(HyroxCycle.session(for: week, constraints: constraints), week: week, strengthOK: strengthOK) ?? reason
        } else if recommendation.choice == .conditioning, !hasCardioTest, let week = constraints.cycleWeek,
           CycleCardio.intervalsDue(week, equipment: profile.equipment, constraints: constraints) {
            // Force possible mais celles de la semaine sont faites (séances prévues) : autre entrée en matière.
            let lead = strengthOK ? "Force de la semaine faite" : "Force faite hier"
            reason = CycleCardio.benchmarkWeeks.contains(week.number) && profile.equipment == .gym
                ? "\(lead) : c'est le jour du WOD de référence de la semaine \(week.number). Note ton temps pour mesurer ta progression."
                : "\(lead) : c'est le jour du fractionné de la semaine \(week.number), sans impact. Les jambes récupèrent pendant que le cœur travaille."
        }
        return TrainingOptions(
            options: choices.map { TrainingOption(choice: $0, day: day(for: $0, profile: profile, budget: budget, test: test, on: date, constraints: constraints)) },
            recommended: recommendation.choice,
            reason: reason
        )
    }

    public func trainingDay(for profile: UserProfile, on date: Date, constraints: DayConstraints) -> TrainingDay {
        let options = options(for: profile, on: date, constraints: constraints)
        let chosen = constraints.choice.flatMap { options.option($0) } ?? options.option(options.recommended)
        return chosen?.day ?? TrainingDay(kind: .rest, estimatedMinutes: 0)
    }

    /// En déplacement : poids du corps, séance courte.
    func adapted(_ profile: UserProfile, constraints: DayConstraints) -> UserProfile {
        var profile = profile
        if constraints.traveling {
            profile.equipment = .bodyweight
            profile.sessionMinutes = min(profile.sessionMinutes, Self.travelMaxMinutes)
        }
        return profile
    }

    /// La proposition que le coach met en avant, et pourquoi. Repos complet après six jours
    /// d'activité d'affilée ou quand fatigue et nuit courte s'additionnent ; nuit courte seule :
    /// pas de force lourde ; courbatures : cardio modéré ; sinon force dès que 48 h sont passées.
    func recommend(on date: Date, constraints: DayConstraints, strengthOK: Bool, isTest: Bool, cardioTest: Bool = false) -> (choice: TrainingChoice, reason: String) {
        if constraints.missedToday {
            return (.light, "Séance ratée : on ne la double pas. Une marche tranquille aujourd'hui, la force revient au prochain jour.")
        }
        let streak = activeStreak(before: date, in: constraints.activeDays)
        if streak >= Self.maxActiveStreak {
            return (.rest, "\(streak) jours d'activité d'affilée : une journée de repos complet aide ton corps à récupérer.")
        }
        let sleep = constraints.sleepHours.flatMap { $0 < Self.shortSleepHours ? $0 : nil }
        if constraints.lowEnergy, let sleep {
            return (.rest, "Fatigue et nuit de \(Self.hours(sleep)) : repos aujourd'hui, la séance attendra demain.")
        }
        if let sleep {
            return strengthOK
                ? (.conditioning, "Nuit de \(Self.hours(sleep)) : le manque de sommeil fait baisser la force. Cardio modéré et marche plutôt que du lourd.")
                : (.light, "Nuit de \(Self.hours(sleep)) : une marche tranquille suffit aujourd'hui.")
        }
        if constraints.sore {
            return (.conditioning, "Courbatures : un cardio modéré et de la marche les soulagent mieux que le repos complet.")
        }
        if let planned = cycleRecommendation(constraints: constraints, strengthOK: strengthOK, cardioTest: cardioTest) {
            return planned
        }
        if strengthOK {
            if isTest {
                return (.strength, "Pas encore de charge notée sur tes mouvements de base : test de force pour trouver les tiennes.")
            }
            guard let last = constraints.lastStrengthDay else {
                return (.strength, "Première séance de force : on pose les bases.")
            }
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: last), to: calendar.startOfDay(for: date)).day ?? 0
            return (.strength, "Dernière séance de force il y a \(days) jours : tes muscles ont récupéré, place à la force.")
        }
        if let hard = hardActivity(before: date, in: constraints.recentActivities) {
            return (.light, "\(hard.kind.title) de \(Int(hard.minutes.rounded())) min hier et force il y a moins de 48 h : une marche tranquille pour récupérer.")
        }
        if cardioTest {
            return (.conditioning, "Force faite hier et pas encore de mesure de ta forme cardio : test de marche de 1,6 km aujourd'hui, il fixe ta zone de cardio.")
        }
        return (.conditioning, "Force faite hier : cardio modéré et marche aujourd'hui, les muscles récupèrent 48 h avant la prochaine séance lourde.")
    }

    /// Semaine du cycle avec un nombre de séances prévu : la force tant qu'il en manque, puis
    /// le fractionné et l'aérobie, puis le repos une fois les séances faites. `nil` : la règle
    /// habituelle (force dès 48 h) s'applique.
    func cycleRecommendation(constraints: DayConstraints, strengthOK: Bool, cardioTest: Bool) -> (choice: TrainingChoice, reason: String)? {
        guard let plan = constraints.cyclePlan, constraints.cycleWeek != nil else { return nil }
        let done = constraints.cycleWorkoutsThisWeek
        let strengthDone = done.filter(Self.isStrengthSession).count
        let hardTitles = [CycleCardio.intervalsTitle, CycleConditioning.benchmarkTitle, HyroxCycle.qualityTitle, HyroxCycle.benchmarkTitle]
        let hardDone = done.filter(hardTitles.contains).count
        let fundamentalsDone = done.filter { $0 == HyroxCycle.fundamentalsTitle }.count
        let cardioLeft = plan.hard > hardDone || plan.fundamentals > fundamentalsDone
            || plan.aerobic > done.count - strengthDone - hardDone - fundamentalsDone
        if done.count >= plan.sessions {
            return (.rest, "Tes \(plan.sessions) séances de la semaine sont faites : repos, ou une marche tranquille si tu as envie de bouger.")
        }
        if strengthDone >= plan.strength {
            return (.conditioning, cardioTest
                ? "Pas encore de mesure de ta forme cardio : test de marche de 1,6 km aujourd'hui, il fixe ta zone de cardio."
                : "Tes \(plan.strength) séances de force de la semaine sont faites : cardio aujourd'hui.")
        }
        if !strengthOK, !cardioLeft {
            return (.light, "Force faite hier et ton cardio de la semaine est fait : une marche tranquille, la force revient dès demain.")
        }
        return nil
    }

    /// Jours d'activité consécutifs juste avant ce jour.
    func activeStreak(before date: Date, in days: Set<Date>) -> Int {
        let days = Set(days.map { calendar.startOfDay(for: $0) })
        var streak = 0
        var cursor = calendar.startOfDay(for: date)
        while let previous = calendar.date(byAdding: .day, value: -1, to: cursor), days.contains(previous) {
            streak += 1
            cursor = previous
        }
        return streak
    }

    /// Séance intense enregistrée dans Santé la veille (cours collectif, fractionné, sport, course).
    func hardActivity(before date: Date, in activities: [ActivitySample]) -> ActivitySample? {
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: date)) else { return nil }
        return activities
            .filter { calendar.isDate($0.start, inSameDayAs: yesterday) && Self.intenseKinds.contains($0.kind) && $0.minutes >= Self.hardActivityMinutes }
            .max { $0.minutes < $1.minutes }
    }

    static func hours(_ value: Double) -> String {
        let total = Int((value * 60).rounded())
        return total % 60 == 0 ? "\(total / 60) h" : "\(total / 60) h \(String(format: "%02d", total % 60))"
    }

    func day(for choice: TrainingChoice, profile: UserProfile, budget: Int, test: Workout?, on date: Date, constraints: DayConstraints) -> TrainingDay {
        switch choice {
        case .strength:
            if let test {
                // Le test se fait tel quel : pas de remplacement, ni de séance resserrée.
                return TrainingDay(kind: .workout(test), estimatedMinutes: test.estimatedMinutes, notes: [
                    "Test de force : monte par paliers jusqu'à une série de 5 lourde et propre, puis note-la. Toutes tes charges de travail en découlent.",
                ])
            }
            var strength = nextWorkout(after: constraints.lastWorkoutTitle, for: profile, on: date, cycleWeek: constraints.cycleWeek)
            if let week = constraints.cycleWeek {
                strength = StrengthCycle.apply(week, to: strength, usesLoads: profile.equipment == .gym)
            }
            // Semaine allégée du cycle : séance plus courte, plutôt que plus de cardio.
            let sessionBudget = constraints.cycleWeek?.isDeload == true
                ? max(Int(Double(budget) * StrengthCycle.deloadTimeShare), min(budget, Self.threeAxisMinutes))
                : budget
            let composed: Workout
            // À 2 séances dans la semaine du cycle, le fractionné se fait en fin de force.
            let intervals = constraints.cycleWeek.flatMap { week in
                constraints.cyclePlan?.intervalsAfterStrength == true
                    ? CycleCardio.intervals(for: week).map { CycleCardio.intervalsExercise($0, equipment: profile.equipment) }
                    : nil
            }
            if let week = constraints.cycleWeek, week.program == .hyrox, profile.equipment == .gym {
                // Hyrox : traîneau après la force, ateliers si la semaine n'a pas de fondamentaux.
                composed = HyroxCycle.compose(strength, week: week, stationsAfter: constraints.cyclePlan?.stationsAfterStrength ?? false)
            } else if let week = constraints.cycleWeek, profile.equipment == .gym {
                // Cycle en salle : technique après la B, conditioning court après la A et la C.
                composed = CycleConditioning.compose(strength, week: week, intervals: intervals)
            } else if let intervals {
                var withIntervals = strength
                withIntervals.exercises.append(intervals)
                composed = withIntervals
            } else {
                composed = sessionBudget >= Self.threeAxisMinutes ? withConditioning(strength, budget: sessionBudget, equipment: profile.equipment, on: date) : strength
            }
            var day = adapt(composed, budget: sessionBudget, constraints: constraints)
            if let postponed = postponedTest(for: profile, constraints: constraints) {
                day.notes.insert(postponed, at: 0)
            }
            if profile.equipment == .gym, let last = constraints.lastStrengthDay,
               let pause = calendar.dateComponents([.day], from: calendar.startOfDay(for: last), to: calendar.startOfDay(for: date)).day,
               let comeback = StrengthProgress.comebackNote(pauseDays: pause) {
                day.notes.insert(comeback, at: 0)
            }
            if let intervals, case .workout(let workout) = day.kind, workout.exercises.contains(where: { $0.key == intervals.key }) {
                day.notes.insert("2 séances cette semaine : le fractionné se fait en fin de séance, pour garder force et cardio.", at: 0)
            }
            if let week = constraints.cycleWeek {
                day.notes.insert(StrengthCycle.note(for: week), at: 0)
            }
            return day
        case .conditioning:
            if let test = cardioTest(budget: budget, constraints: constraints) {
                return TrainingDay(kind: .workout(test), estimatedMinutes: test.estimatedMinutes, notes: [
                    "Test de cardio : ton temps et ton pouls à l'arrivée donnent ta forme cardio (VO2max) et ta zone de cardio modéré. La Watch les affiche ; à refaire toutes les 8 semaines.",
                ])
            }
            if let week = constraints.cycleWeek, week.program == .hyrox {
                let session = HyroxCycle.session(for: week, constraints: constraints)
                var day = adapt(HyroxCycle.workout(session, week: week, budget: budget, zone: constraints.cardio.moderateHeartRate), budget: budget, constraints: constraints)
                day.notes.insert(week.label, at: 0)
                return day
            }
            if let week = constraints.cycleWeek {
                let dayIndex = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
                let workout = CycleCardio.intervalsDue(week, equipment: profile.equipment, constraints: constraints)
                    ? CycleCardio.hardWorkout(for: week, budget: budget, equipment: profile.equipment)
                    : nil
                var day = adapt(
                    workout ?? CycleCardio.aerobicWorkout(week: week, budget: budget, equipment: profile.equipment, dayIndex: dayIndex, zone: constraints.cardio.moderateHeartRate),
                    budget: budget, constraints: constraints
                )
                day.notes.insert(week.label, at: 0)
                return day
            }
            var workout = conditioningWorkout(budget: budget, equipment: profile.equipment, on: date)
            if let zone = constraints.cardio.moderateHeartRate {
                workout.intensityCue = "Tout à allure modérée, entre \(zone.lowerBound) et \(zone.upperBound) battements par minute : tu peux parler, avec un léger essoufflement."
            }
            return adapt(workout, budget: budget, constraints: constraints)
        case .light:
            let minutes = max(min(budget, Self.lightWalkMinutes), 10)
            return TrainingDay(kind: .activeRest(title: "Marche tranquille", minutes: minutes), estimatedMinutes: minutes)
        case .rest:
            return TrainingDay(kind: .rest, estimatedMinutes: 0)
        }
    }

    /// Ajustements du jour (remplacements, déplacement, genou, fatigue, temps) dans des limites de sécurité.
    func adapt(_ composed: Workout, budget: Int, constraints: DayConstraints) -> TrainingDay {
        var notes: [String] = []
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
            notes.append("\(fittedNotePrefix) \(adapted.estimatedMinutes) min : l'essentiel est gardé.")
        }
        return TrainingDay(kind: .workout(adapted), estimatedMinutes: adapted.estimatedMinutes, notes: notes)
    }

    /// Mouvements de référence pas encore testés (salle seulement). Pas de test avec une douleur
    /// au genou, de la fatigue, ou trop peu de temps pour un mouvement : la séance habituelle suit.
    func strengthTest(for profile: UserProfile, budget: Int, constraints: DayConstraints) -> Workout? {
        guard profile.equipment == .gym, let calibrated = constraints.calibratedLifts,
              !constraints.kneePain, !constraints.lowEnergy,
              let test = StrengthCalibration.testWorkout(calibrated: calibrated, budget: budget),
              test.estimatedMinutes <= budget else { return nil }
        return test
    }

    /// Test de cardio à la place du cardio du jour : seulement en forme (pas de fatigue, de
    /// courbatures, de nuit courte ni de genou sensible) et avec assez de temps.
    func cardioTest(budget: Int, constraints: DayConstraints) -> Workout? {
        guard constraints.cardio.testDue, !constraints.lowEnergy, !constraints.sore, !constraints.kneePain,
              (constraints.sleepHours ?? Self.shortSleepHours) >= Self.shortSleepHours,
              budget >= CardioTest.minimumMinutes else { return nil }
        return CardioTest.workout()
    }

    /// Calibrage en attente mais pas proposé aujourd'hui : on dit pourquoi, et quand il reviendra.
    func postponedTest(for profile: UserProfile, constraints: DayConstraints) -> String? {
        guard profile.equipment == .gym, let calibrated = constraints.calibratedLifts,
              !StrengthCalibration.pending(calibrated: calibrated).isEmpty else { return nil }
        var reasons: [String] = []
        if constraints.lowEnergy { reasons.append("tu es fatigué") }
        if constraints.kneePain { reasons.append("ton genou est sensible") }
        if reasons.isEmpty { reasons.append("le temps manque") }
        return "Test de force reporté (\(reasons.joined(separator: ", "))) : il reviendra un prochain jour de force, quand tu seras en forme et disponible au moins 45 min."
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

    /// La séance de force qui suit la dernière faite (A puis B, ou A, B, C pendant un cycle
    /// en salle) ; sans historique, la A.
    func nextWorkout(after title: String?, for profile: UserProfile, on date: Date, cycleWeek: CycleWeek? = nil) -> Workout {
        // Hyrox : 2 séances de force par semaine au plus, rotation A / B.
        let sessions = cycleWeek.flatMap { week in
            profile.equipment == .gym && week.program == .crossfit ? WorkoutCatalog.cycleSessions(phase: week.phase) : nil
        }
            ?? WorkoutCatalog.sessions(for: profile.equipment)
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
            if !exercise.wave.isEmpty {
                // 5/3/1 : la vague reste, sans série au max ni séries « First Set Last ».
                lighter.wave = exercise.wave.map { WaveSet(reps: $0.reps, percentOfMax: $0.percentOfMax) }
                lighter.backoffSets = 0
                return lighter
            }
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
            // 5/3/1 : les séries « First Set Last » se raccourcissent avant le reste.
            { w in w.exercises = w.exercises.map { var e = $0; e.backoffSets = min(e.backoffSets, 3); return e } },
            { w in w.warmupMinutes = min(w.warmupMinutes, 3); w.cooldownMinutes = min(w.cooldownMinutes, 2) },
            // Le cardio et la marche (priorité 4) ne perdent pas de séries : ils sont retirés en premier si besoin.
            { w in w.exercises = w.exercises.map { var e = $0; if e.priority > 1 && e.priority < 4 { e.sets = min(e.sets, 2) }; return e } },
            { w in w.exercises = w.exercises.map { var e = $0; e.backoffSets = 0; return e } },
            // La vague 5/3/1 garde ses 3 séries : c'est la dernière qui compte.
            { w in w.exercises = w.exercises.map { var e = $0; if e.priority < 4 && e.wave.isEmpty { e.sets = min(e.sets, 2) }; return e } },
        ]
        // Séance de cardio seule en tours (fractionné, ateliers) : on retire des tours plutôt que
        // d'écourter l'échauffement ou les récupérations, qui font la qualité de l'effort.
        if !result.exercises.isEmpty && result.exercises.allSatisfy({ $0.priority >= 4 }) {
            while result.estimatedMinutes > budget,
                  let index = result.exercises.indices.filter({ result.exercises[$0].sets > 2 }).max(by: { result.exercises[$0].sets < result.exercises[$1].sets }) {
                result.exercises[index].sets -= 1
            }
        }
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
