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

    /// Premier jour de la semaine du cycle qui contient `date`.
    public func weekStart(on date: Date, calendar: Calendar = .current) -> Date? {
        guard let week = week(on: date, calendar: calendar) else { return nil }
        return calendar.date(byAdding: .day, value: 7 * (week.number - 1), to: calendar.startOfDay(for: startDate))
    }

    /// Séances faites depuis le début de la semaine du cycle, avant ce jour.
    public func workoutsThisWeek(_ completed: [(day: Date, title: String?)], on date: Date, calendar: Calendar = .current) -> [String] {
        guard let start = weekStart(on: date, calendar: calendar) else { return [] }
        let today = calendar.startOfDay(for: date)
        return completed.filter { $0.day >= start && $0.day < today }.compactMap(\.title)
    }
}

/// Séances prévues dans la semaine du cycle et leur répartition (docs/COACH_RULES.md) : la force
/// d'abord, puis le fractionné, puis l'aérobie. À 2 séances, le fractionné se fait en fin de force.
public struct CycleSessionPlan: Sendable, Equatable {
    public static let range = 2...6
    /// Sans réponse ni historique.
    public static let defaultSessions = 4

    public var sessions: Int

    public init(sessions: Int) {
        self.sessions = min(max(sessions, Self.range.lowerBound), Self.range.upperBound)
    }

    /// 2 séances de force jusqu'à 3 séances, 3 au-delà (une par 48 h, rotation A / B / C).
    public var strength: Int { sessions <= 3 ? 2 : 3 }
    /// Le fractionné (ou le WOD de référence) de la semaine, en séance à part dès 3 séances.
    public var hard: Int { sessions >= 3 ? 1 : 0 }
    public var aerobic: Int { sessions - strength - hard }
    public var intervalsAfterStrength: Bool { hard == 0 }

    /// Moyenne des séances faites par semaine sur les semaines pleines avant ce jour, arrondie,
    /// dans les bornes ; `nil` sans au moins une semaine d'historique.
    public static func recentAverage(doneDays: [Date], before date: Date, weeks: Int = 3, calendar: Calendar = .current) -> Int? {
        let today = calendar.startOfDay(for: date)
        let days = doneDays.map { calendar.startOfDay(for: $0) }
        guard let first = days.min(),
              let span = calendar.dateComponents([.day], from: first, to: today).day, span >= 7 else { return nil }
        let counted = min(weeks, span / 7)
        guard let start = calendar.date(byAdding: .day, value: -7 * counted, to: today) else { return nil }
        let done = Set(days.filter { $0 >= start && $0 < today }).count
        let average = (Double(done) / Double(counted)).rounded()
        return min(max(Int(average), range.lowerBound), range.upperBound)
    }
}
