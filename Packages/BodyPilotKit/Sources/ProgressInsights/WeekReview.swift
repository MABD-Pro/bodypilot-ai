import BodyPilotCore
import Foundation

/// Une journée passée telle que le coach la connaît : objectif, repas notés et pas.
public struct ReviewDayInput: Sendable, Equatable {
    public var day: Date
    /// Objectif du jour.
    public var target: Macros
    /// Ce qui a été mangé, d'après les repas notés (pris d'une touche ou décrits).
    public var eaten: Macros
    public var mealsNoted: Int
    public var mealsPlanned: Int
    /// Pas lus dans Santé ; `nil` : non mesurés.
    public var steps: Int?

    public init(day: Date, target: Macros, eaten: Macros, mealsNoted: Int, mealsPlanned: Int, steps: Int? = nil) {
        self.day = day
        self.target = target
        self.eaten = eaten
        self.mealsNoted = mealsNoted
        self.mealsPlanned = mealsPlanned
        self.steps = steps
    }
}

/// Aujourd'hui, pour les conseils du reste de la journée.
public struct ReviewToday: Sendable, Equatable {
    public var meals: DayMealPlan
    public var target: Macros
    public var training: TrainingDay
    public var workoutDone: Bool
    public var steps: Int?
    public var stepsGoal: Int?

    public init(meals: DayMealPlan, target: Macros, training: TrainingDay, workoutDone: Bool, steps: Int? = nil, stepsGoal: Int? = nil) {
        self.meals = meals
        self.target = target
        self.training = training
        self.workoutDone = workoutDone
        self.steps = steps
        self.stepsGoal = stepsGoal
    }
}

/// Calories d'une journée complète par rapport à l'objectif.
public enum KcalStatus: Sendable, Equatable {
    case under
    case onTarget
    case over
}

public struct ReviewDay: Sendable, Equatable, Identifiable {
    public var day: Date
    public var target: Macros
    public var eaten: Macros
    public var mealsNoted: Int
    public var mealsPlanned: Int
    /// Tous les repas notés : la journée compte dans les moyennes.
    public var isComplete: Bool
    public var activities: [WeekActivityEntry]
    public var activeMinutes: Double
    public var steps: Int?
    /// `nil` tant que la journée n'est pas complète.
    public var kcalStatus: KcalStatus?
    public var proteinReached: Bool?
    /// Une ligne pour la liste des jours.
    public var summary: String
    /// Le commentaire du coach sur la journée.
    public var comment: String
    public var id: Date { day }
}

/// Bilan des 7 derniers jours : nutrition, activité, encouragements et conseils.
public struct WeekReview: Sendable, Equatable {
    /// Les 7 jours, du plus ancien à aujourd'hui.
    public var days: [ReviewDay]
    /// Journées passées avec tous leurs repas notés (aujourd'hui exclu tant qu'il n'est pas bouclé).
    public var completeDays: Int
    /// Moyennes des journées complètes ; `nil` sans journée complète.
    public var averageEaten: Macros?
    public var averageTarget: Macros?
    public var proteinDays: Int
    public var kcalOnTargetDays: Int
    /// Séances (cochées ou de plus de 20 min dans Santé, marche exclue) et séances de force.
    public var sessions: Int
    public var strengthSessions: Int
    public var activeMinutes: Double
    /// Minutes d'endurance (force et mobilité exclues), à comparer au repère de l'OMS.
    public var enduranceMinutes: Double
    /// Moyenne des pas des jours passés mesurés.
    public var averageSteps: Double?
    /// L'encouragement du coach, en une phrase.
    public var headline: String
    /// Ce qui a été bien fait.
    public var wins: [String]
    /// Pour le reste de la journée.
    public var restOfDay: [String]
    /// Pour le reste de la semaine.
    public var restOfWeek: [String]
    /// Tous les conseils de la semaine avec leur sujet, avant la limite de 3 (voir `priorities`).
    public var weekAdvice: [WeekAdvice] = []
}

public struct WeekReviewer: Sendable {
    public var calendar: Calendar

    public static let days = 7
    /// Calories dans la cible : de 15 % en dessous à 10 % au-dessus de l'objectif (choix BodyPilot :
    /// les repas notés d'une touche sont des estimations, une marge plus serrée serait du bruit).
    static let kcalLow = 0.85
    static let kcalHigh = 1.10
    /// Protéines atteintes à 90 % de l'objectif (même raison).
    static let proteinReached = 0.90
    /// Fibres : sous 80 % de l'objectif en moyenne, le coach le signale (choix BodyPilot).
    static let fiberReached = 0.8
    /// Minimum recommandé par l'OMS (2020) pour les adultes : 150 min d'activité modérée et
    /// 2 jours de renforcement musculaire par semaine.
    public static let activeMinutesGoal = 150.0
    public static let strengthGoal = 2
    /// Au moins 3 journées complètes pour juger la nutrition de la semaine.
    static let minimumCompleteDays = 3
    static let maxAdvice = 3

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// - Parameters:
    ///   - days: les journées de la période (une par jour au plus), aujourd'hui compris.
    ///   - completed: séances cochées dans l'app, avec leur titre.
    ///   - sessionMinutes: durée prévue d'une séance, pour une séance cochée sans trace dans Santé.
    public func review(
        days inputs: [ReviewDayInput],
        samples: [ActivitySample],
        completed: [(day: Date, title: String?)],
        sessionMinutes: Int,
        today: ReviewToday,
        on date: Date
    ) -> WeekReview {
        let todayStart = calendar.startOfDay(for: date)
        let start = calendar.date(byAdding: .day, value: -(Self.days - 1), to: todayStart) ?? todayStart
        let end = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? date
        let analyzer = WeekActivityAnalyzer(calendar: calendar)
        let entries = analyzer.entries(
            in: DateInterval(start: start, end: end), until: date, samples: samples, completed: completed, sessionMinutes: sessionMinutes
        )

        let days: [ReviewDay] = (0..<Self.days).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let input = inputs.first { calendar.isDate($0.day, inSameDayAs: day) }
                ?? ReviewDayInput(day: day, target: inputs.last?.target ?? .zero, eaten: .zero, mealsNoted: 0, mealsPlanned: 4)
            let activities = entries.filter { calendar.isDate($0.start, inSameDayAs: day) }
            return reviewDay(input, day: day, activities: activities, isToday: offset == Self.days - 1)
        }

        let past = days.filter { $0.day < todayStart }
        let complete = days.filter(\.isComplete)
        let averageEaten = average(complete.map(\.eaten))
        let averageTarget = average(complete.map(\.target))
        let sessionEntries = entries.filter { !$0.fromHealth || analyzer.countsAsSession(sample($0)) }
        let strength = sessionEntries.filter { $0.kind == .strength }.count
        let activeMinutes = entries.reduce(0) { $0 + $1.minutes }
        let enduranceMinutes = entries.filter { $0.kind != .strength && $0.kind != .mobility }.reduce(0) { $0 + $1.minutes }
        let stepDays = past.compactMap(\.steps).filter { $0 > 0 }
        let averageSteps = stepDays.isEmpty ? nil : Double(stepDays.reduce(0, +)) / Double(stepDays.count)

        var review = WeekReview(
            days: days,
            completeDays: complete.count,
            averageEaten: averageEaten,
            averageTarget: averageTarget,
            proteinDays: complete.filter { $0.proteinReached == true }.count,
            kcalOnTargetDays: complete.filter { $0.kcalStatus == .onTarget }.count,
            sessions: sessionEntries.count,
            strengthSessions: strength,
            activeMinutes: activeMinutes,
            enduranceMinutes: enduranceMinutes,
            averageSteps: averageSteps,
            headline: "",
            wins: [],
            restOfDay: [],
            restOfWeek: []
        )
        review.wins = wins(review, stepsGoal: today.stepsGoal)
        // Moins de 3 journées complètes et aucune séance : trop peu pour juger la semaine.
        let hasData = review.completeDays >= Self.minimumCompleteDays || !entries.isEmpty
        review.headline = headline(wins: review.wins.count, hasData: hasData)
        review.restOfDay = restOfDay(today)
        review.weekAdvice = weekAdvice(review, today: today, samples: samples, completed: completed, sessionMinutes: sessionMinutes, on: date)
        review.restOfWeek = Array(review.weekAdvice.map(\.text).prefix(Self.maxAdvice))
        return review
    }

    /// Une activité de Santé relue comme échantillon, pour la règle des 20 minutes.
    private func sample(_ entry: WeekActivityEntry) -> ActivitySample {
        ActivitySample(id: entry.id, kind: entry.kind, start: entry.start, minutes: entry.minutes, kcal: entry.kcal)
    }

    private func average(_ values: [Macros]) -> Macros? {
        guard !values.isEmpty else { return nil }
        return values.reduce(.zero, +).scaled(by: 1 / Double(values.count))
    }

    // MARK: - Une journée

    func reviewDay(_ input: ReviewDayInput, day: Date, activities: [WeekActivityEntry], isToday: Bool) -> ReviewDay {
        let isComplete = input.mealsPlanned > 0 && input.mealsNoted >= input.mealsPlanned
        var status: KcalStatus?
        var protein: Bool?
        if isComplete, input.target.kcal > 0 {
            let ratio = input.eaten.kcal / input.target.kcal
            status = ratio < Self.kcalLow ? .under : ratio > Self.kcalHigh ? .over : .onTarget
            protein = input.target.proteinG <= 0 || input.eaten.proteinG >= input.target.proteinG * Self.proteinReached
        }
        let minutes = activities.reduce(0) { $0 + $1.minutes }
        return ReviewDay(
            day: day,
            target: input.target,
            eaten: input.eaten,
            mealsNoted: input.mealsNoted,
            mealsPlanned: input.mealsPlanned,
            isComplete: isComplete,
            activities: activities,
            activeMinutes: minutes,
            steps: input.steps,
            kcalStatus: status,
            proteinReached: protein,
            summary: summary(input, isComplete: isComplete, activities: activities),
            comment: comment(input, status: status, protein: protein, activities: activities, isToday: isToday)
        )
    }

    func summary(_ input: ReviewDayInput, isComplete: Bool, activities: [WeekActivityEntry]) -> String {
        var parts: [String] = []
        if input.mealsNoted == 0 {
            parts.append("Repas non notés")
        } else if isComplete {
            parts.append("\(input.eaten.kcal.frenchInteger) / \(input.target.kcal.frenchInteger) kcal")
        } else {
            parts.append("\(input.eaten.kcal.frenchInteger) kcal, \(input.mealsNoted) repas sur \(input.mealsPlanned)")
        }
        if let first = activities.last {
            parts.append(activities.count > 1 ? "\(first.title) +\(activities.count - 1)" : first.title)
        }
        return parts.joined(separator: " · ")
    }

    func comment(_ input: ReviewDayInput, status: KcalStatus?, protein: Bool?, activities: [WeekActivityEntry], isToday: Bool) -> String {
        var sentences: [String] = []
        switch status {
        case .onTarget:
            sentences.append(protein == true
                ? "Calories dans la cible et protéines atteintes : la journée type qui fait avancer."
                : "Calories dans la cible. Protéines un peu justes (\(percent(input.eaten.proteinG, of: input.target.proteinG)) de l'objectif) : c'est elles qui protègent le muscle.")
        case .over:
            let over = input.eaten.kcal - input.target.kcal
            sentences.append("\(over.frenchInteger) kcal au-dessus de l'objectif. Une journée ne change rien : c'est la moyenne de la semaine qui compte.")
        case .under:
            let under = input.target.kcal - input.eaten.kcal
            sentences.append("\(under.frenchInteger) kcal sous l'objectif. Manger trop peu fatigue et coûte du muscle : mieux vaut un déficit tenable.")
        case nil:
            if input.mealsNoted == 0 {
                sentences.append(isToday ? "Aucun repas noté pour l'instant." : "Aucun repas noté ce jour-là.")
            } else {
                sentences.append(isToday
                    ? "\(input.mealsNoted) repas sur \(input.mealsPlanned) notés pour l'instant."
                    : "\(input.mealsNoted) repas sur \(input.mealsPlanned) notés : la journée ne compte pas dans les moyennes.")
            }
        }
        if activities.contains(where: { $0.kind == .strength }) {
            sentences.append("Séance de force faite.")
        } else if !activities.isEmpty {
            sentences.append("\(WeekActivityAnalyzer.duration(activities.reduce(0) { $0 + $1.minutes })) d'activité.")
        } else if !isToday {
            sentences.append("Journée sans séance : la récupération fait aussi partie du plan.")
        }
        return sentences.joined(separator: " ")
    }

    private func percent(_ value: Double, of target: Double) -> String {
        guard target > 0 else { return "–" }
        return "\(Int((value / target * 100).rounded())) %"
    }

    // MARK: - Encouragements

    func wins(_ review: WeekReview, stepsGoal: Int?) -> [String] {
        var wins: [String] = []
        let strength = review.strengthSessions
        if strength >= Self.strengthGoal {
            wins.append("\(strength) séances de force en 7 jours : c'est ce qui garde ton muscle pendant que le gras part.")
        } else if review.sessions >= 3 {
            wins.append("\(review.sessions) séances en 7 jours : la régularité est là.")
        }
        if review.enduranceMinutes >= Self.activeMinutesGoal {
            wins.append("\(WeekActivityAnalyzer.duration(review.enduranceMinutes)) d'endurance (cardio, marche, sport) : le repère de l'OMS de 150 min est atteint.")
        }
        if review.completeDays >= Self.minimumCompleteDays {
            if review.proteinDays * 2 >= review.completeDays, review.proteinDays > 0 {
                wins.append("Protéines atteintes \(review.proteinDays) jour\(review.proteinDays > 1 ? "s" : "") sur \(review.completeDays).")
            }
            if review.kcalOnTargetDays * 2 >= review.completeDays, review.kcalOnTargetDays > 0 {
                wins.append("\(review.kcalOnTargetDays) journée\(review.kcalOnTargetDays > 1 ? "s" : "") dans ta cible de calories.")
            }
        }
        if review.completeDays >= Self.days - 1 {
            wins.append("Tous tes repas notés chaque jour : ton coach n'a jamais été aussi précis.")
        }
        if let average = review.averageSteps, let stepsGoal, average >= Double(stepsGoal) {
            wins.append("\(StepActivity.displayed(average).frenchInteger) pas par jour en moyenne : objectif tenu.")
        }
        return wins
    }

    static let hardWeekHeadline = "Semaine plus difficile, ça arrive à tout le monde. On repart simple, dès aujourd'hui."

    func headline(wins: Int, hasData: Bool) -> String {
        guard hasData else {
            return "Ton bilan se remplit au fil des jours : note tes repas d'une touche et coche tes séances, le coach fait le reste."
        }
        switch wins {
        case 3...: return "Très belle semaine : tu tiens le cap sur tous les fronts. Continue exactement comme ça."
        case 1...2: return "De bonnes bases cette semaine. Un ou deux réglages, et ça avance encore mieux."
        default: return Self.hardWeekHeadline
        }
    }

    // MARK: - Conseils

    func restOfDay(_ today: ReviewToday) -> [String] {
        var advice: [String] = []
        let eaten = today.meals.eatenTotals
        let remaining = today.meals.meals.filter { !$0.isEaten }
        if remaining.isEmpty {
            let missing = today.target.proteinG - eaten.proteinG
            if eaten.kcal > 0, missing > 15 {
                advice.append("Repas notés. Il manque environ \(missing.frenchInteger) g de protéines : un skyr ou un verre de lait ce soir comble l'écart.")
            } else if eaten.kcal > 0 {
                advice.append("Journée de repas bouclée. Rien à ajouter, bravo.")
            }
        } else if eaten.kcal >= today.target.kcal {
            advice.append("Objectif de calories déjà atteint : pour la suite, des légumes et une protéine maigre si la faim revient.")
        } else {
            let planned = remaining.reduce(Macros.zero) { $0 + $1.macros }
            let next = remaining[0]
            let count = remaining.count
            advice.append("Encore \(count) repas, environ \(planned.kcal.frenchInteger) kcal et \(planned.proteinG.frenchInteger) g de protéines. Prochain : \(next.title.lowercasedFirst).")
        }

        switch today.training.kind {
        case .workout(let workout) where !today.workoutDone:
            advice.append("Ta séance t'attend : \(workout.title.lowercasedFirst), \(today.training.estimatedMinutes) min. Même une version courte compte.")
        case .activeRest(let title, let minutes) where !today.workoutDone:
            advice.append("Au programme : \(title.lowercasedFirst), \(minutes) min.")
        case .rest where !today.workoutDone:
            advice.append("Repos aujourd'hui : une marche tranquille aide à récupérer sans fatiguer.")
        default:
            advice.append("Séance du jour faite : bois, mange tes protéines et dors bien, c'est là que le muscle se construit.")
        }

        if let steps = today.steps, let goal = today.stepsGoal, steps < goal {
            advice.append("Encore \(Double(goal - steps).frenchInteger) pas pour ton objectif du jour (\(Double(goal).frenchInteger)).")
        }
        return advice
    }

    /// Conseils de la semaine, chacun avec son sujet (pour les 3 priorités, voir `priorities`).
    func weekAdvice(
        _ review: WeekReview,
        today: ReviewToday,
        samples: [ActivitySample],
        completed: [(day: Date, title: String?)],
        sessionMinutes: Int,
        on date: Date
    ) -> [WeekAdvice] {
        var advice: [WeekAdvice] = []

        // Force : le repère de l'OMS se compte sur la semaine du calendrier, 48 h entre deux séances.
        if let week = calendar.dateInterval(of: .weekOfYear, for: date) {
            let analyzer = WeekActivityAnalyzer(calendar: calendar)
            let thisWeek = analyzer.entries(in: week, until: date, samples: samples, completed: completed, sessionMinutes: sessionMinutes)
            let done = Set(thisWeek.filter { $0.kind == .strength && (!$0.fromHealth || analyzer.countsAsSession(sample($0))) }.map { calendar.startOfDay(for: $0.start) }).count
            let todayStart = calendar.startOfDay(for: date)
            let lastDay = calendar.date(byAdding: .day, value: -1, to: week.end) ?? todayStart
            let daysLeft = (calendar.dateComponents([.day], from: todayStart, to: lastDay).day ?? 0) + (today.workoutDone ? 0 : 1)
            let slots = (daysLeft + 1) / 2
            let needed = Self.strengthGoal - done
            if needed > 0, slots > 0 {
                if done == 1 {
                    advice.append(WeekAdvice(.strength, "Force : 1 séance depuis lundi. Une de plus d'ici dimanche pour le minimum recommandé de 2 par semaine (OMS)."))
                } else if slots >= 2 {
                    advice.append(WeekAdvice(.strength, "Force : pas encore de séance depuis lundi. Places-en 2 d'ici dimanche, avec 48\u{00A0}h entre les deux (minimum recommandé par l'OMS)."))
                } else {
                    advice.append(WeekAdvice(.strength, "Force : pas encore de séance depuis lundi. Fais-en au moins une d'ici dimanche ; la régularité se juge sur plusieurs semaines."))
                }
            }
        }

        if review.completeDays < Self.minimumCompleteDays {
            advice.append(WeekAdvice(.logging, "Note tes repas d'une touche (« Comme prévu » suffit) : avec \(review.completeDays) journée\(review.completeDays > 1 ? "s" : "") complète\(review.completeDays > 1 ? "s" : "") sur 7, le bilan de calories reste partiel."))
        } else if let eaten = review.averageEaten, let target = review.averageTarget {
            if target.proteinG > 0, eaten.proteinG < target.proteinG * Self.proteinReached {
                advice.append(WeekAdvice(.protein, "Protéines : \(eaten.proteinG.frenchInteger) g par jour en moyenne pour \(target.proteinG.frenchInteger) g visés. Ajoute une portion (skyr, œufs, thon, poulet) au repas qui en manque le plus."))
            }
            if target.kcal > 0, eaten.kcal > target.kcal * Self.kcalHigh {
                let worst = review.days.filter { $0.kcalStatus == .over }.max { ($0.eaten.kcal - $0.target.kcal) < ($1.eaten.kcal - $1.target.kcal) }
                let detail = worst.map { ", surtout \(weekday($0.day)) (+\(($0.eaten.kcal - $0.target.kcal).frenchInteger))" } ?? ""
                advice.append(WeekAdvice(.kcalOver, "Calories : \((eaten.kcal - target.kcal).frenchInteger) kcal par jour au-dessus de l'objectif en moyenne\(detail). Repère le repas en cause dans le détail du jour."))
            } else if target.kcal > 0, eaten.kcal < target.kcal * Self.kcalLow {
                advice.append(WeekAdvice(.kcalUnder, "Tu manges en moyenne \((target.kcal - eaten.kcal).frenchInteger) kcal de moins que prévu. Un déficit trop fort fatigue et coûte du muscle : garde la collation."))
            }
            if target.fiberG > 0, eaten.fiberG < target.fiberG * Self.fiberReached {
                advice.append(WeekAdvice(.fiber, "Fibres : \(eaten.fiberG.frenchInteger) g par jour en moyenne pour \(target.fiberG.frenchInteger) g visés (ANSES). Un légume de plus à chaque repas, un fruit entier et des légumineuses deux fois par semaine."))
            }
        }

        if review.enduranceMinutes < Self.activeMinutesGoal {
            advice.append(WeekAdvice(.endurance, "\(WeekActivityAnalyzer.duration(review.enduranceMinutes)) d'endurance en 7 jours, pour 150 min recommandées par l'OMS : 20 min de marche rapide par jour comblent l'écart."))
        }

        if let average = review.averageSteps, let goal = today.stepsGoal, average < Double(goal) - 500 {
            advice.append(WeekAdvice(.steps, "Pas : environ \(StepActivity.displayed(average).frenchInteger) par jour. Vise \(Double(goal).frenchInteger) : 10 min de marche après un repas en ajoutent environ 1\u{202F}000."))
        }

        if advice.isEmpty {
            advice.append(WeekAdvice(.none, "Rien à corriger : garde ce rythme, c'est lui qui donne les résultats."))
        }
        return advice
    }

    /// « mardi ».
    func weekday(_ date: Date) -> String {
        let names = ["dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]
        return names[(calendar.component(.weekday, from: date) - 1) % 7]
    }
}

extension String {
    /// « Full body A » → « full body A », pour un titre repris dans une phrase.
    var lowercasedFirst: String {
        guard let first else { return self }
        return first.lowercased() + dropFirst()
    }
}
