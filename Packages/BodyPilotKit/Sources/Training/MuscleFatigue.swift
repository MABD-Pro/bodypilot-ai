import BodyPilotCore
import Foundation

/// Groupes musculaires suivis par la carte de fatigue.
public enum MuscleGroup: String, CaseIterable, Sendable, Codable {
    case quadriceps, hamstrings, glutes, chest, back, shoulders, arms, core, calves

    public var label: String {
        switch self {
        case .quadriceps: "Quadriceps"
        case .hamstrings: "Ischio-jambiers"
        case .glutes: "Fessiers"
        case .chest: "Pectoraux"
        case .back: "Dos"
        case .shoulders: "Épaules"
        case .arms: "Bras"
        case .core: "Abdos"
        case .calves: "Mollets"
        }
    }

    /// Muscles d'un intitulé de fiche (« Quadriceps », « haut des pectoraux », « jambes »…) :
    /// les zones de la silhouette, ramenées à leur groupe.
    static func groups(in text: String) -> [MuscleGroup] {
        MuscleRegion.regions(in: text).map(\.group).reduce(into: [MuscleGroup]()) { if !$0.contains($1) { $0.append($1) } }
    }
}

/// Muscles d'un exercice : le premier de la fiche travaille le plus, les suivants en appoint.
public struct ExerciseMuscles: Sendable, Equatable {
    public var primary: [MuscleGroup]
    public var secondary: [MuscleGroup]

    public static func of(_ exercise: String) -> ExerciseMuscles? {
        guard let guide = ExerciseGuide.guide(for: exercise) else { return nil }
        // « Corps entier : jambes, pectoraux… » : la liste commence après les deux-points.
        let list = guide.muscles.split(separator: ":").last.map(String.init) ?? guide.muscles
        let parts = list.split(separator: ",").map { String($0) }
        guard let first = parts.first else { return nil }
        let primary = MuscleGroup.groups(in: first)
        let secondary = parts.dropFirst().flatMap { MuscleGroup.groups(in: $0) }
            .reduce(into: [MuscleGroup]()) { if !$0.contains($1) && !primary.contains($1) { $0.append($1) } }
        return primary.isEmpty && secondary.isEmpty ? nil : ExerciseMuscles(primary: primary, secondary: secondary)
    }
}

public enum MuscleState: Int, Sendable, Comparable, CaseIterable {
    case fresh, recovering, fatigued

    public static func < (lhs: MuscleState, rhs: MuscleState) -> Bool { lhs.rawValue < rhs.rawValue }

    public var label: String {
        switch self {
        case .fresh: "Frais"
        case .recovering: "En récupération"
        case .fatigued: "Fatigués"
        }
    }
}

/// État de chaque groupe musculaire.
public struct MuscleFatigueMap: Sendable, Equatable {
    /// Charge restante par groupe, en séries équivalentes.
    public var load: [MuscleGroup: Double]

    public func state(_ group: MuscleGroup) -> MuscleState {
        let value = load[group] ?? 0
        if value >= MuscleFatigue.fatiguedLoad { return .fatigued }
        if value >= MuscleFatigue.recoveringLoad { return .recovering }
        return .fresh
    }

    public func groups(_ state: MuscleState) -> [MuscleGroup] {
        MuscleGroup.allCases.filter { self.state($0) == state }
    }

    /// Rien de noté ces trois derniers jours : la carte n'a rien à dire.
    public var isEmpty: Bool { MuscleGroup.allCases.allSatisfy { state($0) == .fresh } }
}

/// Fatigue par muscle à partir des séries notées : chaque exercice noté compte pour
/// `setsPerExercise` séries (la note garde la meilleure série, pas leur nombre), pleinement sur
/// les muscles principaux et pour moitié sur les autres, plus si l'effort était dur.
/// La fatigue s'efface en environ 72 h : la force revient en 48 à 72 h après une séance lourde
/// (Morán-Navarro et al., 2017, cité de mémoire, à vérifier). Seuils : choix BodyPilot.
public enum MuscleFatigue {
    public static let setsPerExercise = 3.0
    public static let secondaryShare = 0.5
    /// Part qui reste le jour même, le lendemain, le surlendemain ; ensuite plus rien.
    public static let remaining: [Double] = [1.0, 0.6, 0.3]
    public static let fatiguedLoad = 3.0
    public static let recoveringLoad = 1.5

    static func effortFactor(_ effort: SetEffort?) -> Double {
        switch effort {
        case .easy: 0.8
        case .hard: 1.2
        default: 1.0
        }
    }

    public static func map(lifts: [LiftEntry], on date: Date, calendar: Calendar) -> MuscleFatigueMap {
        let today = calendar.startOfDay(for: date)
        var load: [MuscleGroup: Double] = [:]
        for lift in lifts {
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: lift.date), to: today).day ?? .max
            guard days >= 0, days < remaining.count, let muscles = ExerciseMuscles.of(lift.exercise) else { continue }
            let sets = setsPerExercise * effortFactor(lift.effort) * remaining[days]
            for group in muscles.primary { load[group, default: 0] += sets }
            for group in muscles.secondary { load[group, default: 0] += sets * secondaryShare }
        }
        return MuscleFatigueMap(load: load)
    }

    /// Muscles principaux de la séance du jour encore fatigués : à prévenir avant de commencer.
    public static func fatiguedTargets(of workout: Workout, in map: MuscleFatigueMap) -> [MuscleGroup] {
        let targets = workout.exercises.compactMap { ExerciseMuscles.of($0.name)?.primary }.flatMap { $0 }
        return MuscleGroup.allCases.filter { targets.contains($0) && map.state($0) == .fatigued }
    }
}
