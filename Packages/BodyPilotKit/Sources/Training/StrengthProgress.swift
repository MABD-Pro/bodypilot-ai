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

    /// Surcharge progressive (ACSM, 2009) : quand la série dépasse d'au moins une répétition
    /// ce qui était prévu, la charge monte de 2 à 10 % ; sinon on garde la charge et on vise
    /// les répétitions prévues. Au poids du corps, on vise une répétition de plus.
    /// Après un test, la charge de travail se déduit du 1RM estimé ; sans série notée,
    /// de celui du mouvement de référence.
    public static func target(for exercise: String, plannedReps: Int, history: [LiftEntry]) -> LiftTarget? {
        guard let last = history.filter({ $0.exercise == exercise }).max(by: { $0.date < $1.date }) else {
            return StrengthCalibration.derivedLoad(for: exercise, plannedReps: plannedReps, history: history)
                .map { LiftTarget(kg: $0, reps: plannedReps, isIncrease: false) }
        }
        if last.isTest, let kg = last.kg, kg > 0 {
            let load = StrengthCalibration.workingLoad(oneRepMax: estimatedOneRepMax(kg: kg, reps: last.reps), reps: plannedReps)
            return LiftTarget(kg: load, reps: plannedReps, isIncrease: false)
        }
        guard let kg = last.kg, kg > 0 else {
            let beat = last.reps >= plannedReps
            return LiftTarget(kg: nil, reps: beat ? last.reps + 1 : plannedReps, isIncrease: beat)
        }
        if last.reps > plannedReps {
            return LiftTarget(kg: kg + increment(from: kg), reps: plannedReps, isIncrease: true)
        }
        return LiftTarget(kg: kg, reps: plannedReps, isIncrease: false)
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
