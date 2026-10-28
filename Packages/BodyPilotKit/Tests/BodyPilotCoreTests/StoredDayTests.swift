import Foundation
import Testing
@testable import BodyPilotCore

private func calendar(_ identifier: String) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: identifier)!
    return calendar
}

@Test func storedDayStaysTheSameDayWhenTravellingWest() {
    let paris = calendar("Europe/Paris")
    let newYork = calendar("America/New_York")
    let morning = paris.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 8))!
    let stored = paris.storedDay(for: morning)
    #expect(newYork.component(.day, from: stored) == 28)
    #expect(paris.component(.day, from: stored) == 28)
    // Minuit à Paris tombe la veille à New York : c'est le défaut corrigé.
    #expect(newYork.component(.day, from: paris.startOfDay(for: morning)) == 27)
}

@Test func onlyMidnightDaysNeedMigration() {
    let paris = calendar("Europe/Paris")
    let morning = paris.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 8))!
    #expect(paris.isStoredAtMidnight(paris.startOfDay(for: morning)))
    #expect(!paris.isStoredAtMidnight(paris.storedDay(for: morning)))
    #expect(!paris.isStoredAtMidnight(morning))
}
