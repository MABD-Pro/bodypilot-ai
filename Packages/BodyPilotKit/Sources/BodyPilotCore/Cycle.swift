import Foundation

/// Cycle d'entraînement de 12 semaines choisi par l'utilisateur.
public enum CycleProgram: String, Sendable, Codable, CaseIterable {
    /// Montée en puissance vers le CrossFit (docs/COACH_RULES.md, « Cycle de 12 semaines »).
    case crossfit

    public var title: String {
        switch self {
        case .crossfit: "Cycle CrossFit"
        }
    }
}

/// Où l'on en est dans le cycle : 3 phases de 4 semaines, la 4ᵉ de chaque phase allégée.
public struct CycleWeek: Sendable, Equatable {
    public var program: CycleProgram
    /// 1 à 12.
    public var number: Int

    public init(program: CycleProgram, number: Int) {
        self.program = program
        self.number = number
    }

    /// 1 à 3.
    public var phase: Int { (number - 1) / TrainingCycle.weeksPerPhase + 1 }
    /// 1 à 4 dans la phase.
    public var weekInPhase: Int { (number - 1) % TrainingCycle.weeksPerPhase + 1 }
    public var isDeload: Bool { weekInPhase == TrainingCycle.weeksPerPhase }

    public var phaseTitle: String {
        switch phase {
        case 1: "base"
        case 2: "puissance"
        default: "conditioning"
        }
    }

    /// « Cycle CrossFit · semaine 3 sur 12 · phase 1, base ».
    public var label: String {
        "\(program.title) · semaine \(number) sur \(TrainingCycle.weeks)\(isDeload ? " (allégée)" : "") · phase \(phase), \(phaseTitle)"
    }
}

/// Cycle commencé un jour donné ; les semaines se comptent depuis ce jour.
public struct TrainingCycle: Sendable, Equatable, Codable {
    public static let weeks = 12
    public static let weeksPerPhase = 4

    public var program: CycleProgram
    public var startDate: Date

    public init(program: CycleProgram, startDate: Date) {
        self.program = program
        self.startDate = startDate
    }

    /// Semaine du cycle ce jour-là ; `nil` avant le début ou une fois les 12 semaines finies.
    public func week(on date: Date, calendar: Calendar = .current) -> CycleWeek? {
        guard let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: startDate), to: calendar.startOfDay(for: date)).day,
              days >= 0 else { return nil }
        let number = days / 7 + 1
        return number <= Self.weeks ? CycleWeek(program: program, number: number) : nil
    }
}
