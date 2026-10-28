import Foundation

/// Cycle menstruel lu dans Santé : la rétention d'eau des jours qui précèdent et ouvrent
/// les règles peut masquer une perte de gras sur la balance (White et al., 2011).
/// Le bilan de la semaine ne propose pas de manger moins pendant ces jours.
public enum MenstrualCycle {
    /// Jours sans règles qui séparent deux cycles : en dessous, c'est le même saignement.
    static let gapDays = 10
    /// Durées de cycle plausibles, pour prévoir les prochaines règles.
    static let plausibleCycleDays = 21...35
    /// Rétention d'eau : les 5 jours avant les règles et leurs 5 premiers jours.
    static let daysBefore = 5
    static let daysAfter = 5

    /// Premiers jours de règles, à partir des jours avec flux notés dans Santé.
    public static func starts(fromFlowDays days: [Date], calendar: Calendar = .current) -> [Date] {
        let sorted = Set(days.map { calendar.startOfDay(for: $0) }).sorted()
        var starts: [Date] = []
        var previous: Date?
        for day in sorted {
            if let previous, let gap = calendar.dateComponents([.day], from: previous, to: day).day, gap <= gapDays {
                // Même saignement.
            } else {
                starts.append(day)
            }
            previous = day
        }
        return starts
    }

    /// Vrai si la balance est sans doute faussée par l'eau : règles commencées il y a 5 jours
    /// au plus, ou prochaines règles attendues dans les 5 jours (durée moyenne des derniers cycles).
    public static func retainsWater(periodStarts: [Date], on date: Date, calendar: Calendar = .current) -> Bool {
        let today = calendar.startOfDay(for: date)
        let starts = Set(periodStarts.map { calendar.startOfDay(for: $0) }).filter { $0 <= today }.sorted()
        guard let last = starts.last, let sinceLast = calendar.dateComponents([.day], from: last, to: today).day else { return false }
        if sinceLast < daysAfter { return true }

        let lengths = zip(starts, starts.dropFirst())
            .compactMap { calendar.dateComponents([.day], from: $0, to: $1).day }
            .filter(plausibleCycleDays.contains)
            .suffix(3)
        guard !lengths.isEmpty else { return false }
        let cycle = Int((Double(lengths.reduce(0, +)) / Double(lengths.count)).rounded())
        let untilNext = cycle - sinceLast
        return (0...daysBefore).contains(untilNext)
    }
}
