import BodyPilotCore
import Foundation

/// Meilleure performance sur un exercice.
public struct PersonalRecord: Sendable, Equatable {
    public var entry: LiftEntry
    /// 1RM estimé avec une charge, nombre de répétitions au poids du corps.
    public var score: Double

    public init(entry: LiftEntry, score: Double) {
        self.entry = entry
        self.score = score
    }
}

/// Objectif de la prochaine série notée.
public struct LiftTarget: Sendable, Equatable {
    public var kg: Double?
    public var reps: Int
    /// Charge ou répétitions en hausse par rapport à la dernière fois.
    public var isIncrease: Bool

    public init(kg: Double?, reps: Int, isIncrease: Bool) {
        self.kg = kg
        self.reps = reps
        self.isIncrease = isIncrease
    }
}

/// Records et surcharge progressive, à partir de la meilleure série notée à chaque séance.
public enum StrengthProgress {
    /// Au-delà, les formules d'estimation du 1RM deviennent trop imprécises.
    static let maxRepsForEstimate = 12

    /// 1RM estimé (formule d'Epley).
    public static func estimatedOneRepMax(kg: Double, reps: Int) -> Double {
        guard reps > 1 else { return kg }
        return kg * (1 + Double(min(reps, maxRepsForEstimate)) / 30)
    }

    public static func score(_ entry: LiftEntry) -> Double {
        if let kg = entry.kg, kg > 0 { return estimatedOneRepMax(kg: kg, reps: entry.reps) }
        return Double(entry.reps)
    }

    /// « 80 kg × 6 », « 15 rép. ».
    public static func label(_ entry: LiftEntry) -> String {
        label(kg: entry.kg, reps: entry.reps)
    }

    public static func label(kg: Double?, reps: Int) -> String {
        if let kg, kg > 0 { return "\(kg.frenchCompact) kg × \(reps)" }
        return "\(reps) rép."
    }

    /// Meilleure série de l'exercice. Une série avec charge passe devant le poids du corps :
    /// les deux ne se comparent pas, et la charge est la progression visée.
    public static func record(for exercise: String, in history: [LiftEntry]) -> PersonalRecord? {
        let entries = history.filter { $0.exercise == exercise }
        let weighted = entries.filter { ($0.kg ?? 0) > 0 }
        let pool = weighted.isEmpty ? entries : weighted
        // À score égal, la plus ancienne reste le record : il faut faire mieux pour le battre.
        guard let best = pool.sorted(by: { $0.date < $1.date }).max(by: { score($0) < score($1) }) else { return nil }
        return PersonalRecord(entry: best, score: score(best))
    }

    /// Records de chaque exercice, les plus récents d'abord.
    public static func records(in history: [LiftEntry]) -> [PersonalRecord] {
        Set(history.map(\.exercise))
            .compactMap { record(for: $0, in: history) }
            .sorted { $0.entry.date > $1.entry.date }
    }

    /// La série bat tout ce qui a été noté avant. Une première série n'est pas un record.
    public static func isRecord(_ entry: LiftEntry, previous: [LiftEntry]) -> Bool {
        let before = previous.filter { $0.exercise == entry.exercise && $0.date < entry.date }
        let isWeighted = (entry.kg ?? 0) > 0
        let comparable = before.filter { (($0.kg ?? 0) > 0) == isWeighted }
        guard let best = comparable.map(score).max() else { return false }
        return score(entry) > best
    }

    /// Force gardée après une pause sans séance de force : la force maximale se maintient
    /// environ 3 semaines (Bosquet et al., 2013), puis baisse lentement. Paliers prudents, pas
    /// des résultats d'étude : un max ancien ne doit pas donner une charge qu'on ne tient plus.
    public static func retention(afterDays days: Int) -> Double {
        switch days {
        case ..<22: 1
        case ..<43: 0.95
        case ..<91: 0.9
        default: 0.85
        }
    }

    /// Au-delà, les charges notées ne disent plus grand-chose : un nouveau test de force est proposé.
    public static let retestAfterDays = 90

    /// Dernière séance de force : la plus récente des séries notées (tous exercices) et des
    /// séances de force connues par ailleurs (cochées dans l'app, Santé).
    static func lastTraining(history: [LiftEntry], lastStrengthDay: Date?) -> Date? {
        ([lastStrengthDay].compactMap { $0 } + history.map(\.date)).max()
    }

    /// Jours sans séance de force jusqu'à `date`.
    public static func pauseDays(history: [LiftEntry], lastStrengthDay: Date?, on date: Date, calendar: Calendar = .current) -> Int? {
        guard let last = lastTraining(history: history, lastStrengthDay: lastStrengthDay) else { return nil }
        return days(from: last, to: date, calendar: calendar)
    }

    /// Force de référence d'un exercice (1RM estimé, en kg) : le meilleur max noté, pondéré par
    /// son ancienneté au moment de la dernière séance (un max d'il y a trois mois compte moins
    /// qu'une série de la semaine), puis par la pause depuis cette séance. Les deux durées se
    /// suivent sans se recouvrir : rien n'est compté deux fois.
    public static func referenceOneRepMax(
        for exercise: String,
        history: [LiftEntry],
        lastStrengthDay: Date? = nil,
        on date: Date? = nil,
        calendar: Calendar = .current
    ) -> Double? {
        let weighted = history.filter { $0.exercise == exercise && ($0.kg ?? 0) > 0 }
        guard !weighted.isEmpty, let last = lastTraining(history: history, lastStrengthDay: lastStrengthDay) else { return nil }
        let best = weighted.map { score($0) * retention(afterDays: days(from: $0.date, to: last, calendar: calendar)) }.max() ?? 0
        let pause = date.map { days(from: last, to: $0, calendar: calendar) } ?? 0
        return best * retention(afterDays: pause)
    }

    /// Charges de travail à partir du max pondéré (2 répétitions en réserve), puis surcharge
    /// progressive (ACSM, 2009) : quand la série dépasse d'au moins une répétition ce qui était
    /// prévu, la charge monte de 2 à 10 %. Après une pause de plus de 3 semaines, on repart du
    /// max pondéré, sans hausse. Au poids du corps, on vise une répétition de plus.
    /// Sans série notée, la charge vient du mouvement de référence.
    /// Sans `date`, aucune pause n'est comptée.
    public static func target(
        for exercise: String,
        plannedReps: Int,
        history: [LiftEntry],
        lastStrengthDay: Date? = nil,
        on date: Date? = nil,
        calendar: Calendar = .current
    ) -> LiftTarget? {
        guard let last = history.filter({ $0.exercise == exercise }).max(by: { $0.date < $1.date }) else {
            return StrengthCalibration.derivedLoad(for: exercise, plannedReps: plannedReps, history: history, lastStrengthDay: lastStrengthDay, on: date, calendar: calendar)
                .map { LiftTarget(kg: $0, reps: plannedReps, isIncrease: false) }
        }
        guard let kg = last.kg, kg > 0 else {
            let beat = last.reps >= plannedReps
            return LiftTarget(kg: nil, reps: beat ? last.reps + 1 : plannedReps, isIncrease: beat)
        }
        let reference = referenceOneRepMax(for: exercise, history: history, lastStrengthDay: lastStrengthDay, on: date, calendar: calendar) ?? score(last)
        let fromMax = StrengthCalibration.workingLoad(oneRepMax: reference, reps: plannedReps)
        let pause = date.flatMap { pauseDays(history: history, lastStrengthDay: lastStrengthDay, on: $0, calendar: calendar) } ?? 0
        if last.isTest || retention(afterDays: pause) < 1 {
            return LiftTarget(kg: fromMax, reps: plannedReps, isIncrease: false)
        }
        let progressed = last.reps > plannedReps ? kg + increment(from: kg) : kg
        let load = max(progressed, fromMax)
        return LiftTarget(kg: load, reps: plannedReps, isIncrease: load > kg)
    }

    /// Note de reprise sous le titre de la séance de force, après plus de 3 semaines sans force.
    public static func comebackNote(pauseDays days: Int) -> String? {
        let kept = retention(afterDays: days)
        guard kept < 1 else { return nil }
        let weeks = days / 7
        return "Reprise après \(weeks) semaines sans force : charges à \(Int((kept * 100).rounded())) % de tes max. Elles remontent vite, la force revient plus vite qu'elle ne s'est construite."
    }

    private static func days(from start: Date, to end: Date, calendar: Calendar) -> Int {
        max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: end)).day ?? 0)
    }

    /// Environ 5 % de la charge, arrondi aux disques (2,5 kg) ou, sous 30 kg, aux haltères (1 kg).
    public static func increment(from kg: Double) -> Double {
        let step = loadStep(for: kg)
        return max(step, (kg * 0.05 / step).rounded() * step)
    }

    /// Pas de réglage de la charge dans la saisie.
    public static func loadStep(for kg: Double) -> Double {
        kg < 30 ? 1 : 2.5
    }
}
